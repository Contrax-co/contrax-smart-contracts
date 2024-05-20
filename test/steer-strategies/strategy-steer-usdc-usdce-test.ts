/* eslint-disable no-undef */
import { ethers, network } from "hardhat";
import { expect } from "chai";
import { Contract, Signer, BigNumber } from "ethers";
import { overwriteTokenAmount, returnSigner, setStrategy } from "../utils/helpers";
import { setupSigners } from "../utils/static";

const walletAddress = process.env.WALLET_ADDR === undefined ? "" : process.env["WALLET_ADDR"];

let zapInUsdcAmount: string = "2500000000";
//1.5k Arb
let zapInArbAmount: string = "1500000000000000000000";
let timelockIsStrategist = false;
let snapshotId: string;

let arbContract: Contract;
let usdcContract: Contract;
let vaultContract: Contract;
let controllerContract: Contract;
let strategyContract: Contract;

let walletSigner: Signer;
let governanceSigner: Signer;
let strategistSigner: Signer;
let timelockSigner: Signer;

let wethAddress = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
let usdcAddress = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831";
let arbAddress = "0x912CE59144191C1204E64559FE8253a0e49E6548";

const steerVaultAddrress = "0x3eE813a6fCa2AaCAF0b7C72428fC5BC031B9BD65";

const vaultName = "VaultSteerSushiUsdcUsdce";
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
];

describe("Strategy Steer Test", async () => {
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
    strategyContract = await stratFactory
      .connect(walletSigner)
      .deploy(
        governanceSigner.getAddress(),
        strategistSigner.getAddress(),
        controllerAdd,
        timelockSigner.getAddress()
      );

    const approveStrategy = await controllerContract
      .connect(timelockSigner)
      .approveStrategy(steerVaultAddrress, strategyContract.address);
    const tx_approveStrategy = await approveStrategy.wait(1);

    if (!tx_approveStrategy.status) {
      console.error(`Error approving the strategy for: ${strategyName}`);
      return strategyContract;
    }
    console.log(`Approved Strategy in the Controller for: ${strategyName}\n`);

    await setStrategy(strategyName, controllerContract, timelockSigner, steerVaultAddrress, strategyContract.address);

    usdcContract = await ethers.getContractAt("contracts/lib/erc20.sol:ERC20", usdcAddress, walletSigner);
    await overwriteTokenAmount(usdcAddress, strategyContract.address, zapInUsdcAmount, 9);

    await strategyContract.connect(timelockSigner).setRewardToken(usdcAddress);


    //Set pool fees for Usdc/Usdce
    await strategyContract
      .connect(timelockSigner)
      .setPoolFees("0xaf88d065e77c8cC2239327C5EDb3A432268e5831", "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8", 100);
  });

  it("Strategy Should contains Usdc balance", async function () {
    let usdcBal: BigNumber = await usdcContract.balanceOf(strategyContract.address);
    expect(usdcBal.toNumber()).to.be.gt(0);
    expect(usdcBal.toString()).to.be.equals(zapInUsdcAmount);
  });

  it("Should exchange strategy usdc to steerVault token", async function () {
    let usdcBalBefore: BigNumber = await usdcContract.balanceOf(strategyContract.address);
    let txRes = await strategyContract.connect(governanceSigner).harvest();
    let usdcBalAfter: BigNumber = await usdcContract.balanceOf(strategyContract.address);

    const txReceipt = await txRes.wait();

    expect(usdcBalAfter.toNumber()).to.be.lt(usdcBalBefore.toNumber());
    // Now you can check for the event
    expect(txReceipt.events?.some((event: { event: string }) => event.event === "Harvest")).to.be.true;
  });
});
