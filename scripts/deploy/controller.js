const { ethers } = require("hardhat");
require("@nomiclabs/hardhat-waffle");
require('dotenv').config();

async function main() {
    const platform = "GMX";
    const controller_name = platform+"Controller";

    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    const governance_addr = "0xCb410A689A03E06de0a6247b13C13D14237DecC8";
    const strategist_addr = "0xCb410A689A03E06de0a6247b13C13D14237DecC8";
    const timelock_addr = "0xCb410A689A03E06de0a6247b13C13D14237DecC8"; 
    const devfund_addr = "0xCb410A689A03E06de0a6247b13C13D14237DecC8";
    const treasury_addr = "0xCb410A689A03E06de0a6247b13C13D14237DecC8";

    const controllerFactory = await ethers.getContractFactory(controller_name);

    const Controller = await controllerFactory.deploy(governance_addr, strategist_addr, timelock_addr, devfund_addr, treasury_addr);
    console.log(`deployed ${controller_name} at : ${Controller.address}`);

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1); 
    }); 

