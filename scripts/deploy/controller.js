const { ethers } = require("hardhat");
require("@nomiclabs/hardhat-waffle");
require('dotenv').config();

async function main() {
    const platform = "Sushi";
    const controller_name = platform+"Controller";

    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    const governance_addr = "0x0B11B4399DA7c88F5C7Cd42DE7F4290bBD150e80";
    const strategist_addr = "0x0B11B4399DA7c88F5C7Cd42DE7F4290bBD150e80";
    const timelock_addr = "0x0B11B4399DA7c88F5C7Cd42DE7F4290bBD150e80"; 
    const devfund_addr = "0x0B11B4399DA7c88F5C7Cd42DE7F4290bBD150e80";
    const treasury_addr = "0x0B11B4399DA7c88F5C7Cd42DE7F4290bBD150e80";

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

