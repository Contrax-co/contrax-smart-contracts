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
let name = "SushiWethUsdc";
let vault_addr = "0x46910A4AbA500b71F213150A0E99201Fd5c8FCec";
// let strategy_addr = test_case.strategyAddress;
// let slot = test_case.slot;
let timelockIsStrategist = false;

let snapshotId: string;

let controller_addr= "0x6cCc135D543f8fFD7D93174f8A11Ba4860695808";

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


let asset_addr = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
let asset_addr2 = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8";
let asset_addr3 = "0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f";
let want_addr = "0x515e252b2b5c22b4b2b6Df66c2eBeeA871AA4d69"; 

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

        const zapperFactory = await ethers.getContractFactory('VaultZapperSushi');
        Zapper = await zapperFactory.connect(walletSigner).deploy();

        Vault = await ethers.getContractAt(vaultName, vault_addr, walletSigner);

  
        zapper_addr = Zapper.address;
        console.log(`Deployed Zapper at ${zapper_addr}`);

        // assetContract = await ethers.getContractAt("ERC20", asset_addr, walletSigner);
        // await overwriteTokenAmount(asset_addr, wallet_addr, txnAmt, 2);

        assetContract2 = await ethers.getContractAt("ERC20", asset_addr2, walletSigner);
        await overwriteTokenAmount(asset_addr2, wallet_addr, txnAmt, 51);


        wantContract = await ethers.getContractAt("ERC20", want_addr, walletSigner);
      
    });

    const zapInETH = async () => {
      let _vaultBefore = await Vault.connect(walletSigner).balanceOf(await walletSigner.getAddress()); 
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

    it("user wallet contains asset balance", async function () {
      //let BNBal = await assetContract.balanceOf(await walletSigner.getAddress());
      let BNBal2 = await assetContract2.balanceOf(await walletSigner.getAddress());

      const BN = ethers.BigNumber.from(txnAmt)._hex.toString();

      expect(BNBal2).to.be.equals(BN);
      //expect(BNBal2).to.be.equals(BNBal).to.be.equals(BN);
    });

    it("Should deposit from the zapper to the vault", async function() {
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
