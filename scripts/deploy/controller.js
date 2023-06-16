const { ethers } = require("hardhat");
require("@nomiclabs/hardhat-waffle");
require('dotenv').config();

async function main() {
    const platform = "Sushi";
    const controller_name = platform+"Controller";

    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    const governance_addr = "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1";
    const strategist_addr = "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1";
    const timelock_addr = "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"; 
    const devfund_addr = "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1";
    const treasury_addr = "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1";

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

