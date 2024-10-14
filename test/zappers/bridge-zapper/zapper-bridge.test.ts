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

const WETH_USDC_POOL_BASE = "0xd0b53D9277642d899DF5C87A3966A349A798F224";
const WETH_USDC_POOL_ARB = "0xC6962004f452bE9203591991D15f6b388e09E8D0";

let bridgeContractArb = "0xe8CDF27AcD73a434D661C84887215F7598e7d0d3";
let usdcAmountToZap = "50000";
let usdcAmountIn = "1050000";
let Data =
  "0xc7c7f5b30000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000013f3beea77a500000000000000000000000000000000000000000000000000000000000000000000000000000000000000005c70387dbc7c481dbc54d6d6080a5c936a883ba800000000000000000000000000000000000000000000000000000000000075e80000000000000000000000005C70387dbC7C481dbc54D6D6080A5C936a883Ba800000000000000000000000000000000000000000000000000000000000f4240000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

let wethArb = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
let usdcArb = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831";

const wethBase = "0x4200000000000000000000000000000000000006";
const usdcBase = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";

const sushiV3Factory = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";
const baseV3Factory = "0x38015D05f4fEC8AFe15D7cc0386a126574e8077B";
const uniV3FactoryArb = "0x1F98431c8aD98523631AE4a59f267346ea31F984";

const sushiV3Router = "0xFB7eF66a7e61224DD6FcD0D7d9C3be5C8B049b9f";
const baseV3Router = "0x1B8eea9315bE495187D873DA7773a874545D9D48";
const uniV3RouterArb = "0xE592427A0AEce92De3Edee1F18E0157C05861564";

const steerVaultAddrresswethUsdbc = "0x571A582064a07E0FA1d62Cb1cE4d1B7fcf9095d3";
const steerVaultAddressWethcbBtc = "0xD5A49507197c243895972782C01700ca27090Ee1";

const steerPeripheryArb = "0x806c2240793b3738000fcb62C66BF462764B903F";
const steerPeripheryBase = "0x16BA7102271dC83Fff2f709691c2B601DAD7668e";

const baseToken = "0xd07379a755A8f11B57610154861D694b2A0f615a";

