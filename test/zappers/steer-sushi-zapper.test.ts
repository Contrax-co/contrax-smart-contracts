/* eslint-disable no-undef */
import { ethers, network } from "hardhat";
import { expect } from "chai";
import { Contract, Signer, BigNumber } from "ethers";
import { overwriteTokenAmount, returnSigner } from "../utils/helpers";

let zapInUsdcAmount: string = "2500000000000";
let zapInEthAmount: string = "15000000000000000000";

const walletAddress = process.env.WALLET_ADDR === undefined ? "" : process.env["WALLET_ADDR"];

let snapshotId: string;

let usdcContract: Contract;
let zapperContract: Contract;
let vaultContract: Contract;

let walletSigner: Signer;

let wethAddress = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
let usdcAddress = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831";

const vaultName = "VaultSteerSushiWethSushi";


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

    const vaultFactory = await ethers.getContractFactory(vaultName);
    vaultContract = await vaultFactory
      .connect(walletSigner)
      .deploy(walletSigner.getAddress(), walletSigner.getAddress());

    const zapperFactory = await ethers.getContractFactory("SteerSushiZapperBase");
    zapperContract = await zapperFactory.connect(walletSigner).deploy(
      walletSigner.getAddress(),
    );
    zapperContract.connect(walletSigner).addToWhitelist(vaultContract.address);
    usdcContract = await ethers.getContractAt("contracts/lib/erc20.sol:ERC20", usdcAddress, walletSigner);
    await overwriteTokenAmount(usdcAddress, walletAddress, zapInUsdcAmount, 9);
  });

  const zapInETH = async () => {
    let _vaultBalanceBefore: BigNumber = await vaultContract
      .connect(walletSigner)
      .balanceOf(await walletSigner.getAddress());

    const tokenInAmount0 = BigNumber.from(zapInEthAmount).div(2);
    const tokenInAmount1 = BigNumber.from(zapInEthAmount).sub(tokenInAmount0);

    await zapperContract
      .connect(walletSigner)
      .zapInETH(vaultContract.address, 0, wethAddress, tokenInAmount0.toString(), tokenInAmount1.toString(), {
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

    const tokenInAmount0 = BigNumber.from(zapInUsdcAmount).div(2);
    const tokenInAmount1 = BigNumber.from(zapInUsdcAmount).sub(tokenInAmount0);
    await zapperContract
      .connect(walletSigner)
      .zapIn(vaultContract.address, 0, usdcAddress, tokenInAmount0.toString(), tokenInAmount1.toString());

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
