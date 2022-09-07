const { ethers } = require("hardhat");
require("@nomiclabs/hardhat-waffle");
require('dotenv').config();

async function main() {
    const platform = "Sushi";
    const zapper_name = "VaultZapEth"+platform;

    const [deployer] = await ethers.getSigners();
    console.log("Deploying zapper contracts with the account:", deployer.address);

    

    const zapperFactory = await ethers.getContractFactory(zapper_name);
    const Zapper = await zapperFactory.deploy(); 

    console.log(`deployed ${zapper_name} at : ${zapper.address}`);


    // const Controller = new ethers.Contract(controller_addr, controller_ABI, deployer);

    // const deploy = async(name) => {
    //     console.log(`deploy new contract for`);

    // }

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1); 
    }); 