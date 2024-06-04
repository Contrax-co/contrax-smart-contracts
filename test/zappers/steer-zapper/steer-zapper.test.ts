/* eslint-disable no-undef */
import { ethers, network } from "hardhat";
import { expect } from "chai";
import { Contract, Signer, BigNumber } from "ethers";
import { overwriteTokenAmount, returnSigner, setStrategy } from "../../utils/helpers";
import { setupSigners } from "../../utils/static";

let zapInUsdcAmount: string = "2500000000";
let zapInEthAmount: string = "100000000000000000";

let timelockIsStrategist = false;

const walletAddress = process.env.WALLET_ADDR === undefined ? "" : process.env["WALLET_ADDR"];

let snapshotId: string;

let usdcContract: Contract;
let zapperContract: Contract;
let vaultContract: Contract;
let controllerContract: Contract;
let startegyContract: Contract;

let walletSigner: Signer;
let governanceSigner: Signer;
let strategistSigner: Signer;
let timelockSigner: Signer;

let wethAddress = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
let usdcAddress = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831";
const steerVaultAddrressUsdcWeth = "0x01476fcCa94502267008119B83Cea234dc3fA7D7";

const vaultName = "VaultSteerSushiWethUsdc";
const strategyName = "StrategySteerUsdcUsdce";

const poolFees = [
  {
    poolFee: 100,
    token0: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
    token1: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
  }, // usdc-usdce
  {
    poolFee: 500,
    token0: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
    token1: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
  }, // usdc-weth
  {
    poolFee: 100,
    token0: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
    token1: "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9",
  }, // usdc-usdt
  {
    poolFee: 500,
    token0: "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9",
    token1: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
  }, // usdt-weth
  {
    poolFee: 500,
    token0: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
    token1: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
  }, // usdce-weth
  // {
  //   poolFee: 100,
  //   token0: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
  //   token1: "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9",
  // },// usdc-usdt
  // weth-sushi
];

