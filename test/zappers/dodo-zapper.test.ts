/* eslint-disable no-undef */
const { ethers, network } = require("hardhat");
const hre = require("hardhat");
import { expect } from "chai";
import {Contract, ContractFactory, Signer, BigNumber} from "ethers";
import {
  setupSigners,
  reward_addr,
  treasury_addr
} from "../utils/static";
import {
  overwriteTokenAmount,
  returnSigner
} from "../utils/helpers";

let txnAmt: string = "2500000000000000000";

const wallet_addr = process.env.WALLET_ADDR === undefined ? '' : process.env['WALLET_ADDR'];
let name = "DodoUsdc";
let vault_addr = "0x5A06beea8573C59AFe9a15A3f01D6B4505b89339";
// let strategy_addr = test_case.strategyAddress;
// let slot = test_case.slot;
let timelockIsStrategist = false;

let snapshotId: string;

let controller_addr= "0x8Ff4Bf80b46cEd83e0d5dD99DDe79458fF55F3b0";

let DodoZapper: Contract; 
let zapper_addr: string;

let assetContract: Contract;
let wantContract: Contract;
let Controller: Contract;
let Vault: Contract;

let governanceSigner: Signer;
let strategistSigner: Signer;
let walletSigner: Signer;
let controllerSigner: Signer;
let timelockSigner: Signer;


let asset_addr = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8";
let want_addr = "0x7eBd8a1803cE082d4dE609C0aA0813DD842BD4DB"

describe( "Tests for Dodo Zapper", async () => {

    // These reset the state after each test is executed 
    beforeEach(async () => {
      snapshotId = await ethers.provider.send('evm_snapshot');
    });

    afterEach(async () => {
        await ethers.provider.send('evm_revert', [snapshotId]);
    });


    before(async () => {

        const vaultName = `Vault${name}`;

        // Impersonate the wallet signer and add credit
        await network.provider.send('hardhat_impersonateAccount', [wallet_addr]);
        console.log(`Impersonating account: ${wallet_addr}`);
        walletSigner = await returnSigner(wallet_addr);
        [timelockSigner, strategistSigner, governanceSigner] = await setupSigners(timelockIsStrategist); 

        // Add a new case here when including a new family of folding strategies
        Controller = await ethers.getContractAt("Controller", controller_addr, governanceSigner);
        console.log(`Using controller: ${controller_addr}\n`);


        // load user wallet with initial amount
        await hre.network.provider.send("hardhat_setBalance", [
            await walletSigner.getAddress(), 
            "0x10000000000000000000000",]
        );

        const dodoFactory = await ethers.getContractFactory('DodoVaultZapper');
        DodoZapper = await dodoFactory.connect(walletSigner).deploy();

        Vault = await ethers.getContractAt(vaultName, vault_addr, walletSigner);

  
        zapper_addr = DodoZapper.address;
        console.log(`Deployed DodoZapper at ${zapper_addr}`);

        assetContract = await ethers.getContractAt("ERC20", asset_addr, walletSigner);
        await overwriteTokenAmount(asset_addr, wallet_addr, txnAmt, 51);

        wantContract = await ethers.getContractAt("ERC20", want_addr, walletSigner);
      
    })

    it("user wallet contains asset balance", async function () {
      let BNBal = await assetContract.balanceOf(await walletSigner.getAddress());
      console.log(`The balance of BNBal is ${BNBal}`);

      const BN = ethers.BigNumber.from(txnAmt)._hex.toString();
      console.log(`The balance of BN is ${BN}`);

      expect(BNBal).to.be.equals(BN);
    });

    it("Vault initialized with zero balance for user", async function() {
      let BNBal = await Vault.balanceOf(await walletSigner.getAddress());
      expect(BNBal).to.be.equals(BigNumber.from("0x0"));
    });
    

    it("Should deposit from the zapper to the vault", async function() {
      let _vaultBefore = await Vault.connect(walletSigner).balanceOf(await walletSigner.getAddress()); 
      console.log(`The balance the user has in the vault before depositing is ${_vaultBefore}`); 

      await assetContract.connect(walletSigner).approve(zapper_addr, txnAmt);
      await DodoZapper.connect(walletSigner).zapIn(vault_addr, asset_addr, txnAmt);

      let _vaultAfter = await Vault.connect(walletSigner).balanceOf(await walletSigner.getAddress()); 
      console.log(`The balance the user has in the vault after depositing is ${_vaultAfter}`); 

      expect(_vaultAfter).to.be.gt(_vaultBefore);

    });

    // it("Should withdraw from the vault and zap to the native tokens", async function() {
    //   await assetContract.connect(walletSigner).approve(zapper_addr, txnAmt);
    //   await StargateZapper.connect(walletSigner).zapIn(vault_addr, asset_addr, txnAmt, 7);

    //   let userBal = await assetContract.connect(walletSigner).balanceOf(wallet_addr);
    //   expect(userBal).to.be.equals(BigNumber.from("0x0"));

    //   let _amounttoWithdraw = await Vault.connect(walletSigner).totalSupply(); 

    //   let _balBefore = await assetContract.connect(walletSigner).balanceOf(wallet_addr);
    //   let _vaultBal = await wantContract.connect(walletSigner).balanceOf(vault_addr);

    //   expect(_vaultBal).to.be.equals(_amounttoWithdraw);

    //   await Vault.connect(walletSigner).approve(zapper_addr, _amounttoWithdraw);
    //   await StargateZapper.connect(walletSigner).zapOut(vault_addr, _amounttoWithdraw, asset_addr, 7);

    //   let _balAfter = await assetContract.connect(walletSigner).balanceOf(wallet_addr);

    //   expect(_balAfter).to.be.gt(_balBefore);
    // })


})
