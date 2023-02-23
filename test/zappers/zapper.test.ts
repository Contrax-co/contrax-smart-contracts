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

let txnAmt: string = "250000000000000";

const wallet_addr = process.env.WALLET_ADDR === undefined ? '' : process.env['WALLET_ADDR'];
let name = "FishWstEthWeth";
let vault_addr = "0x33BD22e9D83C7A74199405aF2D8dfA21309F719F";
// let strategy_addr = test_case.strategyAddress;
// let slot = test_case.slot;
let timelockIsStrategist = false;

let snapshotId: string;

let controller_addr= "0xF36059454bE1e87E88506DdcF2aa65a1CEF8C1bF";

let Zapper: Contract; 
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


let asset_addr = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
let want_addr = "0xe263353986a4638144c41E44cEBAc9d0A76ECab3"

describe( "Tests for Zapper", async () => {

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

        // Getting some eth
        await ethers.provider.send("hardhat_setBalance", [
          wallet_addr,
          "0x1158e460913d00000", // 20 ETH
        ]);
        let ethBal = await ethers.provider.getBalance(wallet_addr); 
        console.log(`User's balance of ether is ${ethBal}`);
        
        walletSigner = await returnSigner(wallet_addr);
        [timelockSigner, strategistSigner, governanceSigner] = await setupSigners(timelockIsStrategist); 

        // Add a new case here when including a new family of folding strategies
        Controller = await ethers.getContractAt("Controller", controller_addr, governanceSigner);
        console.log(`Using controller: ${controller_addr}\n`);


        // // load user wallet with initial amount
        // await hre.network.provider.send("hardhat_setBalance", [
        //     await walletSigner.getAddress(), 
        //     "0x10000000000000000000000",]
        // );

        const zapperFactory = await ethers.getContractFactory('VaultZapEthFish');
        Zapper = await zapperFactory.connect(walletSigner).deploy();

        Vault = await ethers.getContractAt(vaultName, vault_addr, walletSigner);

  
        zapper_addr = Zapper.address;
        console.log(`Deployed Zapper at ${zapper_addr}`);

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

      await Zapper.connect(walletSigner).zapInETH(vault_addr, 0, asset_addr, {value: "10000000000000000000"});

      let _vaultAfter = await Vault.connect(walletSigner).balanceOf(await walletSigner.getAddress()); 
      console.log(`The balance the user has in the vault after depositing is ${_vaultAfter}`); 

      expect(_vaultAfter).to.be.gt(_vaultBefore);

    });

    it("Should withdraw from the vault and zap to the native tokens", async function() {
      await Zapper.connect(walletSigner).zapInETH(vault_addr, 0, asset_addr, {value: "10000000000000000000"});

      let _amounttoWithdraw = await Vault.connect(walletSigner).balanceOf(wallet_addr); 

      let _balBefore = await ethers.provider.getBalance(wallet_addr); 
      console.log(`The balance the user has before zapping Out is ${_balBefore}`); 

      await Vault.connect(walletSigner).approve(zapper_addr, _amounttoWithdraw);
      await Zapper.connect(walletSigner).zapOutAndSwapEth(vault_addr, _amounttoWithdraw, 0);

      let _balAfter = await ethers.provider.getBalance(wallet_addr); 
      console.log(`the balance after is ${_balAfter}`);

      expect(_balAfter).to.be.gt(_balBefore);
    }); 


})