describe("Steer Zapper Test", async () => {
  // These reset the state after each test is executed
  beforeEach(async () => {
    snapshotId = await ethers.provider.send("evm_snapshot", []);
  });
  afterEach(async () => {
    await ethers.provider.send("evm_revert", [snapshotId]);
  });

  before(async () => {
    // Impersonate the wallet signer and add credit
    await network.provider.send("hardhat_impersonateAccount", [walletAddress]);
    console.log(`Impersonating account: ${walletAddress}`);

    // Getting some eth
    await ethers.provider.send("hardhat_setBalance", [
      walletAddress,
      "0x1158e460913d00000", // 20 ETH
    ]);
    let ethBalance = await ethers.provider.getBalance(walletAddress);
    console.log(`User's balance of ether is ${ethBalance}`);

    walletSigner = await returnSigner(walletAddress); 

    [timelockSigner, strategistSigner, governanceSigner] = await setupSigners(timelockIsStrategist);

    const controllerFactory = await ethers.getContractFactory("SteerController");
    controllerContract = await controllerFactory
      .connect(walletSigner)
      .deploy(
        governanceSigner.getAddress(),
        strategistSigner.getAddress(),
        timelockSigner.getAddress(),
        walletSigner.getAddress(),
        walletSigner.getAddress()
      );
    let controllerAdd = controllerContract.address;
    const vaultFactory = await ethers.getContractFactory(vaultName);
    vaultContract = await vaultFactory
      .connect(walletSigner)
      .deploy(walletSigner.getAddress(), walletSigner.getAddress(), controllerAdd);

    const stratFactory = await ethers.getContractFactory(strategyName);

    // Now we can deploy the new strategy
    startegyContract = await stratFactory
      .connect(walletSigner)
      .deploy(governanceSigner.getAddress(), strategistSigner.getAddress(), controllerAdd, timelockSigner.getAddress());

    const approveStrategy = await controllerContract
      .connect(timelockSigner)
      .approveStrategy(steerVaultAddrressUsdcWeth, startegyContract.address);
    const tx_approveStrategy = await approveStrategy.wait(1);

    if (!tx_approveStrategy.status) {
      console.error(`Error approving the strategy for: ${strategyName}`);
      return startegyContract;
    }
    console.log(`Approved Strategy in the Controller for: ${strategyName}\n`);

    await setStrategy(
      strategyName,
      controllerContract,
      timelockSigner,
      steerVaultAddrressUsdcWeth,
      startegyContract.address
    );

    const zapperFactory = await ethers.getContractFactory("SteerZapperBase");
    zapperContract = await zapperFactory.connect(walletSigner).deploy(
      walletSigner.getAddress(),
      [vaultContract.address]
    );

    usdcContract = await ethers.getContractAt("contracts/lib/erc20.sol:ERC20", usdcAddress, walletSigner);
    await overwriteTokenAmount(usdcAddress, walletAddress, zapInUsdcAmount, 9);

    // await overwriteTokenAmount(steerVaultAddrressUsdcWeth, startegyContract.address, strategySteerVaultAmount, 9);
  });

  const zapInETH = async () => {
    let _vaultBalanceBefore: BigNumber = await vaultContract
      .connect(walletSigner)
      .balanceOf(await walletSigner.getAddress());

    await zapperContract
      .connect(walletSigner)
      .zapInETH(vaultContract.address, 0, wethAddress, {
        value: zapInEthAmount,
      });

    let _vaultBalanceAfter: BigNumber = await vaultContract
      .connect(walletSigner)
      .balanceOf(await walletSigner.getAddress());

    return [_vaultBalanceBefore, _vaultBalanceAfter];
  };

  const zapIn = async () => {
    let _vaultBalanceBefore: BigNumber = await vaultContract
      .connect(walletSigner)
      .balanceOf(await walletSigner.getAddress());
    let _usdcBalanceBefore: BigNumber = await usdcContract
      .connect(walletSigner)
      .balanceOf(await walletSigner.getAddress());

    await usdcContract.connect(walletSigner).approve(zapperContract.address, zapInUsdcAmount);

    await zapperContract
      .connect(walletSigner)
      .zapIn(vaultContract.address, 0, usdcAddress, zapInUsdcAmount);

    let _vaultBalanceAfter: BigNumber = await vaultContract
      .connect(walletSigner)
      .balanceOf(await walletSigner.getAddress());

    let _usdcBalanceAfter: BigNumber = await usdcContract
      .connect(walletSigner)
      .balanceOf(await walletSigner.getAddress());

    return [_vaultBalanceBefore, _vaultBalanceAfter, _usdcBalanceBefore, _usdcBalanceAfter];
  };

  it("User wallet contains usdc balance", async function () {
    let usdcBalance: BigNumber = await usdcContract.balanceOf(await walletSigner.getAddress());
    expect(usdcBalance.toNumber()).to.be.gt(0);
    expect(usdcBalance.toString()).to.be.equals(zapInUsdcAmount);
  });
 
  it("Should ZapIn with Eth", async function () {
    let [_vaultBefore, _vaultAfter] = await zapInETH();
    expect(_vaultAfter).to.be.gt(_vaultBefore);
  });

  it("Should ZapIn with USDC", async function () {
    let [_vaultBefore, _vaultAfter, _usdcBalanceBefore, _usdcBalanceAfter] = await zapIn();

    expect(_vaultAfter).to.be.gt(_vaultBefore);
    expect(_usdcBalanceBefore).to.be.gt(_usdcBalanceAfter);
  });

  it("Should ZapOut and swap into ETH", async function () {
    let [, _vaultAfter] = await zapInETH();

    let ethBalanceBefore = await ethers.provider.getBalance(walletAddress);
    await vaultContract.connect(walletSigner).approve(zapperContract.address, _vaultAfter);
    await zapperContract.connect(walletSigner).zapOutAndSwapEth(vaultContract.address, _vaultAfter, 0);

    _vaultAfter = await vaultContract.connect(walletSigner).balanceOf(walletAddress);
    const ethBalanceAfter = await ethers.provider.getBalance(walletAddress);

    expect(_vaultAfter).to.be.equals(BigNumber.from("0x0"));
    expect(ethBalanceAfter).to.be.gt(ethBalanceBefore);
  });

  it("Should ZapOut and swap into USDC", async function () {
    let [, _vaultAfter] = await zapIn();

    let usdcBalanceBefore = await usdcContract.connect(walletSigner).balanceOf(await walletSigner.getAddress());

    await vaultContract.connect(walletSigner).approve(zapperContract.address, _vaultAfter);
    await zapperContract.connect(walletSigner).zapOutAndSwap(vaultContract.address, _vaultAfter, usdcAddress, 0);

    _vaultAfter = await vaultContract.connect(walletSigner).balanceOf(walletAddress);
    const usdcBalanceAfter = await usdcContract.connect(walletSigner).balanceOf(await walletSigner.getAddress());

    expect(_vaultAfter).to.be.equals(BigNumber.from("0x0"));
    expect(usdcBalanceAfter).to.be.gt(usdcBalanceBefore);
  });
});
