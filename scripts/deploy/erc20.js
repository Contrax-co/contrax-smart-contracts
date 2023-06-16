const hre = require("hardhat");
const { ethers } = require("hardhat");
// const { ethers, artifacts } from 'hardhat';
  
async function main() {
    await hre.run('compile');
  
    const tokenFactory = await ethers.getContractFactory("ERC20");
    const token = await tokenFactory.deploy(
      "TestToken",
      "TT"
    );
  
    await token.deployed();
  
    console.log("token is deployed to:", token.address);
}
  
// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });