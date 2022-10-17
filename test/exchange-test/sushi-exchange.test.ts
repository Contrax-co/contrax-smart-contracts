/* eslint-disable no-undef */
const { ethers, network } = require("hardhat");
const hre = require("hardhat");
import { expect } from "chai";
import {Contract, ContractFactory, Signer, BigNumber} from "ethers";
import { overwriteTokenAmount, returnSigner } from "../utils/helpers";

let stratABI = [{"inputs": [{"internalType": "address","name": "_logic","type": "address"},{"internalType": "address","name": "admin_","type": "address"},{"internalType": "bytes","name": "_data","type": "bytes"}],"stateMutability": "payable","type": "constructor"},{"anonymous": false,"inputs": [{"indexed": false,"internalType": "address","name": "previousAdmin","type": "address"},{"indexed": false,"internalType": "address","name": "newAdmin","type": "address"}],"name": "AdminChanged","type": "event"},{"anonymous": false,"inputs": [{"indexed": true,"internalType": "address","name": "implementation","type": "address"}],"name": "Upgraded","type": "event"},{"stateMutability": "payable","type": "fallback"},{"inputs": [],"name": "admin","outputs": [{"internalType": "address","name": "admin_","type": "address"}],"stateMutability": "nonpayable","type": "function"},{"inputs": [{"internalType": "address","name": "newAdmin","type": "address"}],"name": "changeAdmin","outputs": [],"stateMutability": "nonpayable","type": "function"},{"inputs": [],"name": "implementation","outputs": [{"internalType": "address","name": "implementation_","type": "address"}],"stateMutability": "nonpayable","type": "function"},{"inputs": [{"internalType": "address","name": "newImplementation","type": "address"}],"name": "upgradeTo","outputs": [],"stateMutability": "nonpayable","type": "function"},{"inputs": [{"internalType": "address","name": "newImplementation","type": "address"},{"internalType": "bytes","name": "data","type": "bytes"}],"name": "upgradeToAndCall","outputs": [],"stateMutability": "payable","type": "function"},{"stateMutability": "payable","type": "receive"}];

const wallet_addr = process.env.WALLET_ADDR === undefined ? '' : process.env['WALLET_ADDR'];
let walletSigner: Signer; 

let snapshotId: string;

let controller_addr = "0xd7bc9a6Ee68e125169E96024Ef983Fee76520569";

let initialWethBal: string;
let initialUsdcBal: string; 
let initialWethUsdcBal: string; 
let exchange_addr: string;

let wethContract: Contract;
let usdcContract: Contract;
let wethUsdcContract: Contract;

let Exchange: Contract; 


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

        // // load user wallet with initial amount
        // await hre.network.provider.send("hardhat_setBalance", [
        //     await walletSigner.getAddress(), 
        //     "0x10000000000000000000000",]
        // );
        
        const exchangeFactory = await ethers.getContractFactory('SushiExchange');
        Exchange = await exchangeFactory.connect(walletSigner).deploy(
            controller_addr
        );

        exchange_addr = Exchange.address;

        console.log(`Deployed SushiExchange at ${exchange_addr}`);

        wethUsdcContract = await ethers.getContractAt("ERC20", weth_usdc_lp, walletSigner);
        initialWethUsdcBal = await wethUsdcContract.connect(walletSigner).balanceOf(wallet_addr);
        await overwriteTokenAmount(weth_usdc_lp, wallet_addr, txnAmt, 1);


        wethUsdcContract = await ethers.getContractAt("ERC20", weth_usdc_lp, walletSigner);
        initialWethUsdcBal = await wethUsdcContract.connect(walletSigner).balanceOf(wallet_addr);
        await overwriteTokenAmount(weth_usdc_lp, wallet_addr, txnAmt, 1);

        // wethContract = await ethers.getContractAt("ERC20", weth_addr, walletSigner);
        // usdcContract = await ethers.getContractAt("ERC20", usdc_addr, walletSigner);

        // initialWethBal = await wethContract.connect(walletSigner).balanceOf(wallet_addr); 
        // initialUsdcBal = await usdcContract.connect(walletSigner).balanceOf(wallet_addr);

        // console.log(`the initial amount of weth is ${initialWethBal}`)
        // console.log(`the initial amount of usdc is ${initialUsdcBal}`)

        // await overwriteTokenAmount(weth_addr, wallet_addr, txnAmt, 2);
        // await overwriteTokenAmount(usdc_addr, wallet_addr, txnAmt, 2);

        // initialWethBal = await wethContract.connect(walletSigner).balanceOf(wallet_addr); 
        // initialUsdcBal = await usdcContract.connect(walletSigner).balanceOf(wallet_addr);

        // console.log(`the initial amount of weth is ${initialWethBal}`)
        // console.log(`the initial amount of usdc is ${initialUsdcBal}`)

        
    })

    it("user wallet contains an initial balance of wethUsdc tokens", async function() {
        let wethUsdcBal = await wethUsdcContract.connect(walletSigner).balanceOf(wallet_addr);
        const BN = ethers.BigNumber.from(txnAmt)._hex.toString();

        console.log(`\nthe balance of weth-usdc tokens in user wallet is ${wethUsdcBal}`);

        expect(wethUsdcBal.sub(initialWethUsdcBal)).to.be.equals(BN); 

    })

    it("swaps user from lp token to an erc20 token", async function() {
        let amt = await wethUsdcContract.connect(walletSigner).balanceOf(wallet_addr);
        await wethUsdcContract.connect(walletSigner).approve(exchange_addr, amt);

        await Exchange.swapPairForToken(weth_usdc_lp, weth_addr, amt.div(2)); 

        let finalAmt = await wethUsdcContract.connect(walletSigner).balanceOf(wallet_addr);

        console.log(`the final amt after transferring is ${amt}`);

    })

})


