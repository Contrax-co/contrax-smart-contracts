// /// SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.7.6;
// pragma abicoder v2;

// import "./interfaces/IHypervisor.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
// import "@uniswap/v3-core/contracts/libraries/FullMath.sol";
// import "@openzeppelin/contracts/math/SafeMath.sol";
// import "@openzeppelin/contracts/math/SignedSafeMath.sol";
// import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
// import "./algebra/interfaces/pool/IAlgebraPoolState.sol";

// /// @title Clearing v2
// /// @notice Proxy contract for hypervisor positions management
// contract ClearingV2 is ReentrancyGuard {
//   using SafeERC20 for IERC20;
//   using SafeMath for uint256;
//   using SignedSafeMath for int256;

//   string constant VERSION = '2.0.0';
//   address public owner;
//   bool public paused;
//   mapping(address => Position) public positions;

//   bool public twapCheck = true;
//   uint32 public twapInterval = 3600;
//   uint256 public depositDelta = 10_010;
//   uint256 public deltaScale = 10_000; /// must be a power of 10
//   uint256 public priceThreshold = 10_000;
//   uint256 constant MAX_UINT = 2**256 - 1;
//   uint256 public constant PRECISION = 1e36;
//   mapping (address => mapping (address => bool)) public freeDepositList;

//   struct Position {
//     bool customRatio;
//     bool customTwap;
//     bool ratioRemoved;
//     bool depositOverride; // force custom deposit constraints
//     bool twapOverride; // force twap check for hypervisor instance
//     uint8 version; 
//     uint32 twapInterval; // override global twap
//     uint256 priceThreshold; // custom price threshold
//     uint256 deposit0Max;
//     uint256 deposit1Max;
//     uint256 maxTotalSupply;
//     uint256 fauxTotal0;
//     uint256 fauxTotal1;
//     uint256 customDepositDelta;
//     // mapping(address=>bool) list; // whitelist certain accounts for freedeposit
//   }

//   event PositionAdded(address, uint8);
//   event CustomDeposit(address, uint256, uint256, uint256);
//   event PriceThresholdSet(uint256 _priceThreshold);
//   event DepositDeltaSet(uint256 _depositDelta);
//   event DeltaScaleSet(uint256 _deltaScale);
//   event TwapIntervalSet(uint32 _twapInterval);
//   event TwapOverrideSet(address pos, bool twapOverride, uint32 _twapInterval, uint256 _priceThreshold);
//   event PriceThresholdPosSet(address pos, uint256 _priceThreshold);
//   event DepositOverrideSet(address pos, bool depositOverride);
//   event TwapCheckSet(bool twapCheck);
//   event ListAppended(address pos, address[] listed);
//   event ListRemoved(address pos, address listed);
//   event CustomRatio(address pos, uint256 fauxTotal0, uint256 fauxTotal1);
//   event RatioRemoved(address pos);

//   constructor() {
//     owner = msg.sender;
//   }

//   modifier onlyAddedPosition(address pos) {
//     Position storage p = positions[pos];
//     require(p.version != 0, "not added");
//     _;
//   }

//   /// @notice Add the hypervisor position
//   /// @param pos Address of the hypervisor
//   /// @param version Type of hypervisor
//   function addPosition(address pos, uint8 version) external onlyOwner {
//     Position storage p = positions[pos];
//     require(p.version == 0, 'already added');
//     require(version > 0, 'version < 1');
//     p.version = version;
//     IHypervisor(pos).token0().safeApprove(pos, MAX_UINT);
//     IHypervisor(pos).token1().safeApprove(pos, MAX_UINT);
//     emit PositionAdded(pos, version);
//   }

//   /// @notice apply configuration constraints to shares minted 
//   /// @param pos Address of the hypervisor
//   /// @param shares Amount of shares minted (included for upgrades)
//   /// @return cleared whether shares are cleared 
//   function clearShares(
//     address pos,
//     uint256 shares 
//   ) public view onlyAddedPosition(pos) returns (bool cleared) {
//     if(positions[pos].maxTotalSupply != 0) {
//       require(IHypervisor(pos).totalSupply() <= positions[pos].maxTotalSupply, "exceeds max supply");
//     }
//     return true;
//   }

