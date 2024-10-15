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
let ethAmountOut = "21551604936134";
let usdcAmountToZap = "56000";
let usdcAmountIn = "1000000";
let Data =
  "0xc7c7f5b3000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000001399dfc1adc600000000000000000000000000000000000000000000000000000000000000000000000000000000000000005c70387dbc7c481dbc54d6d6080a5c936a883ba800000000000000000000000000000000000000000000000000000000000075e80000000000000000000000005c70387dbc7c481dbc54d6d6080a5c936a883ba800000000000000000000000000000000000000000000000000000000000f4240000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

let wethArb = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
let usdcArb = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831";

const wethBase = "0x4200000000000000000000000000000000000006";
const usdcBase = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";

let wCore = "0x40375C92d9FAf44d2f9db9Bd9ba41a3317a2404f";
let usdcCore = "0xa4151B2B3e269645181dCcF2D426cE75fcbDeca9";

const sushiV3FactoryBase = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";
const baseV3FactoryBase = "0x38015D05f4fEC8AFe15D7cc0386a126574e8077B";
const uniV3FactoryArb = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
const coreXV3FactoryCore = "0x526190295AFB6b8736B14E4b42744FBd95203A3a";

const sushiV3RouterBase = "0xFB7eF66a7e61224DD6FcD0D7d9C3be5C8B049b9f";
const baseV3RouterBase = "0x1B8eea9315bE495187D873DA7773a874545D9D48";
const uniV3RouterArb = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
const coreXV3RouterCore = "0xcc85A7870902f5e3dCef57E4d44F42b613c87a2E";

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
      .deploy(walletSigner.getAddress(), wCore, usdcCore, coreXV3RouterCore, coreXV3FactoryCore);

    usdcContract = await ethers.getContractAt("contracts/lib/erc20.sol:ERC20", usdcCore, walletSigner);
    await overwriteTokenAmount(usdcCore, walletAddress, zapInUsdcAmount, 9);

    console.log(`Deployed Usdc: ${usdcContract.address}`);
    // await overwriteTokenAmount(steerVaultAddrresswethUsdbc, startegyContract.address, strategySteerVaultAmount, 9);
  });

  // it("User wallet contains usdc balance", async function () {
  //   let usdcBalance: BigNumber = await usdcContract.balanceOf(await walletSigner.getAddress());
  //   expect(usdcBalance.toNumber()).to.be.gt(0);
  //   expect(usdcBalance.toString()).to.be.equals(zapInUsdcAmount);
  // });

  it("Should ZapIn with USDC", async function () {
    // await usdcContract.connect(walletSigner).approve(zapperContract.address, zapInUsdcAmount);

    let usdcBalanceBefore = await usdcContract.connect(walletSigner).balanceOf(await walletSigner.getAddress());

    await zapperContract
      .connect(walletSigner)
      .zapIn(bridgeContractArb, Data, usdcAmountToZap, ethAmountOut, usdcAmountIn, {
        value: zapInEthAmount,
      });

    let usdcBalanceAfter = await usdcContract.connect(walletSigner).balanceOf(await walletSigner.getAddress());

    let diff = usdcBalanceAfter.sub(usdcBalanceBefore);

    let contractEthBalance = await ethers.provider.getBalance(zapperContract.address);
    let contractUsdcBalance = await usdcContract.connect(walletSigner).balanceOf(zapperContract.address);

    expect(diff).to.be.equals(usdcAmountIn);
    expect(contractEthBalance).to.be.equals(0);
    expect(contractUsdcBalance).to.be.equals(0);
  });
});
