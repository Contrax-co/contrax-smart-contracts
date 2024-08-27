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
let usdcArb = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831";

const sushiV3Factory = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";

const wethBase = "0x4200000000000000000000000000000000000006";
const usdcBase = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";

const sushiV3Router = "0xFB7eF66a7e61224DD6FcD0D7d9C3be5C8B049b9f";

const steerVaultAddrresswethUsdbc = "0x571A582064a07E0FA1d62Cb1cE4d1B7fcf9095d3";
// const steerVaultAddrressUsdcUsdt = "0x5DbAD371890C3A89f634e377c1e8Df987F61fB64";

const steerPeripheryArb = "0x806c2240793b3738000fcb62C66BF462764B903F";
const steerPeripheryBase = "0x16BA7102271dC83Fff2f709691c2B601DAD7668e";

const baseToken = "0xd07379a755A8f11B57610154861D694b2A0f615a";

const vaultName = "VaultSteerSushiWethUsdbc";
const strategyName = "StrategySteerUsdbcWeth";

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
      .deploy(
        governanceSigner.getAddress(),
        strategistSigner.getAddress(),
        controllerAdd,
        timelockSigner.getAddress(),
        wethBase,
        sushiV3Factory,
        steerPeripheryBase
      );

    const approveStrategy = await controllerContract
      .connect(timelockSigner)
      .approveStrategy(steerVaultAddrresswethUsdbc, startegyContract.address);
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
      steerVaultAddrresswethUsdbc,
      startegyContract.address
    );

    // set Vault in controller

    await controllerContract.connect(timelockSigner).setVault(steerVaultAddrresswethUsdbc, vaultContract.address);

    // deploy zapper
    const zapperFactory = await ethers.getContractFactory("SteerZapperBase");
    zapperContract = await zapperFactory
      .connect(walletSigner)
      .deploy(walletSigner.getAddress(), wethBase, sushiV3Router, sushiV3Factory, steerPeripheryBase, [
        vaultContract.address,
      ]);

    usdcContract = await ethers.getContractAt("contracts/lib/erc20.sol:ERC20", usdcBase, walletSigner);
    await overwriteTokenAmount(usdcBase, walletAddress, zapInUsdcAmount, 9);

    console.log(`Deployed Usdc: ${usdcContract.address}`);
    // await overwriteTokenAmount(steerVaultAddrresswethUsdbc, startegyContract.address, strategySteerVaultAmount, 9);
  });

  const zapInETH = async () => {
    let _vaultBalanceBefore: BigNumber = await vaultContract
      .connect(walletSigner)
      .balanceOf(await walletSigner.getAddress());

    await zapperContract.connect(walletSigner).zapInETH(vaultContract.address, 0, wethBase, {
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

    await zapperContract.connect(walletSigner).zapIn(vaultContract.address, 0, usdcBase, zapInUsdcAmount);

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
    await zapperContract.connect(walletSigner).zapOutAndSwap(vaultContract.address, _vaultAfter, usdcBase, 0);

    _vaultAfter = await vaultContract.connect(walletSigner).balanceOf(walletAddress);
    const usdcBalanceAfter = await usdcContract.connect(walletSigner).balanceOf(await walletSigner.getAddress());

    expect(_vaultAfter).to.be.equals(BigNumber.from("0x0"));
    expect(usdcBalanceAfter).to.be.gt(usdcBalanceBefore);
  });
});
