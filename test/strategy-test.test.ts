/* eslint-disable no-undef */
const { ethers, network } = require("hardhat");
const hre = "hardhat";
import { expect } from "chai";
import { setupMockStrategy } from "./mocks/Strategy";
import { setupMockVault } from "./mocks/Vault"; 
import {Contract, ContractFactory, Signer, BigNumber} from "ethers";
import {
    setupSigners,
    reward_addr,
    treasury_addr
} from "./utils/static";
import {
    overwriteTokenAmount, increaseBlock,
    returnSigner, returnController, fastForwardAWeek,
    setStrategy, whitelistHarvester, setKeeper,
    vaultEarn, strategyFold, addGauge
} from "./utils/helpers";


import { TestableStrategy } from "./strategy-test-case";

export function doStrategyTest(test_case: TestableStrategy) {

    const wallet_addr = process.env.WALLET_ADDR === undefined ? '' : process.env['WALLET_ADDR'];
    let name = test_case.name;
    let vault_addr = test_case.vaultAddress;
    let strategy_addr = test_case.strategyAddress;
    let fold = test_case.fold;
    let slot = test_case.slot;
    let controller = test_case.controller;
    let timelockIsStrategist = test_case.timelockIsStrategist;

    let assetContract: Contract;
    let Controller: Contract;
    let Vault: Contract;
    let Strategy: Contract;

    let governanceSigner: Signer;
    let strategistSigner: Signer;
    let walletSigner: Signer;
    let controllerSigner: Signer;
    let timelockSigner: Signer;

    let strategyBalance: string;
    let controller_addr: string;
    let asset_addr: string;
    let governance_addr: string;
    let strategist_addr: string;
    let timelock_addr: string;
    let snapshotId: string;

    let txnAmt: string = "250000000000000000000";
   
    describe( "Tests for: " + name, async () => {
        
        // These reset the state after each test is executed 
        beforeEach(async () => {
            snapshotId = await ethers.provider.send('evm_snapshot');
        });
        afterEach(async () => {
            await ethers.provider.send('evm_revert', [snapshotId]);
        });


        before(async () => {
            // names of the strategy and vault
            const strategyName = `Strategy${name}`;
            const vaultName = `Vault${name}`;

            // Impersonate the wallet signer and add credit
            await network.provider.send('hardhat_impersonateAccount', [wallet_addr]);
            console.log(`Impersonating account: ${wallet_addr}`);
            walletSigner = await returnSigner(wallet_addr);
            [timelockSigner, strategistSigner, governanceSigner] = await setupSigners(timelockIsStrategist);  
            
            // Add a new case here when including a new family of folding strategies
            controller_addr = returnController(controller);
            Controller = await ethers.getContractAt("Controller", controller_addr, governanceSigner);
            console.log(`Using controller: ${controller_addr}\n`);

            timelock_addr = await timelockSigner.getAddress();
            governance_addr = await governanceSigner.getAddress();
            strategist_addr = await strategistSigner.getAddress(); 

            // const controllerFactory = await ethers.getContractFactory("Controller", timelockSigner);
            // Controller = await controllerFactory.deploy(governance_addr, strategist_addr, timelock_addr, timelock_addr, timelock_addr);

            /** Strategy Mock **/
            Strategy = await setupMockStrategy(
                strategyName,
                strategy_addr,
                fold,
                Controller,
                walletSigner,
                timelockSigner,
                governanceSigner,
                strategistSigner
            );

            asset_addr = await Strategy.want();
            assetContract = await ethers.getContractAt("ERC20", asset_addr, walletSigner);
            // ensure timelocker is same as used in Strategy
            timelock_addr = await Strategy.timelock();
            timelockSigner = await returnSigner(timelock_addr);

            /** Vault Mock **/
            Vault = await setupMockVault(
                vaultName,
                vault_addr,
                asset_addr,
                Controller,
                timelockSigner,
                governanceSigner
            );

            // ensure addresses
            strategy_addr = Strategy.address;
            vault_addr = Vault.address;

            /** Access **/
            await setStrategy(name, Controller, timelockSigner, asset_addr, strategy_addr);
            await whitelistHarvester(name, Strategy, governanceSigner, wallet_addr);
            if (test_case.type == "FOLD") {
                await setKeeper(name, Strategy, governanceSigner, wallet_addr);
            }

            /** EARN **/
            await vaultEarn(name, Vault);
            await strategyFold(name, fold, Strategy, governanceSigner);

            /* Gauges */
            //await addGauge(name, Vault, governanceSigner)

            await overwriteTokenAmount(asset_addr, wallet_addr, txnAmt, slot);
        });

        const harvester = async () => {
            await overwriteTokenAmount(asset_addr, wallet_addr, txnAmt, slot);
            let amt = await assetContract.connect(walletSigner).balanceOf(wallet_addr);

            let balBefore = await assetContract.connect(walletSigner).balanceOf(vault_addr);

            await assetContract.connect(walletSigner).approve(vault_addr, amt);
            await Vault.connect(walletSigner).depositAll();
            
            let userBal = await assetContract.connect(walletSigner).balanceOf(wallet_addr);
            expect(userBal).to.be.equals(BigNumber.from("0x0"));

            let balAfter = await assetContract.connect(walletSigner).balanceOf(vault_addr);
            expect(balBefore).to.be.lt(balAfter);
            
            await Vault.connect(walletSigner).earn();

            await fastForwardAWeek();

            let harvestable_function = Strategy.functions['getHarvestable']? 'getHarvestable' : 'getWavaxAccrued';
            let harvestable = await Strategy.functions[harvestable_function]();
            console.log(`\tHarvestable, pre harvest: ${harvestable.toString()}`);
    
            let initialBalance = await Strategy.balanceOf();
            // let cost = (await Strategy.estimateGas.harvest()).toNumber();
            // console.log("cost %d", cost);
            await Strategy.connect(walletSigner).harvest();
            await increaseBlock(2);

            harvestable = await Strategy.functions[harvestable_function]();
            console.log(`\tHarvestable, post harvest: ${harvestable.toString()}`);

            return [amt, initialBalance]; 
        };

        it("user wallet contains asset balance", async function() {
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

        it("Controller vault to be configured correctly", async function() {
          expect(await Controller.vaults(asset_addr)).to.contains(vault_addr);
        });

        if (test_case.type != "FOLD") {
            it("Controller strategy to be configured correctly", async () => {
              expect(await Controller.strategies(asset_addr)).to.be.equals(strategy_addr);
            });

            it("should be able to change keep amount for fees", async function() {
              await Strategy.connect(timelockSigner).setKeep(10);
              let keep = await Strategy.keep();
              expect(keep).to.be.equals(10);
            });

            it("should be be able change fee distributor", async function () {
              await Strategy.connect(governanceSigner).setFeeDistributor(wallet_addr);
              const feeDistributor = await Strategy.feeDistributor();
              expect(feeDistributor).to.be.equals(wallet_addr);
            })
        }

        it("Should be able to deposit/withdraw money into vault", async function() {
          let txnAmt = "2500000000000000000000000000";
          let vault_addr = Vault.address;
          let wallet_addr = await walletSigner.getAddress();
          await assetContract.approve(vault_addr, txnAmt);
          let balBefore = await assetContract.connect(walletSigner).balanceOf(vault_addr);
          await Vault.connect(walletSigner).depositAll();

          let userBal = await assetContract.connect(walletSigner).balanceOf(wallet_addr);
          expect(userBal).to.be.equals(BigNumber.from("0x0"));

          let balAfter = await assetContract.connect(walletSigner).balanceOf(vault_addr);
          expect(balBefore).to.be.lt(balAfter);

          await Vault.connect(walletSigner).withdrawAll();

          userBal = await assetContract.connect(walletSigner).balanceOf(wallet_addr);
          console.log(`the user bal is ${userBal}`);
          expect(userBal).to.be.gt(BigNumber.from("0x0"));
        });

        it.only("Harvests should make some money!", async function() {
          let initialBalance;
          [, initialBalance] = await harvester();

          let newBalance = await Strategy.balanceOf();
          console.log(`initial balance: ${initialBalance}`);
          console.log(`new balance: ${newBalance}`);
          expect(newBalance).to.be.gt(initialBalance);
        });

        it("Strategy loaded with initial balance", async function() {
          let vault_addr = Vault.address;
          await assetContract.approve(vault_addr, txnAmt);
          await Vault.connect(walletSigner).depositAll();

          await Vault.connect(walletSigner).earn();

          let strategyBalance = await Strategy.balanceOf();
          expect(strategyBalance).to.not.be.equals(BigNumber.from("0x0"));
        });

        it("Users should earn some money!", async function() {
          let asset_addr = assetContract.address
          let vault_addr = Vault.address
          let wallet_addr = await walletSigner.getAddress()
      
          await overwriteTokenAmount(asset_addr, wallet_addr, txnAmt, slot);
          let amt = await assetContract.connect(walletSigner).balanceOf(wallet_addr);
      
          await assetContract.connect(walletSigner).approve(vault_addr, amt);
          await Vault.connect(walletSigner).deposit(amt);
          await Vault.connect(walletSigner).earn();

          await fastForwardAWeek();
          
          await Strategy.connect(walletSigner).harvest();
          await increaseBlock(1);

          fastForwardAWeek(); 
          
          await Vault.connect(walletSigner).withdrawAll();
          
          let newAmt = await assetContract.connect(walletSigner).balanceOf(wallet_addr);
      
          expect(amt).to.be.lt(newAmt);
        });

        it("should take no commission when fees not set", async function() {

          let asset_addr = assetContract.address
          let vault_addr = Vault.address
          let wallet_addr = await walletSigner.getAddress()

          await overwriteTokenAmount(asset_addr, wallet_addr, txnAmt, slot);
          let amt = await assetContract.connect(walletSigner).balanceOf(wallet_addr);

          await assetContract.connect(walletSigner).approve(vault_addr, amt);
          await Vault.connect(walletSigner).deposit(amt);
          await Vault.connect(walletSigner).earn();

          await fastForwardAWeek();

          // Set PerformanceTreasuryFee
          await Strategy.connect(timelockSigner).setPerformanceTreasuryFee(0);

          // Set KeepPNG
          await Strategy.connect(timelockSigner).setKeep(0);
          let rewardContract = await ethers.getContractAt("ERC20", reward_addr, walletSigner);

          const vaultBefore = await Vault.balance();
          const treasuryBefore = await assetContract.connect(walletSigner).balanceOf(treasury_addr);
          const rewardBefore = await rewardContract.balanceOf(treasury_addr);

          await Strategy.connect(walletSigner).harvest();
          await increaseBlock(1);

          const vaultAfter = await Vault.balance();
          const treasuryAfter = await assetContract.connect(walletSigner).balanceOf(treasury_addr);
          const rewardAfter = await rewardContract.balanceOf(treasury_addr);

          const earnt = vaultAfter.sub(vaultBefore);
          const earntTreasury = treasuryAfter.sub(treasuryBefore);
          const rewardAccrued = rewardAfter.sub(rewardBefore);
          console.log(`\t💸Vault profit after harvest: ${earnt.toString()}`);
          console.log(`\t💸Treasury profit after harvest:  ${earntTreasury.toString()}`);
          console.log(`\t💸Reward token accrued : ${rewardAccrued}`);
          expect(rewardAccrued).to.be.lt(1);
          expect(earntTreasury).to.be.lt(1);
        });

        it("should take some commission when fees are set", async function() {
          let vault_addr = Vault.address

          // Set PerformanceTreasuryFee
          await Strategy.connect(timelockSigner).setPerformanceTreasuryFee(0);

          await Strategy.connect(timelockSigner).setKeep(1000);

          let rewardContract = await ethers.getContractAt("ERC20", reward_addr, walletSigner);

          const vaultBefore = await Vault.balance();
          const treasuryBefore = await assetContract.connect(walletSigner).balanceOf(treasury_addr);
          const rewardBefore = await rewardContract.balanceOf(treasury_addr);
          console.log(`rewardBefore: ${rewardBefore.toString()}`);
          console.log(`vaultBefore: ${vaultBefore.toString()}`);

          let initialBalance;
          [, initialBalance] = await harvester();

          let newBalance = await Strategy.balanceOf();
          console.log(`initial balance: ${initialBalance}`);
          console.log(`new balance: ${newBalance}`);

          const vaultAfter = await Vault.balance();
          const treasuryAfter = await assetContract.connect(walletSigner).balanceOf(treasury_addr);
          const rewardAfter = await rewardContract.balanceOf(treasury_addr);
          console.log(`rewardAfter: ${rewardAfter.toString()}`);
          console.log(`vaultAfter: ${vaultAfter.toString()}`);
          const earnt = vaultAfter.sub(vaultBefore);
          const earntTreasury = treasuryAfter.sub(treasuryBefore);
          const rewardAccrued = rewardAfter.sub(rewardBefore);
          console.log(`\t💸Vault profit after harvest: ${earnt.toString()}`);
          console.log(`\t💸Treasury profit after harvest:  ${earntTreasury.toString()}`);
          console.log(`\t💸Reward token accrued : ${rewardAccrued}`);
          expect(rewardAccrued).to.be.gt(1);
        });

    });

};