//   /// @notice apply configuration constraints to deposit 
//   /// @param pos Address of the hypervisor
//   /// @param deposit0 Amount of token0 to deposit
//   /// @param deposit1 Amount of token1 to deposit
//   /// @param to Address to receive liquidity tokens
//   /// @param pos Hypervisor Address
//   /// @param minIn min assets to expect in position during a direct deposit 
//   /// @return cleared whether deposit is cleared 
//   function clearDeposit(
//     uint256 deposit0,
//     uint256 deposit1,
//     address from,
//     address to,
//     address pos,
//     uint256[4] memory minIn
//   ) public view onlyAddedPosition(pos) returns (bool cleared) {
//     require(!paused, "paused");
//     require(to != address(0), "to should be non-zero");
//     require(
//       IHypervisor(pos).currentTick() >= IHypervisor(pos).baseLower() &&
//        IHypervisor(pos).currentTick() < IHypervisor(pos).baseUpper(),
//       "price out of base range"
//     );
//     Position storage p = positions[pos];
//     if (twapCheck || p.twapOverride) {
//       /// check twap
//       checkPriceChange(
//         pos,
//         (p.twapOverride ? p.twapInterval : twapInterval),
//         (p.twapOverride ? p.priceThreshold : priceThreshold)
//       );
//     }
    
//     if (!freeDepositList[pos][from]) {
//       require(deposit0 > 0 && deposit1 > 0, "must deposit to both sides");
//       (uint256 test1Min, uint256 test1Max) = getDepositAmount(pos, address(IHypervisor(pos).token0()), deposit0);
//       require(deposit1 >= test1Min && deposit1 <= test1Max, "Improper ratio"); 
      
//       (uint256 test0Min, uint256 test0Max) = getDepositAmount(pos, address(IHypervisor(pos).token1()), deposit1);
//       require(deposit0 >= test0Min && deposit0 <= test0Max, "Improper ratio");

//       if (p.depositOverride) {
//         require(deposit0 <= p.deposit0Max, "token0 exceeds");
//         require(deposit1 <= p.deposit1Max, "token1 exceeds");
//       }
//     }

//     return true;
//   }

//   /// @notice Get the amount of token to deposit for the given amount of pair token
//   /// @param pos Hypervisor Address
//   /// @param token Address of token to deposit
//   /// @param _deposit Amount of token to deposit
//   /// @return amountStart Minimum amounts of the pair token to deposit
//   /// @return amountEnd Maximum amounts of the pair token to deposit
//   function getDepositAmount(
//     address pos,
//     address token,
//     uint256 _deposit
//   ) public view returns (uint256 amountStart, uint256 amountEnd) {
//     require(token == address(IHypervisor(pos).token0()) || token == address(IHypervisor(pos).token1()), "token mistmatch");
//     require(_deposit > 0, "deposits can't be zero");
//     (uint256 total0, uint256 total1) = IHypervisor(pos).getTotalAmounts();
//     if (IHypervisor(pos).totalSupply() == 0) {
//       amountStart = 0;
//       if (positions[pos].depositOverride) {
//         amountEnd = (token == address(IHypervisor(pos).token0())) ? 
//           positions[pos].deposit1Max : 
//           positions[pos].deposit0Max;
//       } else {
//         amountEnd = (token == address(IHypervisor(pos).token0())) ? 
//           IHypervisor(pos).deposit1Max() :
//           IHypervisor(pos).deposit0Max();
//       }
//     } else if (total0 == 0 || total1 == 0) {
//       amountStart = 0;
//       amountEnd = 0;
//     } else {
//       (uint256 ratioStart, uint256 ratioEnd) = positions[pos].customRatio ? 
//         applyRatio(pos, token, positions[pos].fauxTotal0, positions[pos].fauxTotal1) :
//         applyRatio(pos, token, total0, total1);
//       amountStart = FullMath.mulDiv(_deposit, PRECISION, ratioStart);
//       amountEnd = FullMath.mulDiv(_deposit, PRECISION, ratioEnd);
//     }
//   }

