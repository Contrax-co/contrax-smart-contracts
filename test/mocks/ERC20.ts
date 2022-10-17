const hre = require("hardhat")
const { ethers } = require("hardhat")
import {
    Contract,
    Signer
} from "ethers";
import { overwriteTokenAmount } from "../utils/helpers";

export async function setupMockERC20(
    token_name: string, token_symbol: string, walletSigner: Signer,
    wallet_addr: string, txnAmt: string
) {

    let ERC20: Contract; 
    const ercFactory = await ethers.getContractFactory('ERC20');

    ERC20 = await ercFactory.connect(walletSigner).deploy(
        token_name, 
        token_symbol, 
    );

    console.log(`Deployed first erc20 token at ${ERC20.address}`); 

    // load newly deplyed erc20 contract with balance
    overwriteTokenAmount(ERC20.address, wallet_addr, txnAmt, 0); 

    return ERC20; 
}