const vaultName = "VaultSteerBaseWethcbBTC";
const strategyName = "StrategySteerWethcbBtc";

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

    // deploy zapper
    const zapperFactory = await ethers.getContractFactory("ZapperBridge");
    zapperContract = await zapperFactory
      .connect(walletSigner)
      .deploy(walletSigner.getAddress(), wethArb, usdcArb, uniV3RouterArb, uniV3FactoryArb, WETH_USDC_POOL_ARB);

    usdcContract = await ethers.getContractAt("contracts/lib/erc20.sol:ERC20", usdcArb, walletSigner);
    await overwriteTokenAmount(usdcArb, walletAddress, zapInUsdcAmount, 9);

    console.log(`Deployed Usdc: ${usdcContract.address}`);
    // await overwriteTokenAmount(steerVaultAddrresswethUsdbc, startegyContract.address, strategySteerVaultAmount, 9);
  });

  // const zapInETH = async () => {
  //   let _vaultBalanceBefore: BigNumber = await vaultContract
  //     .connect(walletSigner)
  //     .balanceOf(await walletSigner.getAddress());

  //   await zapperContract.connect(walletSigner).zapInETH(vaultContract.address, 0, wethBase, {
  //     value: zapInEthAmount,
  //   });

  //   let _vaultBalanceAfter: BigNumber = await vaultContract
  //     .connect(walletSigner)
  //     .balanceOf(await walletSigner.getAddress());

  //   return [_vaultBalanceBefore, _vaultBalanceAfter];
  // };

  // const zapIn = async () => {
  //   let _vaultBalanceBefore: BigNumber = await vaultContract
  //     .connect(walletSigner)
  //     .balanceOf(await walletSigner.getAddress());
  //   let _usdcBalanceBefore: BigNumber = await usdcContract
  //     .connect(walletSigner)
  //     .balanceOf(await walletSigner.getAddress());

  //   await usdcContract.connect(walletSigner).approve(zapperContract.address, zapInUsdcAmount);

  //   await zapperContract.connect(walletSigner).zapIn(vaultContract.address, 0, usdcArb, zapInUsdcAmount);

  //   let _vaultBalanceAfter: BigNumber = await vaultContract
  //     .connect(walletSigner)
  //     .balanceOf(await walletSigner.getAddress());

  //   let _usdcBalanceAfter: BigNumber = await usdcContract
  //     .connect(walletSigner)
  //     .balanceOf(await walletSigner.getAddress());

  //   return [_vaultBalanceBefore, _vaultBalanceAfter, _usdcBalanceBefore, _usdcBalanceAfter];
  // };

  it("User wallet contains usdc balance", async function () {
    let usdcBalance: BigNumber = await usdcContract.balanceOf(await walletSigner.getAddress());
    expect(usdcBalance.toNumber()).to.be.gt(0);
    expect(usdcBalance.toString()).to.be.equals(zapInUsdcAmount);
  });

  // it("Should ZapIn with Eth", async function () {
  //   let [_vaultBefore, _vaultAfter] = await zapInETH();
  //   expect(_vaultAfter).to.be.gt(_vaultBefore);
  // });

  it("Should ZapIn with USDC", async function () {
    await usdcContract.connect(walletSigner).approve(zapperContract.address, usdcAmountIn);

    let usdcBalanceBefore = await usdcContract.connect(walletSigner).balanceOf(await walletSigner.getAddress());

    await zapperContract.connect(walletSigner).zapIn(bridgeContractArb, Data, usdcAmountToZap, usdcAmountIn);

    let usdcBalanceAfter = await usdcContract.connect(walletSigner).balanceOf(await walletSigner.getAddress());

    let diff = usdcBalanceAfter.sub(usdcBalanceBefore);

    let contractEthBalance = await ethers.provider.getBalance(zapperContract.address);
    let contractUsdcBalance = await usdcContract.connect(walletSigner).balanceOf(zapperContract.address);

    expect(diff).to.be.equals(usdcAmountIn);
    expect(contractEthBalance).to.be.equals(0);
    expect(contractUsdcBalance).to.be.equals(0);
  });

  // it("Should ZapOut and swap into ETH", async function () {
  //   let [, _vaultAfter] = await zapInETH();

  //   let ethBalanceBefore = await ethers.provider.getBalance(walletAddress);
  //   await vaultContract.connect(walletSigner).approve(zapperContract.address, _vaultAfter);
  //   await zapperContract.connect(walletSigner).zapOutAndSwapEth(vaultContract.address, _vaultAfter, 0);

  //   _vaultAfter = await vaultContract.connect(walletSigner).balanceOf(walletAddress);
  //   const ethBalanceAfter = await ethers.provider.getBalance(walletAddress);
  //   expect(_vaultAfter).to.be.equals(BigNumber.from("0x0"));
  //   expect(ethBalanceAfter).to.be.gt(ethBalanceBefore);
  // });

  // it("Should ZapOut and swap into USDC", async function () {
  //   let [, _vaultAfter] = await zapIn();

  //   let usdcBalanceBefore = await usdcContract.connect(walletSigner).balanceOf(await walletSigner.getAddress());

  //   await vaultContract.connect(walletSigner).approve(zapperContract.address, _vaultAfter);
  //   await zapperContract.connect(walletSigner).zapOutAndSwap(vaultContract.address, _vaultAfter, usdcArb, 0);

  //   _vaultAfter = await vaultContract.connect(walletSigner).balanceOf(walletAddress);
  //   const usdcBalanceAfter = await usdcContract.connect(walletSigner).balanceOf(await walletSigner.getAddress());

  //   expect(_vaultAfter).to.be.equals(BigNumber.from("0x0"));
  //   expect(usdcBalanceAfter).to.be.gt(usdcBalanceBefore);
  // });
});