//   /// @notice Get range for deposit based on provided amounts
//   /// @param pos Hypervisor Address
//   /// @param token Address of token to deposit
//   /// @param total0 Amount of token0 in hype 
//   /// @param total1 Amount of token1 in hype 
//   /// @return ratioStart Minimum amounts of the pair token to deposit
//   /// @return ratioEnd Maximum amounts of the pair token to deposit
//   function applyRatio(
//     address pos,
//     address token,
//     uint256 total0,
//     uint256 total1
//   ) public view returns (uint256 ratioStart, uint256 ratioEnd) {
//     require(token == address(IHypervisor(pos).token0()) || token == address(IHypervisor(pos).token1()), "token mistmatch");
//     uint256 _depositDelta = positions[pos].depositOverride ?
//       positions[pos].customDepositDelta :
//       depositDelta;
//     if (token == address(IHypervisor(pos).token0())) {
//       ratioStart = FullMath.mulDiv(total0.mul(_depositDelta), PRECISION, total1.mul(deltaScale));
//       ratioEnd = FullMath.mulDiv(total0.mul(deltaScale), PRECISION, total1.mul(_depositDelta));
//     } else {
//       ratioStart = FullMath.mulDiv(total1.mul(_depositDelta), PRECISION, total0.mul(deltaScale));
//       ratioEnd = FullMath.mulDiv(total1.mul(deltaScale), PRECISION, total0.mul(_depositDelta));
//     }
//   }

//   /// @notice Check if the price change overflows or not based on given twap and threshold in the hypervisor
//   /// @param pos Hypervisor Address
//   /// @param _twapInterval Time intervals
//   /// @param _priceThreshold Price Threshold
//   /// @return price Current price
//   function checkPriceChange(
//     address pos,
//     uint32 _twapInterval,
//     uint256 _priceThreshold
//   ) public view returns (uint256 price) {

//     (uint160 sqrtPrice, , , , , , ) = IHypervisor(pos).pool().globalState();
//     price = FullMath.mulDiv(uint256(sqrtPrice).mul(uint256(sqrtPrice)), PRECISION, 2**(96 * 2));

//     uint160 sqrtPriceBefore = getSqrtTwapX96(pos, _twapInterval);
//     uint256 priceBefore = FullMath.mulDiv(uint256(sqrtPriceBefore).mul(uint256(sqrtPriceBefore)), PRECISION, 2**(96 * 2));
//     if (price.mul(10_000).div(priceBefore) > _priceThreshold || priceBefore.mul(10_000).div(price) > _priceThreshold)
//       revert("Price change Overflow");
//   }

//   /// @notice Get the sqrt price before the given interval
//   /// @param pos Hypervisor Address
//   /// @param _twapInterval Time intervals
//   /// @return sqrtPriceX96 Sqrt price before interval
//   function getSqrtTwapX96(address pos, uint32 _twapInterval) public view returns (uint160 sqrtPriceX96) {
//     if (_twapInterval == 0) {
//       /// return the current price if _twapInterval == 0
//       (sqrtPriceX96, , , , , ,) = IHypervisor(pos).pool().globalState();
//     } 
//     else {
//       uint32[] memory secondsAgos = new uint32[](2);
//       secondsAgos[0] = _twapInterval; /// from (before)
//       secondsAgos[1] = 0; /// to (now)

//       (int56[] memory tickCumulatives, , ,) = IHypervisor(pos).pool().getTimepoints(secondsAgos);

//       /// tick(imprecise as it's an integer) to price
//       sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
//         int24((tickCumulatives[1] - tickCumulatives[0]) / _twapInterval)
//       );
//     }
//   }

//   /// @param _priceThreshold Price Threshold
//   function setPriceThreshold(uint256 _priceThreshold) external onlyOwner {
//     priceThreshold = _priceThreshold;
//     emit PriceThresholdSet(_priceThreshold);
//   }

//   /// @param _depositDelta Number to calculate deposit ratio
//   function setDepositDelta(uint256 _depositDelta) external onlyOwner {
//     depositDelta = _depositDelta;
//     emit DepositDeltaSet(_depositDelta);
//   }

//   /// @param _deltaScale Number to calculate deposit ratio
//   function setDeltaScale(uint256 _deltaScale) external onlyOwner {
//     deltaScale = _deltaScale;
//     emit DeltaScaleSet(_deltaScale);
//   }

