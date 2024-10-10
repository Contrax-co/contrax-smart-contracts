/* eslint-disable no-undef */
import { ethers, network } from "hardhat";
import { expect } from "chai";
import { Contract, Signer, BigNumber } from "ethers";
import { overwriteTokenAmount, returnSigner, setStrategy, increaseTime, fastForwardAWeek } from "../../utils/helpers";
import { setupSigners } from "../../utils/static";

let zapInUsdcAmount: string = "25000000000";
let zapInEthAmount: string = "10000000000000000000";

let timelockIsStrategist = false;

const walletAddress = process.env.WALLET_ADDR === undefined ? "" : process.env["WALLET_ADDR"];

let snapshotId: string;

let zapperContract: Contract;
let vaultContract: Contract;
let controllerContract: Contract;
let startegyContract: Contract;

let walletSigner: Signer;
let governanceSigner: Signer;
let strategistSigner: Signer;
let timelockSigner: Signer;

let stCoreAddress = "0xb3A8F0f0da9ffC65318aA39E55079796093029AD";

const vaultName = "VaultCoreBase";
const strategyName = "StrategyCore";

describe("Core Zapper Test", async () => {
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

    const controllerFactory = await ethers.getContractFactory("CoreController");
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
      .deploy(stCoreAddress, walletSigner.getAddress(), walletSigner.getAddress(), controllerAdd);

    const stratFactory = await ethers.getContractFactory(strategyName);

    // Now we can deploy the new strategy
    startegyContract = await stratFactory
      .connect(walletSigner)
      .deploy(
        stCoreAddress,
        governanceSigner.getAddress(),
        strategistSigner.getAddress(),
        controllerAdd,
        timelockSigner.getAddress()
      );

    const approveStrategy = await controllerContract
      .connect(timelockSigner)
      .approveStrategy(stCoreAddress, startegyContract.address);
    const tx_approveStrategy = await approveStrategy.wait(1);

    if (!tx_approveStrategy.status) {
      console.error(`Error approving the strategy for: ${strategyName}`);
      return startegyContract;
    }
    console.log(`Approved Strategy in the Controller for: ${strategyName}\n`);

    await setStrategy(strategyName, controllerContract, timelockSigner, stCoreAddress, startegyContract.address);

    const zapperFactory = await ethers.getContractFactory("CoreZapperBase");
    zapperContract = await zapperFactory
      .connect(walletSigner)
      .deploy(walletSigner.getAddress(), [vaultContract.address]);

  });

  const zapInETH = async () => {
    let _vaultBalanceBefore: BigNumber = await vaultContract
      .connect(walletSigner)
      .balanceOf(await walletSigner.getAddress());

    await zapperContract.connect(walletSigner).zapInETH(vaultContract.address, 0, {
      value: zapInEthAmount,
    });

    let _vaultBalanceAfter: BigNumber = await vaultContract
      .connect(walletSigner)
      .balanceOf(await walletSigner.getAddress());

    return [_vaultBalanceBefore, _vaultBalanceAfter];
  };

  const redeemCore = async (_amount: BigNumber) => {
    await vaultContract.connect(walletSigner).approve(zapperContract.address, _amount);
    await zapperContract.connect(walletSigner).redeem(vaultContract.address, _amount);

    let _vaultBalanceAfter: BigNumber = await vaultContract
      .connect(walletSigner)
      .balanceOf(await walletSigner.getAddress());

    return _vaultBalanceAfter;
  };

 
  it("Should ZapIn with Eth", async function () {
    let [_vaultBefore, _vaultAfter] = await zapInETH();
    expect(_vaultAfter).to.be.gt(_vaultBefore);
  });

  it("Should redeem stCore before zapOut", async function () {
    let [, _vaultAfter] = await zapInETH();

    let vaultBalAfterRedeem = await redeemCore(_vaultAfter);

    expect(vaultBalAfterRedeem).to.be.lt(_vaultAfter);
  });

  it("Should ZapOut after redeem", async function () {
    let [, _vaultAfter] = await zapInETH();

    await redeemCore(_vaultAfter);

    await fastForwardAWeek();

    let ethBalanceBefore = await ethers.provider.getBalance(walletAddress);

    await zapperContract.connect(walletSigner).zapOutAndSwapEth(vaultContract.address);

    let ethBalanceAfter = await ethers.provider.getBalance(walletAddress);

    expect(ethBalanceAfter).to.be.gt(ethBalanceBefore);
  });

});
