/* eslint-disable no-undef */
import { ethers, network } from "hardhat";
import { expect } from "chai";
import { Contract, Signer, BigNumber } from "ethers";
import { overwriteTokenAmount, returnSigner, setStrategy } from "../../utils/helpers";
import { setupSigners } from "../../utils/static";

let zapInUsdcAmount: string = "250000000";
let zapInEthAmount: string = "1000000000000000000";

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

let wethArb = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
let usdcArb = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831";

let wethPol = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";

let usdcPol = "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359";
let wPol = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";

const wethBase = "0x4200000000000000000000000000000000000006";
const usdcBase = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";

const sushiV3Factory = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";
const baseV3FactoryBase = "0x38015D05f4fEC8AFe15D7cc0386a126574e8077B";
const uniV3FactoryArb = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
const uniV3FactoryPol = "0x1F98431c8aD98523631AE4a59f267346ea31F984";

const sushiV3Router = "0xFB7eF66a7e61224DD6FcD0D7d9C3be5C8B049b9f";
const baseV3Router = "0x1B8eea9315bE495187D873DA7773a874545D9D48";
const uniV3RouterArb = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
const uniV3RouterPol = "0xE592427A0AEce92De3Edee1F18E0157C05861564";

const gammaVaultWpolWeth = "0x02203f2351E7aC6aB5051205172D3f772db7D814";
const gammaUniProxy = "0xA42d55074869491D60Ac05490376B74cF19B00e6";

const wpol_weth_poolId = "0";
const masterChef = "0x20ec0d06F447d550fC6edee42121bc8C1817b97D";

const vaultName = "VaultGammaWpolWeth";
const strategyName = "StrategyGamma";

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

    const controllerFactory = await ethers.getContractFactory("GammaController");
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
        wpol_weth_poolId,
        gammaVaultWpolWeth,
        governanceSigner.getAddress(),
        strategistSigner.getAddress(),
        controllerAdd,
        timelockSigner.getAddress(),
        masterChef
      );

    const approveStrategy = await controllerContract
      .connect(timelockSigner)
      .approveStrategy(gammaVaultWpolWeth, startegyContract.address);
    const tx_approveStrategy = await approveStrategy.wait(1);

    if (!tx_approveStrategy.status) {
      console.error(`Error approving the strategy for: ${strategyName}`);
      return startegyContract;
    }
    console.log(`Approved Strategy in the Controller for: ${strategyName}\n`);

    await setStrategy(strategyName, controllerContract, timelockSigner, gammaVaultWpolWeth, startegyContract.address);

    // set Vault in controller

    await controllerContract.connect(timelockSigner).setVault(gammaVaultWpolWeth, vaultContract.address);

    // deploy zapper

    const zapperFactory = await ethers.getContractFactory("GammaZapper");
    zapperContract = await zapperFactory
      .connect(walletSigner)
      .deploy(wPol, usdcPol, uniV3RouterPol, uniV3FactoryPol, [vaultContract.address], gammaUniProxy);

    console.log(`Deployed Zapper: ${zapperContract.address}`);

    usdcContract = await ethers.getContractAt("contracts/lib/erc20.sol:ERC20", usdcPol, walletSigner);
    await overwriteTokenAmount(usdcPol, walletAddress, zapInUsdcAmount, 9);

    console.log(`Deployed Usdc: ${usdcContract.address}`);
    // await overwriteTokenAmount(steerVaultAddrresswethUsdbc, startegyContract.address, strategySteerVaultAmount, 9);
  });

  const zapInETH = async () => {
    let _vaultBalanceBefore: BigNumber = await vaultContract
      .connect(walletSigner)
      .balanceOf(await walletSigner.getAddress());

    await zapperContract.connect(walletSigner).zapInETH(vaultContract.address, 0, wPol, {
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

    await zapperContract.connect(walletSigner).zapIn(vaultContract.address, 0, usdcPol, zapInUsdcAmount);

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
    await zapperContract.connect(walletSigner).zapOutAndSwap(vaultContract.address, _vaultAfter, usdcPol, 0);

    _vaultAfter = await vaultContract.connect(walletSigner).balanceOf(walletAddress);
    const usdcBalanceAfter = await usdcContract.connect(walletSigner).balanceOf(await walletSigner.getAddress());

    expect(_vaultAfter).to.be.equals(BigNumber.from("0x0"));
    expect(usdcBalanceAfter).to.be.gt(usdcBalanceBefore);
  });
});
