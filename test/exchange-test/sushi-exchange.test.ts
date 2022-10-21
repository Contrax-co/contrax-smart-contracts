/* eslint-disable no-undef */
const { ethers, network } = require("hardhat");
const hre = require("hardhat");
import { expect } from "chai";
import {Contract, ContractFactory, Signer, BigNumber} from "ethers";
import { setupMockERC20 } from "../mocks/ERC20";
import { overwriteTokenAmount, returnSigner } from "../utils/helpers";

let stratABI = [{"inputs": [{"internalType": "address","name": "_logic","type": "address"},{"internalType": "address","name": "admin_","type": "address"},{"internalType": "bytes","name": "_data","type": "bytes"}],"stateMutability": "payable","type": "constructor"},{"anonymous": false,"inputs": [{"indexed": false,"internalType": "address","name": "previousAdmin","type": "address"},{"indexed": false,"internalType": "address","name": "newAdmin","type": "address"}],"name": "AdminChanged","type": "event"},{"anonymous": false,"inputs": [{"indexed": true,"internalType": "address","name": "implementation","type": "address"}],"name": "Upgraded","type": "event"},{"stateMutability": "payable","type": "fallback"},{"inputs": [],"name": "admin","outputs": [{"internalType": "address","name": "admin_","type": "address"}],"stateMutability": "nonpayable","type": "function"},{"inputs": [{"internalType": "address","name": "newAdmin","type": "address"}],"name": "changeAdmin","outputs": [],"stateMutability": "nonpayable","type": "function"},{"inputs": [],"name": "implementation","outputs": [{"internalType": "address","name": "implementation_","type": "address"}],"stateMutability": "nonpayable","type": "function"},{"inputs": [{"internalType": "address","name": "newImplementation","type": "address"}],"name": "upgradeTo","outputs": [],"stateMutability": "nonpayable","type": "function"},{"inputs": [{"internalType": "address","name": "newImplementation","type": "address"},{"internalType": "bytes","name": "data","type": "bytes"}],"name": "upgradeToAndCall","outputs": [],"stateMutability": "payable","type": "function"},{"stateMutability": "payable","type": "receive"}];

const wallet_addr = process.env.WALLET_ADDR === undefined ? '' : process.env['WALLET_ADDR'];
let walletSigner: Signer; 

let snapshotId: string;

let controller_addr = "0xd7bc9a6Ee68e125169E96024Ef983Fee76520569";

let wethContract: Contract;
let usdcContract: Contract;
let wethUsdcContract: Contract;

let Exchange: Contract; 
let exchange_addr: string;


let weth_addr = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
let usdc_addr = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8"; 
let weth_usdc_lp= "0x905dfCD5649217c42684f23958568e533C711Aa3";

let txnAmt: string = "25000000000000000000000";


describe( "Tests for Sushi Swap Exchange", async () => {
    // These reset the state after each test is executed 
    beforeEach(async () => {
        snapshotId = await ethers.provider.send('evm_snapshot');
    });
    afterEach(async () => {
        await ethers.provider.send('evm_revert', [snapshotId]);
    });

    before(async () => {

        // Impersonate the wallet signer and add credit
        await network.provider.send('hardhat_impersonateAccount', [wallet_addr]);
        console.log(`Impersonating account: ${wallet_addr}`);
        walletSigner = await returnSigner(wallet_addr);

        // load user wallet with initial amount
        await hre.network.provider.send("hardhat_setBalance", [
            await walletSigner.getAddress(), 
            "0x10000000000000000000000",]
        );
        
        const exchangeFactory = await ethers.getContractFactory('SushiExchange');
        Exchange = await exchangeFactory.connect(walletSigner).deploy(
            controller_addr
        );

        exchange_addr = Exchange.address;

        console.log(`Deployed SushiExchange at ${exchange_addr}`);

        wethContract = await ethers.getContractAt("ERC20", weth_addr, walletSigner);
        await overwriteTokenAmount(wethContract.address, wallet_addr, txnAmt, 51);

        usdcContract = await ethers.getContractAt("ERC20", usdc_addr, walletSigner);
        await overwriteTokenAmount(usdcContract.address, wallet_addr, txnAmt, 51);
        
        wethUsdcContract = await ethers.getContractAt("ERC20", weth_usdc_lp, walletSigner); 
        await overwriteTokenAmount(wethUsdcContract.address, wallet_addr, txnAmt, 1);
    })

    it("user wallet contains an initial balance of tokens", async function() {
        const BN = ethers.BigNumber.from(txnAmt)._hex.toString();

        let wethBal = await wethContract.connect(walletSigner).balanceOf(wallet_addr);
        let usdcBal = await usdcContract.connect(walletSigner).balanceOf(wallet_addr);

        expect(wethBal).to.be.equals(BN); 
        expect(usdcBal).to.be.equals(BN); 
    })

    it("swap from one token to another token", async function() {
        await wethContract.approve(exchange_addr, txnAmt);
        await Exchange.connect(walletSigner).swapFromTokenToToken(weth_addr, usdc_addr, txnAmt);
        
        let usdcBal = await usdcContract.connect(walletSigner).balanceOf(wallet_addr); 
        let wethBal = await wethContract.connect(walletSigner).balanceOf(wallet_addr);
        console.log(`\nThe usdc after swap is ${usdcBal}`);
        console.log(`The balance of weth in the user wallet is ${wethBal}`);

        const BN = ethers.BigNumber.from(txnAmt)._hex.toString();

        expect(usdcBal).to.be.gt(BN);
        expect(wethBal).to.be.equals('0x0');
    })

    it("should swap from token to lp token", async function() {
        await usdcContract.approve(exchange_addr, txnAmt); 
        await Exchange.connect(walletSigner).swapTokenForPair(usdc_addr, weth_usdc_lp, txnAmt); 

        let weth_usdc_bal = await wethUsdcContract.connect(walletSigner).balanceOf(wallet_addr);
        console.log(`\nthe bal of te lp token is ${weth_usdc_bal}`);

        const BN = ethers.BigNumber.from(txnAmt)._hex.toString();

        await wethContract.approve(exchange_addr, txnAmt); 
        await Exchange.connect(walletSigner).swapTokenForPair(weth_addr, weth_usdc_lp, txnAmt);

        let final_weth_usdc_bal = await wethUsdcContract.connect(walletSigner).balanceOf(wallet_addr);
        console.log(`the final bal of te lp token is ${final_weth_usdc_bal}`)


        expect(weth_usdc_bal).to.be.gt(BN);
        expect(final_weth_usdc_bal).to.be.gt(weth_usdc_bal);
    })

    it.only("should swap from lp pair to token", async function() {
        await wethUsdcContract.approve(exchange_addr, txnAmt);
        await Exchange.connect(walletSigner).swapPairForToken(weth_usdc_lp, usdc_addr, txnAmt);

        let usdc_bal = await usdcContract.connect(walletSigner).balanceOf(wallet_addr);
        console.log(`\nthe bal of te lp token is ${usdc_bal}`);

        const BN = ethers.BigNumber.from(txnAmt)._hex.toString();
        expect(usdc_bal).to.be.gt(BN);
    })

})


