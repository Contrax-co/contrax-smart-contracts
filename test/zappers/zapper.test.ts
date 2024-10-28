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

let txnAmt: string = "2500000000000";

const wallet_addr = process.env.WALLET_ADDR === undefined ? '' : process.env['WALLET_ADDR'];
let name = "PeapodsGmxOhm";
let vault_addr = "0x20ee953C13E4af44D8Dcdb7A799DD9010b7603B6";
// let strategy_addr = test_case.strategyAddress;
// let slot = test_case.slot;
let timelockIsStrategist = false;

let snapshotId: string;

let controller_addr= "0xc3BB0e5134672f7DFb574cDB9adDDe10d6f2ADd8";

let Zapper: Contract; 
let zapper_addr: string;

let assetContract: Contract;
let assetContract2: Contract;
let wantContract: Contract;
let Controller: Contract;
let Vault: Contract;

let governanceSigner: Signer;
let strategistSigner: Signer;
let walletSigner: Signer;
let controllerSigner: Signer;
let timelockSigner: Signer;


let asset_addr = "0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a";    // GMX
let asset_addr2 = "0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a";   // GMX
let asset_addr3 = "0xf0cb2dc0db5e6c66B9a70Ac27B06b878da017028";   // OHM
let want_addr = "0x91aDF4a1A94A1a9E8a9d4b5B53DD7D8EFF816892"; // apGMX - apOHM

let ap_addr = "0x8CB10B11Fad33cfE4758Dc9977d74CE7D2fB4609";
let ap_addr2 = "0xEb1A8f8Ea373536600082BA9aE2DB97327513F7d";

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

        const zapperFactory = await ethers.getContractFactory('VaultLPZapperPeapods');
        Zapper = await zapperFactory.connect(walletSigner).deploy();

        Vault = await ethers.getContractAt(vaultName, vault_addr, walletSigner);

  
        zapper_addr = Zapper.address;
        console.log(`Deployed Zapper at ${zapper_addr}`);

        // assetContract = await ethers.getContractAt("ERC20", asset_addr, walletSigner);
        // await overwriteTokenAmount(asset_addr, wallet_addr, txnAmt, 2);

        // Connects to asset 2 (GMX) contract and adds a balance
        assetContract2 = await ethers.getContractAt("ERC20", asset_addr2, walletSigner);
        await overwriteTokenAmount(asset_addr2, wallet_addr, txnAmt, 5);


        wantContract = await ethers.getContractAt("ERC20", want_addr, walletSigner);
      
    });

    const zapInETH = async () => {
      let _vaultBefore = await Vault.connect(walletSigner).balanceOf(await walletSigner.getAddress()); 

      // whitelist vault address
      await Zapper.connect(governanceSigner).addToWhitelist(vault_addr);

      // set apTokens and baseTokens
      await Zapper.connect(governanceSigner).setApTokens(ap_addr, asset_addr); 
      await Zapper.connect(governanceSigner).setApTokens(ap_addr2, asset_addr3);

      await Zapper.connect(governanceSigner).setBaseTokens(ap_addr, asset_addr); 
      await Zapper.connect(governanceSigner).setBaseTokens(ap_addr2, asset_addr3);

      console.log("before zapping")


      await Zapper.connect(walletSigner).zapInETH(vault_addr, 0, asset_addr, {value: "15000000000000000000"});

      let _vaultAfter = await Vault.connect(walletSigner).balanceOf(await walletSigner.getAddress()); 

      return [_vaultBefore, _vaultAfter]; 

    }

    const zapIn = async () => {
      let _vaultBefore = await Vault.connect(walletSigner).balanceOf(await walletSigner.getAddress()); 
      
      await assetContract2.connect(walletSigner).approve(zapper_addr, txnAmt);
      await Zapper.connect(walletSigner).zapIn(vault_addr, 0, asset_addr2, txnAmt);

      let _vaultAfter = await Vault.connect(walletSigner).balanceOf(await walletSigner.getAddress());

      let assetBalAfter2 = await assetContract2.connect(walletSigner).balanceOf(await walletSigner.getAddress());

      return [_vaultBefore, _vaultAfter, assetBalAfter2]; 

    }

    it.only("user wallet contains asset balance", async function () {
      //let BNBal = await assetContract.balanceOf(await walletSigner.getAddress());
      let BNBal2 = await assetContract2.balanceOf(await walletSigner.getAddress());

      const BN = ethers.BigNumber.from(txnAmt)._hex.toString();

      expect(BNBal2).to.be.equals(BN);
      //expect(BNBal2).to.be.equals(BNBal).to.be.equals(BN);
    });

    it.only("Should deposit from the zapper to the vault", async function() {
      let [_vaultBefore, _vaultAfter] = await zapInETH(); 

      //expect(_vaultBefore).to.be.equals(BigNumber.from("0x0"));
      console.log("the value in the vault before is", _vaultBefore);
      expect(_vaultAfter).to.be.gt(_vaultBefore);

    });

    it("Should deposit usdc from the zapper into the vault", async function() {
      let [_vaultBefore, _vaultAfter, assetBalAfter2] = await zapIn();

      //expect(_vaultBefore).to.be.equals(BigNumber.from("0x0"));
      expect(_vaultAfter).to.be.gt(_vaultBefore);
      expect(assetBalAfter2).to.be.equals(BigNumber.from("0x0"));

    });

    it("Should withdraw from the vault and zap into the native tokens", async function() {
      let ethBal = await ethers.provider.getBalance(wallet_addr); 

      let[, _vaultAfter] = await zapInETH();

      await Vault.connect(walletSigner).approve(zapper_addr, _vaultAfter);
      await Zapper.connect(walletSigner).zapOutAndSwapEth(vault_addr, _vaultAfter, 0);

      _vaultAfter = await Vault.connect(walletSigner).balanceOf(wallet_addr);
      const _balAfter = await ethers.provider.getBalance(wallet_addr); 
      const _balDifference = (_balAfter/ethBal).toPrecision(3);

      expect(_vaultAfter).to.be.equals(BigNumber.from("0x0"));
      expect(Number(_balDifference)).to.be.gt(0.99);
    }); 

    it("Should withdraw from vault andd zap into usdc", async function () {
      let assetBalBefore = await assetContract2.connect(walletSigner).balanceOf(await walletSigner.getAddress());
      let [, _vaultAfter, ] = await zapIn();

      await Vault.connect(walletSigner).approve(zapper_addr, _vaultAfter);
      await Zapper.connect(walletSigner).zapOutAndSwap(vault_addr, _vaultAfter, asset_addr2, 0);

      _vaultAfter = await Vault.connect(walletSigner).balanceOf(wallet_addr);
      const _balAfter = await assetContract2.connect(walletSigner).balanceOf(await walletSigner.getAddress()); 
      const _balDifference = (_balAfter/assetBalBefore).toPrecision(3);

      expect(_vaultAfter).to.be.equals(BigNumber.from("0x0"));
      expect(Number(_balDifference)).to.be.gt(0.98);
  
    });
     
})