//   /// @param pos Hypervisor address
//   /// @param deposit0Max Amount of maximum deposit amounts of token0
//   /// @param deposit1Max Amount of maximum deposit amounts of token1
//   /// @param maxTotalSupply Maximum total suppoy of hypervisor
//   /// @param customDepositDelta custom deposit delta
//   function customDeposit(
//     address pos,
//     uint256 deposit0Max,
//     uint256 deposit1Max,
//     uint256 maxTotalSupply,
//     uint256 customDepositDelta
//   ) external onlyOwner onlyAddedPosition(pos) {
//     Position storage p = positions[pos];
//     p.deposit0Max = deposit0Max;
//     p.deposit1Max = deposit1Max;
//     p.maxTotalSupply = maxTotalSupply;
//     p.customDepositDelta = customDepositDelta;
//     emit CustomDeposit(pos, deposit0Max, deposit1Max, maxTotalSupply);
//   }

//   /// @param pos Hypervisor address
//   /// @param _customRatio whether to use custom ratio 
//   /// @param fauxTotal0 override total0
//   /// @param fauxTotal1 override total1 
//   function customRatio(
//     address pos,
//     bool _customRatio,
//     uint256 fauxTotal0,
//     uint256 fauxTotal1
//   ) external onlyOwner onlyAddedPosition(pos) {
//     require(!positions[pos].ratioRemoved, "custom ratio is no longer available");
//     Position storage p = positions[pos];
//     p.customRatio = _customRatio;
//     p.fauxTotal0 = fauxTotal0;
//     p.fauxTotal1 = fauxTotal1;
//     emit CustomRatio(pos, fauxTotal0, fauxTotal1);
//   }

//   // @note permantently remove ability to apply custom ratio to hype
//   function removeRatio(address pos) external onlyOwner onlyAddedPosition(pos) {
//     Position storage p = positions[pos];
//     p.ratioRemoved = true;
//     emit RatioRemoved(pos);
//   }

//   /// @notice set deposit override
//   /// @param pos Hypervisor Address
//   function setDepositOverride(address pos, bool _depositOverride) external onlyOwner onlyAddedPosition(pos) {
//     Position storage p = positions[pos];
//     p.depositOverride = _depositOverride;
//     emit DepositOverrideSet(pos, _depositOverride);
//   }

//   /// @param _twapInterval Time intervals
//   function setTwapInterval(uint32 _twapInterval) external onlyOwner {
//     twapInterval = _twapInterval;
//     emit TwapIntervalSet(_twapInterval);
//   }

//   /// @param pos Hypervisor Address
//   /// @param twapOverride Twap Override
//   /// @param _twapInterval Time Intervals
//   /// @param _priceThreshold Price Threshold
//   function setTwapOverride(address pos, bool twapOverride, uint32 _twapInterval, uint256 _priceThreshold) external onlyOwner onlyAddedPosition(pos) {
//     Position storage p = positions[pos];
//     p.twapOverride = twapOverride;
//     p.twapInterval = _twapInterval;
//     p.priceThreshold = _priceThreshold;
//     emit TwapOverrideSet(pos, twapOverride, _twapInterval, _priceThreshold);
//   }

//   /// @notice Set Twap
//   function setTwapCheck(bool _twapCheck) external onlyOwner {
//     twapCheck = _twapCheck;
//     emit TwapCheckSet(_twapCheck);
//   }

//   // @notice check if an address is whitelisted for hype
//   function getListed(address pos, address i) public view returns(bool) {
//     return freeDepositList[pos][i];
//   }

//   function getPositionInfo(address pos) public view returns (Position memory) {
//     return positions[pos];
//   }

//   /// @notice Append whitelist to hypervisor
//   /// @param pos Hypervisor Address
//   /// @param listed Address array to add in whitelist
//   function appendList(address pos, address[] memory listed) external onlyOwner onlyAddedPosition(pos) {
//     for (uint8 i; i < listed.length; i++) {
//       freeDepositList[pos][listed[i]] = true;
//     }
//     emit ListAppended(pos, listed);
//   }

//   /// @notice Remove address from whitelist
//   /// @param pos Hypervisor Address
//   /// @param listed Address to remove from whitelist
//   function removeListed(address pos, address listed) external onlyOwner onlyAddedPosition(pos) {
//     freeDepositList[pos][listed] = false;
//     emit ListRemoved(pos, listed);
//   }

//   function pause(bool _paused) external onlyOwner {
//     paused = _paused;
//   }

//   function transferOwnership(address newOwner) external onlyOwner {
//     require(newOwner != address(0), "newOwner should be non-zero");
//     owner = newOwner;
//   }

//   modifier onlyOwner {
//     require(msg.sender == owner, "only owner");
//     _;
//   }
// }