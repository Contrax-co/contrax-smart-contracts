const { ethers } = require("hardhat");
require("@nomiclabs/hardhat-waffle");
require('dotenv').config();

async function main() {
    const platform = "Stargate";
    const zapper_name = platform+"VaultZapper";

    const [deployer] = await ethers.getSigners();
    console.log("Deploying zapper contracts with the account:", deployer.address);

    const stargate_router = "0x53Bf833A5d6c4ddA888F69c22C88C9f356a41614";


    const zapperFactory = await ethers.getContractFactory(zapper_name);
    const Zapper = await zapperFactory.deploy(stargate_router); 

    console.log(`deployed ${zapper_name} at : ${Zapper.address}`);


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