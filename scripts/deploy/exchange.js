const { ethers } = require("hardhat");
require("@nomiclabs/hardhat-waffle");
require('dotenv').config();

async function main() {
  const platform = "Sushi";
  const exchanger_name = platform+"Exchange";  

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const controller_addr = "0xd7bc9a6Ee68e125169E96024Ef983Fee76520569";

  const exchangeFactory = await ethers.getContractFactory(exchanger_name);

  const Exchange = await exchangeFactory.deploy(controller_addr);
  console.log(`deployed ${exchanger_name} at : ${Exchange.address}`);

}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1); 
    }); 