// SPDX-License-Identifier: Apache2.0
pragma solidity 0.8.4;

import {
    IEarnErrors
} from "./interface/IErrors.sol";
import "./interface/ICandidateHub.sol";
import "./interface/ISTCore.sol";
import "./interface/IPledgeAgent.sol";

import "./lib/IterableAddressDelegateMapping.sol";
import "./lib/Structs.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/**
* @dev The primary purposes of introducing Core LST are:
*   1. Improve user experience
*   2. Bring more utilities of CORE token
*/
contract Earn is Initializable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    using IterableAddressDelegateMapping for IterableAddressDelegateMapping.Map;
    using Address for address payable;

    // Exchange rate base
    // 10^6 is used to enhance precision in calculations
    uint256 private constant RATE_BASE = 1000000;

    // Address of system contract: CandidateHub
    address private constant CANDIDATE_HUB = 0x0000000000000000000000000000000000001005;

    // Address of system contract: PledgeAgent
    address private constant PLEDGE_AGENT = payable(0x0000000000000000000000000000000000001007);

    // The number of seconds in a day
    uint256 public constant DAY_INTERVAL = 86400;

    // https://github.com/coredao-org/core-genesis-contract/blob/master/contracts/CandidateHub.sol
    uint256 public constant VALIDATOR_ACTIVE_STATUS = 17;

    // Address of stCORE contract: STCORE
    address public STCORE;

    // Exchange rate (conversion rate between stCORE and CORE)
    // Exchange rate is calculated and updated at the beginning of each round
    uint256[] public exchangeRates;

    // Delegate records on each validator from the Earn contract
    IterableAddressDelegateMapping.Map private validatorDelegateMap;

    // Redemption period
    // It takes {lockDay} days for users to get CORE back from Earn after requesting redeem
    uint256 public lockDay;

    // Redeem records are saved for each user
    // The records been withdrawn are removed to improve iteration performance
    mapping(address => RedeemRecord[]) public redeemRecords;

    // The threshold to tigger rebalance
    uint256 public balanceThreshold;

    // Dues protections
    uint256 public mintMinLimit;
    uint256 public redeemMinLimit;
    uint256 public pledgeAgentLimit;

    // Protocol fee percents and fee receiving address
    // Set 0 ~ 1000000
    // 1000000 = 100%
    uint256 public protocolFeePoints;
    address public protocolFeeReceiver;

    // The operator address to trigger afterTurnRound() and rebalance methods
    address public operator;

    // roundTag of Core blockchain
    uint256 public roundTag;

    // Length limit of RedeemRecord[]
    // A user can keep up to {redeemCountLimit} redeem records
    // This is introduced to avoid gas issue when users withdraw CORE from this contract
    uint256 public redeemCountLimit;

    // Query limit of exchangeRates
    // A caller can query at most {exchangeRateQueryLimit} rounds
    uint256 public exchangeRateQueryLimit;

    // The amount of CORE which are requested for redumption but not yet undelegated from PledgeAgent
    uint256 public toWithdrawAmount;

    /// --- EVENTS --- ///

    // User operations events
    event Mint(address indexed account, uint256 core, uint256 stCore);
    event Delegate(address indexed validator, uint256 amount);
    event UnDelegate(address indexed validator, uint256 amount);
    event Redeem(address indexed account, uint256 stCore, uint256 core, uint256 protocolFee);
    event Withdraw(address indexed account, uint256 amount, uint256 protocolFee);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    // Operator operations events
    event CalculateExchangeRate(uint256 round, uint256 exchangeRate);
    event ReBalance(address indexed from, address indexed to, uint256 amount);

    // Admin operations events
    event UpdateBalanceThreshold(address indexed caller, uint256 balanceThreshold);
    event UpdateMintMinLimit(address indexed caller, uint256 mintMinLimit);
    event UpdateRedeemMinLimit(address indexed caller, uint256 redeemMinLimit);
    event UpdatePledgeAgentLimit(address indexed caller, uint256 pledgeAgentLimit);
    event UpdateLockDay(address indexed caller, uint256 lockDay);
    event UpdateProtocolFeePoints(address indexed caller, uint256 protocolFeePoints);
    event UpdateProtocolFeeReceiver(address indexed caller, address protocolFeeReceiver);
    event UpdateOperator(address indexed caller, address operator);
    event UpdateRedeemCountLimit(address indexed caller, uint256 redeemCountLimit);
    event UpdateExchangeRateQueryLimit(address indexed caller, uint256 exchangeRateQueryLimit);

    /**
    * @dev Invoke the {Initializable}.{_disableInitializers} function in the constructor
    * to prevent the implementation contract from being used.
    */
    constructor() {
        _disableInitializers();
    }

    /**
    * @dev Contract initialization function, used to initialize fields when creating proxy.
    */
    function initialize(address _stCore, address _protocolFeeReceiver, address _operator) external initializer {
        __Ownable2Step_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        // stCORE should be none ZERO
        if (_stCore == address(0)) {
            revert IEarnErrors.EarnZeroSTCore(_stCore);
        }
        STCORE = _stCore;

        // protocol fee address should be none ZERO
        if (_protocolFeeReceiver == address(0)) {
            revert IEarnErrors.EarnZeroProtocolFeeReceiver(_protocolFeeReceiver);
        }
        protocolFeeReceiver = _protocolFeeReceiver;

        // operator address should be none ZERO
        if (_operator == address(0)) {
            revert IEarnErrors.EarnZeroOperator(_operator);
        }
        operator = _operator;

        // Initialize fields
        exchangeRates.push(RATE_BASE);
        roundTag = _currentRound();
        lockDay = 7;
        balanceThreshold = 10000 ether;
        mintMinLimit = 1 ether;
        redeemMinLimit = 1 ether;
        pledgeAgentLimit = 1 ether;
        protocolFeePoints = 0;
        redeemCountLimit = 100;
        exchangeRateQueryLimit = 365;
        toWithdrawAmount = 0;
    }

    /**
    * @dev Implements {UUPSUpgradeable}.{_authorizeUpgrade()},
    * can be used to implement contract upgrade logic if needed.
    */
    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}

    /// --- MODIFIERS --- ///

    /**
    * @dev Modifier to make a function callable only when {msg.sender} is {operator}.
    */
    modifier onlyOperator() {
        require(msg.sender == operator, "Not operator");
        _;
    }

    /**
    * @dev Modifier to make a function callable only after {afterTurnRound} is called at the beginning of a round.
    */
    modifier afterSettled() {
        require(roundTag == _currentRound(), "Turn round not executed");
        _;
    }

    /**
    * @dev Modifier to make a function callable only when validator can delegate.
    */
    modifier canDelegate(address _validator) {
        require (ICandidateHub(CANDIDATE_HUB).canDelegate(_validator), "Can not delegate to validator");
        _;
    }

    /// --- USER INTERACTIONS --- ///

    /**
    * @dev Mint stCORE using CORE.
    * The caller needs to pass in the validator address to delegate to.
    * By doing so Earn treats existing validators/new comers equally.
    */
    function mint(address _validator) external payable afterSettled nonReentrant whenNotPaused canDelegate(_validator) {
        address account = msg.sender;
        uint256 amount = msg.value;

        // dues protection
        if (amount < mintMinLimit) {
            revert IEarnErrors.EarnMintAmountTooSmall(account, amount);
        }

        // Delegate CORE to PledgeAgent
        _delegate(_validator, amount);

        // Mint stCORE and send to users
        uint256 stCore = _exchangeSTCore(amount);
        ISTCore(STCORE).mint(account, stCore);

        emit Mint(account, amount, stCore);
    }

    /**
    * @dev Redeem stCORE to get back CORE.
    */
    function redeem(uint256 stCore) external afterSettled nonReentrant whenNotPaused {
        address account = msg.sender;
        RedeemRecord[] storage records = redeemRecords[account];

        if (records.length >= redeemCountLimit) {
            revert IEarnErrors.EarnRedeemCountOverLimit(account, records.length, redeemCountLimit);
        }

        // Dues protection
        if (stCore < redeemMinLimit) {
            revert IEarnErrors.EarnSTCoreTooSmall(account, stCore);
        }

        uint256 core = _exchangeCore(stCore);

        // Burn stCORE
        ISTCore(STCORE).burn(account, stCore);

        // Calculate protocol fee
        uint256 protocolFee = core * protocolFeePoints / RATE_BASE;

        // Update redeem records
        uint256 redeemAmount = core - protocolFee;
        RedeemRecord memory redeemRecord = RedeemRecord({
            redeemTime: block.timestamp,
            unlockTime: block.timestamp + DAY_INTERVAL * lockDay,
            amount: redeemAmount,
            stCore: stCore,
            protocolFee: protocolFee
        });
        records.push(redeemRecord);

        toWithdrawAmount += core;

        emit Redeem(account, stCore, redeemAmount, protocolFee);
    }

    /**
    * @dev Withdraw CORE tokens after redemption period.
    */
    function withdraw() external afterSettled nonReentrant {
        address account = msg.sender;

        // Find user redeem records
        RedeemRecord[] storage records = redeemRecords[account];
        if (records.length == 0) {
            revert IEarnErrors.EarnEmptyRedeemRecord();
        }

        uint256 accountAmount = 0;
        uint256 protocolFeeAmount = 0;
        for (uint256 i = records.length; i != 0; i--) {
            RedeemRecord memory record = records[i - 1];
            if (record.unlockTime < block.timestamp) {
                accountAmount += record.amount;
                protocolFeeAmount += record.protocolFee;
                if (i != records.length) {
                    records[i - 1] = records[records.length - 1];
                }
                records.pop();
            }
        }

        // No eligible records found
        if (accountAmount == 0) {
            revert IEarnErrors.EarnRedeemRecordNotFound(account);
        }

        // Amount of CORE to undelegate
        uint256 totalAmount = accountAmount + protocolFeeAmount;

        // Undelegate CORE from validators
        _unDelegateWithStrategy(totalAmount);

        // Transfer CORE to user
        payable(account).sendValue(accountAmount);

        // Transfer CORE to porotocol fee receiver
        if (protocolFeeAmount != 0) {
            payable(protocolFeeReceiver).sendValue(protocolFeeAmount);
        }

        // Update toWithdrawAmount
        toWithdrawAmount -= totalAmount;

        emit Withdraw(account, accountAmount, protocolFeeAmount);
    }

    /// --- OPERATOR INTERACTIONS --- ///

    /**
    * @dev Triggered right after Core blockchain turns to a new round.
    * Users are not allowed to operate before this method is executed successfully in each round.
    * The Earn contract does following in this method
    *   1. Claim rewards from each validator
    *   2. Stake rewards back to one randomly chosen active validator (auto compounding)
    *   3. Update daily exchange rate
    * During the process, this method also undelegates from inactive validators.
    * The operator can also pass in new elected validators to act as a fallback catch
    * in the case where all existing validators are replaced in the new round.
    * The parameter type is set to address[] instead of address for forward compatibilities.
    */
    function afterTurnRound(address[] memory newElectedValidators) external onlyOperator {
        // Claim rewards
        for (uint i = validatorDelegateMap.size(); i != 0; i--) {
            address key = validatorDelegateMap.getKeyAtIndex(i - 1);

            // Claim reward from validator
            _claim(key);

            // Check validator status
            if (!_isActive(key)) {
                // Undelegate from inactive validator
                _unDelegate(key, 0);
            }
        }

        // Delegate all claimed rewards + undelegate amounts from inactive validators
        //  to a random chosen validator
        // If all validators staked by Earn in last round become inactive
        //  choose the first validator in the passed in array
        uint256 validatorSize = validatorDelegateMap.size();
        if (validatorSize == 0) {
            if (newElectedValidators.length > 0 && ICandidateHub(CANDIDATE_HUB).canDelegate(newElectedValidators[0])) {
                uint256 delegateAmount = address(this).balance;
                if (delegateAmount >= pledgeAgentLimit) {
                    _delegate(newElectedValidators[0], delegateAmount);
                }
            } else {
                // should not happen
                revert IEarnErrors.EarnValidatorsAllOffline();
            }
        } else {
            uint256 delegateAmount = address(this).balance;
            if (delegateAmount >= pledgeAgentLimit) {
                uint256 randomIndex = _randomIndex(validatorSize);
                address randomKey = validatorDelegateMap.getKeyAtIndex(randomIndex);
                _delegate(randomKey, delegateAmount);
            }
        }

        uint256 currentRound = _currentRound();

        // Update exchange rate
        uint256 totalSupply = IERC20(STCORE).totalSupply();
        if (totalSupply > 0) {
            uint256 _capital = 0;
            for (uint256 i = 0; i < validatorDelegateMap.size(); i++) {
                address key = validatorDelegateMap.getKeyAtIndex(i);
                _capital += validatorDelegateMap.get(key);
            }
            if (_capital > toWithdrawAmount) {
                uint256 rate = (_capital - toWithdrawAmount) * RATE_BASE / totalSupply;
                exchangeRates.push(rate);

                emit CalculateExchangeRate(currentRound, rate);
            }
        }

        // Update round tag
        roundTag = currentRound;
    }

    /**
    * @dev This method can be triggered on a regular basis, e.g. hourly/daily/weekly/etc.
    * The Earn contract rebalances staking on top/bottom validators in this method.
    */
    function reBalance() external afterSettled onlyOperator {
        if (validatorDelegateMap.size() <= 1) {
            revert IEarnErrors.EarnEmptyValidator();
        }

        // Use the first validator as a benchmark
        address key = validatorDelegateMap.getKeyAtIndex(0);
        uint256 initDelegateAmount = validatorDelegateMap.get(key);

        // Find max and min delegate amounts in all validators
        uint256 max = initDelegateAmount;
        address maxValidator = key;
        uint256 min = initDelegateAmount;
        address minValidator = key;
        for (uint256 i = 1; i < validatorDelegateMap.size(); i++) {
            key = validatorDelegateMap.getKeyAtIndex(i);
            uint256 delegateAmount = validatorDelegateMap.get(key);
            if (delegateAmount > max) {
                max = delegateAmount;
                maxValidator = key;
            } else if (delegateAmount < min) {
                min = delegateAmount;
                minValidator = key;
            }
        }

        if (minValidator == maxValidator) {
            revert IEarnErrors.EarnReBalanceNoNeed(maxValidator, minValidator);
        }

        if (max - min < balanceThreshold) {
            revert IEarnErrors.EarnReBalanceAmountDifferenceLessThanThreshold(maxValidator, minValidator, max, min, balanceThreshold);
        }

        // Transfer CORE to rebalance
        uint256 transferAmount = (max - min) / 2;

        _reBalanceTransfer(maxValidator, minValidator, max, transferAmount);
    }

    /**
    * @dev This method is introduce to take necessary actions to improve earning.
    * e.g. to transfer stakes from a jailed validator to another before turn round.
    * e.g. to transfer stakes from a low APR validator to a high APR validator.
    */
    function manualReBalance(address _from, address _to, uint256 _transferAmount) external afterSettled onlyOperator canDelegate(_to) {
        if (validatorDelegateMap.size() == 0) {
            revert IEarnErrors.EarnEmptyValidator();
        }

        uint256 fromValidatorAmount = validatorDelegateMap.get(_from);

        if (fromValidatorAmount < _transferAmount) {
            revert IEarnErrors.EarnReBalanceInsufficientAmount(_from, fromValidatorAmount, _transferAmount);
        }

        _reBalanceTransfer(_from, _to, fromValidatorAmount, _transferAmount);
    }

    /// --- VIEW METHODS ---///

    /**
    * @dev Returns redemption records based on the given address.
    */
    function getRedeemRecords(address _account) external view returns (RedeemRecord[] memory) {
        return redeemRecords[_account];
    }

    /**
    * @dev Returns the lock and unlock amount based on the given address.
    */
    function getRedeemAmount(address _account) external view returns (uint256 unlockedAmount, uint256 lockedAmount) {
        RedeemRecord[] storage records = redeemRecords[_account];
        for (uint256 i = 0; i < records.length; i++) {
            RedeemRecord memory record = records[i];
            if (record.unlockTime < block.timestamp) {
                unlockedAmount += record.amount;
            } else {
                lockedAmount += record.amount;
            }
        }
    }

    /**
    * @dev Returns the exchange rate of the last {target} days.
    */
    function getExchangeRates(uint256 target) external view returns(uint256[] memory _exchangeRates) {
        if (target > exchangeRateQueryLimit) {
            return _exchangeRates;
        }

        if (target < 1) {
            return _exchangeRates;
        }

        uint256 size = exchangeRates.length;
        uint256 from = 0;
        uint256 count;
        if (target >= size) {
            count = size;
        } else {
            from = size - target;
            count = target;
        }

        _exchangeRates = new uint256[](count);
        for (uint256 i = from; i < size; i++) {
            _exchangeRates[i-from] = exchangeRates[i];
        }
    }

    /**
    * @dev Returns current latest exchange rate.
    */
    function getCurrentExchangeRate() external view returns (uint256) {
        return exchangeRates[exchangeRates.length - 1];
    }

    /**
    * @dev Returns the total amount delegated in {PLEDGE_AGENT} for this contract.
    */
    function getTotalDelegateAmount() external view returns (uint256) {
        uint256 amount = 0;
        uint256 mapSize = validatorDelegateMap.size();
        for (uint256 i = 0; i < mapSize; i++) {
            address key = validatorDelegateMap.getKeyAtIndex(i);
            amount += validatorDelegateMap.get(key);
        }
        return amount;
    }

    /// --- INTERNAL METHODS --- ///

    /**
    * @dev Returns the current round.
    * Calls {CANDIDATE_HUB.getRoundTag()}.
    */
    function _currentRound() private view returns (uint256) {
        return ICandidateHub(CANDIDATE_HUB).getRoundTag();
    }

    /**
    * @dev Exchanges core to stCore.
    */
    function _exchangeSTCore(uint256 core) private view returns (uint256) {
        return core * RATE_BASE / exchangeRates[exchangeRates.length-1];
    }

    /**
    * @dev Exchanges stCore to core.
    */
    function _exchangeCore(uint256 stCore) private view returns(uint256) {
        return stCore * exchangeRates[exchangeRates.length-1] / RATE_BASE;
    }

    /**
    * @dev Exchanges core to stCore.
    * Undelegate CORE from validators with strategy.
    * There is dues protection in PledageAgent, which are
    *   1. Can only delegate 1+ CORE
    *   2. Can only undelegate 1+ CORE AND can only leave 1+ CORE on validator after undelegate
    * Internally, Earn delegates/undelegates on validators for each mint/redeem action.
    * As a result, to make the system solid. Any undelegate action on a validator from Earn must result in
    *   1. The validator must be cleared or have 1+ CORE remaining after undelegate.
    *     AND
    *   2. Earn contract must have 0 or 1+ CORE left to further undelegate.
    * Otherwise, Earn might fail to undelegate further because of the dues protection from PledgeAgent.
    */
    function _unDelegateWithStrategy(uint256 amount) private {
        // Random validator position
        uint256 length = validatorDelegateMap.size();
        if (length == 0) {
            revert IEarnErrors.EarnEmptyValidator();
        }
        uint256 fromIndex = _randomIndex(length);

        bool reachedEnd = false;
        uint256 index = fromIndex;
        while (!(index == fromIndex && reachedEnd) && amount > 0) {
            address key = validatorDelegateMap.getKeyAtIndex(index);
            uint256 validatorAmount = validatorDelegateMap.get(key);

            if (validatorAmount > 0) {
                if (validatorAmount == amount) {
                    // Case 1: the amount available on the validator == the amount needs to be undelegated
                    // Undelegate all the tokens from the validator
                    _unDelegate(key, amount);
                    amount = 0;
                    break;
                } else if (validatorAmount > amount) {
                    if (validatorAmount >= amount + pledgeAgentLimit) {
                        // Case 2: the amount available on the validator >= the amount needs to be undelegated + 1
                        // Undelegate all the tokens from the validator
                        _unDelegate(key, amount);
                        amount = 0;
                        break;
                    } else {
                        // Case 3: the amount available on the validator >= the amount needs to be undelegated AND
                        //          the amount available on the validator <= the amount needs to be undelegated + 1
                        // In this case we need to make sure there are 1 CORE token left to further undelegate
                        uint256 undelegateAmount = amount - pledgeAgentLimit;
                        if (undelegateAmount > pledgeAgentLimit) {
                            _unDelegate(key, undelegateAmount);
                            amount -= undelegateAmount;
                        }
                    }
                } else {
                    if (amount >= validatorAmount + pledgeAgentLimit) {
                        // Case 4: the amount available on the validator <= the amount needs to be undelegated - 1
                        // Clear the validator and move to the next one
                        _unDelegate(key, validatorAmount);
                        amount -= validatorAmount;
                    } else {
                        // Case 5: the amount available on the validator >= the amount needs to be undelegated - 1 AND
                        //          the amount available on the validator <= the amount needs to be undelegated
                        // In this case we need to make sure there are 1 CORE token left on validator
                        uint256 undelegateAmount = validatorAmount - pledgeAgentLimit;
                        if (undelegateAmount > pledgeAgentLimit) {
                            _unDelegate(key, undelegateAmount);
                            amount -= undelegateAmount;
                        }
                    }
                }
            }

            if (index == length - 1) {
                index = 0;
                reachedEnd = true;
            } else {
                index++;
            }
        }

        // Earn protocol is insolvency
        // In theory this could not happen if Earn is funded before open to public
        if (amount > 0) {
            revert IEarnErrors.EarnUnDelegateFailedFinally(msg.sender, amount);
        }
    }

    /**
    * @dev Calls {PLEDGE_AGENT} to perform {delegateCoin()} operation.
    */
    function _delegate(address validator, uint256 amount) private {
        IPledgeAgent(PLEDGE_AGENT).delegateCoin {
            value: amount
        }(validator);
        // Update delegate record
        validatorDelegateMap.add(validator, amount);
        emit Delegate(validator, amount);
    }

    /**
    * @dev Calls {PLEDGE_AGENT} to perform {undelegateCoin()} operation.
    * If the amount is 0, then delete validator from {validatorDelegateMap}.
    * The delete action only occurs in the {afterTurnRound} function when the validator is invalid.
    */
    function _unDelegate(address validator, uint256 amount) private {
        if (amount == 0) {
            // The case only occurs in the {afterTurnRound} function when the validator is invalid.
            if (validatorDelegateMap.get(validator) >= pledgeAgentLimit) {
                // The undelegateCoin needs to be called
                // only if the current delegate amount is greater than or equal to limit.
                IPledgeAgent(PLEDGE_AGENT).undelegateCoin(validator, amount);
            }
            // Remove delegate record
            validatorDelegateMap.remove(validator);
        } else {
            IPledgeAgent(PLEDGE_AGENT).undelegateCoin(validator, amount);
            // Update delegate record
            validatorDelegateMap.subtract(validator, amount);
        }
        emit UnDelegate(validator, amount);
    }

    /**
    * @dev Calls {PLEDGE_AGENT} to perform {transferCoin()} operation.
    */
    function _transfer(address from, address to, uint256 amount) private {
        IPledgeAgent(PLEDGE_AGENT).transferCoin(from, to, amount);
        // Update delegate record
        validatorDelegateMap.subtract(from, amount);
        validatorDelegateMap.add(to, amount);
        emit Transfer(from, to, amount);
    }

    /**
    * @dev Calls {PLEDGE_AGENT} to perform {claimReward()} operation.
    */
    function _claim(address validator) private {
        address[] memory addresses = new address[](1);
        addresses[0] = validator;
        IPledgeAgent(PLEDGE_AGENT).claimReward(addresses);
    }

    /**
    * @dev Returns a random number based on the length of array.
    */
    function _randomIndex(uint256 length) private view returns (uint256) {
        return uint256(keccak256(abi.encode(msg.sender, roundTag))) % length;
    }

    /**
    * @dev Determine whether the validator is active based on {CANDIDATE_HUB}.
    */
    function _isActive(address validator) private view returns (bool) {
        uint256 indexPlus1 = ICandidateHub(CANDIDATE_HUB).operateMap(validator);
        if (indexPlus1 == 0) {
            return false;
        }
        Candidate memory candidate = ICandidateHub(CANDIDATE_HUB).candidateSet(indexPlus1 - 1);
        return candidate.status == VALIDATOR_ACTIVE_STATUS;
    }

    /**
    * @dev Transfer amount from a validator to another.
    * The funcion is reused by {reBalance()} and {manualReBalance()}.
    */
    function _reBalanceTransfer(address _from, address _to, uint256 _fromAmount, uint256 _transferAmount) private {
        if (_transferAmount >= pledgeAgentLimit && (_fromAmount == _transferAmount || _fromAmount - _transferAmount >= pledgeAgentLimit)) {
            _transfer(_from, _to, _transferAmount);
            emit ReBalance(_from, _to, _transferAmount);
        } else {
            revert IEarnErrors.EarnReBalanceInvalidTransferAmount(_from, _fromAmount, _transferAmount);
        }
    }

    /// --- ADMIN OPERATIONS --- ///

    /**
    * @dev Updates the threshold between the maximum and minimum amount pledged.
    * If the amount difference is less than the threshold, the rebalance operation is not performed.
    * The default value is 10000 core.
    *
    * Emits an {UpdateBalanceThreshold} event.
    *
    * Requirements:
    *
    * - The caller must be owner.
    */
    function updateBalanceThreshold(uint256 _balanceThreshold) external onlyOwner {
        if (_balanceThreshold == 0) {
            revert IEarnErrors.EarnBalanceThresholdMustGreaterThanZero();
        }
        balanceThreshold = _balanceThreshold;
        emit UpdateBalanceThreshold(msg.sender, _balanceThreshold);
    }

    /**
    * @dev Updates the minimum amount of user mint operation.
    * The default value is 1 core.
    *
    * Emits an {UpdateMintMinLimit} event.
    *
    * Requirements:
    *
    * - The caller must be owner.
    */
    function updateMintMinLimit(uint256 _mintMinLimit) external onlyOwner {
        if (_mintMinLimit < 1 ether) {
            revert IEarnErrors.EarnMintMinLimitMustGreaterThan1Core();
        }
        mintMinLimit = _mintMinLimit;
        emit UpdateMintMinLimit(msg.sender, _mintMinLimit);
    }

    /**
    * @dev Updates the minimum amount of user redemption.
    * The default value is 1 stCore.
    *
    * Emits an {UpdateRedeemMinLimit} event.
    *
    * Requirements:
    *
    * - The caller must be owner.
    */
    function updateRedeemMinLimit(uint256 _redeemMinLimit) external onlyOwner {
        if (_redeemMinLimit < 1 ether) {
            revert IEarnErrors.EarnRedeemMinLimitMustGreaterThan1Core();
        }
        redeemMinLimit = _redeemMinLimit;
        emit UpdateRedeemMinLimit(msg.sender, _redeemMinLimit);
    }

    /**
    * @dev Updates the minimum amount of the pledge operation.
    * The default value is 1 core, which is limited by {PLEDGE_AGENT}.
    *
    * Emits an {UpdatePledgeAgentLimit} event.
    *
    * Requirements:
    *
    * - The caller must be owner.
    */
    function updatePledgeAgentLimit(uint256 _pledgeAgentLimit) external onlyOwner {
        if (_pledgeAgentLimit < 1 ether) {
            revert IEarnErrors.EarnPledgeAgentLimitMustGreaterThan1Core();
        }
        pledgeAgentLimit = _pledgeAgentLimit;
        emit UpdatePledgeAgentLimit(msg.sender, _pledgeAgentLimit);
    }

    /**
    * @dev Updates the user redemption lockup period.
    *
    * Emits an {UpdateLockDay} event.
    *
    * Requirements:
    *
    * - The caller must be owner.
    */
    function updateLockDay(uint256 _lockDay) external onlyOwner {
        if (_lockDay == 0) {
            revert IEarnErrors.EarnLockDayMustGreaterThanZero();
        }
        lockDay = _lockDay;
        emit UpdateLockDay(msg.sender, _lockDay);
    }

    /**
    * @dev Updates the rate of protocol fee.
    *
    * Emits an {UpdateProtocolFeePoints} event.
    *
    * Requirements:
    *
    * - The caller must be owner.
    */
    function updateProtocolFeePoints(uint256 _protocolFeePoints) external onlyOwner {
        if (_protocolFeePoints > RATE_BASE) {
            revert IEarnErrors.EarnProtocolFeePointMoreThanRateBase(_protocolFeePoints);
        }
        protocolFeePoints = _protocolFeePoints;
        emit UpdateProtocolFeePoints(msg.sender, _protocolFeePoints);
    }

    /**
    * @dev Updates the address of protocol fee receiver.
    * The receiver receives the fees generated by the user's participation in making money.
    *
    * Emits an {UpdateProtocolFeeReceiver} event.
    *
    * Requirements:
    *
    * - The caller must be owner.
    */
    function updateProtocolFeeReceiver(address _protocolFeeReceiver) external onlyOwner {
        if (_protocolFeeReceiver == address(0)) {
            revert IEarnErrors.EarnZeroProtocolFeeReceiver(_protocolFeeReceiver);
        }
        protocolFeeReceiver = _protocolFeeReceiver;
        emit UpdateProtocolFeeReceiver(msg.sender, _protocolFeeReceiver);
    }

    /**
    * @dev Updates the address of the operator role.
    * The operator role can call functions modified by {onlyOperator}.
    *
    * Emits an {UpdateOperator} event.
    *
    * Requirements:
    *
    * - The caller must be owner.
    */
    function updateOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) {
            revert IEarnErrors.EarnZeroOperator(_operator);
        }
        operator = _operator;
        emit UpdateOperator(msg.sender, _operator);
    }

    /**
    * @dev Updates the maximum number of redemption records stored.
    *
    * Emits an {UpdateRedeemCountLimit} event.
    *
    * Requirements:
    *
    * - The caller must be owner.
    */
    function updateRedeemCountLimit(uint256 _redeemCountLimit) external onlyOwner {
        if (_redeemCountLimit == 0) {
            revert IEarnErrors.EarnRedeemCountLimitMustGreaterThanZero();
        }
        redeemCountLimit = _redeemCountLimit;
        emit UpdateRedeemCountLimit(msg.sender, _redeemCountLimit);
    }

    /**
    * @dev Updates the number of items returned from the exchange rate query.
    *
    * Emits an {UpdateExchangeRateQueryLimit} event.
    *
    * Requirements:
    *
    * - The caller must be owner.
    */
    function updateExchangeRateQueryLimit(uint256 _exchangeRateQueryLimit) external onlyOwner {
        if (_exchangeRateQueryLimit == 0) {
            revert IEarnErrors.EarnExchangeRateQueryLimitMustGreaterThanZero();
        }
        exchangeRateQueryLimit = _exchangeRateQueryLimit;
        emit UpdateExchangeRateQueryLimit(msg.sender, _exchangeRateQueryLimit);
    }

    /**
    * @dev Triggers stopped state.
    *
    * Calls {PausableUpgradeable.sol._pause()}.
    *
    * Requirements:
    *
    * - The contract must not be paused.
    */
    function pause() external onlyOwner {
        _pause();
    }

    /**
    * @dev Returns to normal state.
    *
    * Calls {PausableUpgradeable.sol._unpause()}.
    *
    * Requirements:
    *
    * - The contract must be paused.
    */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
    * @dev Only receive rewards from {PLEDGE_AGENT}.
    */
    receive() external payable {
        if (msg.sender != PLEDGE_AGENT) {
            revert IEarnErrors.EarnTransferAmountProhibit(msg.sender);
        }
    }

    /**
    * @dev This empty reserved space is put in place to allow future versions to add new
    * variables without shifting down storage in the inheritance chain.
    * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    */
    uint256[50] private __gap;
}