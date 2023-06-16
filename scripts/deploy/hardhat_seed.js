const hre = require("hardhat");
const { ethers } = require("hardhat");
// const { ethers, artifacts } from 'hardhat';
  
async function main() {
    await hre.run('compile');
  
    const VaultFactory = await ethers.getContractFactory("VaultSushiWethDpx");
    const vault = await VaultFactory.deploy(
      "0x5b1869D9A4C187F2EAa108f3062412ecf0526b24",
      "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1",
      "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1",
      "0xe78A0F7E598Cc8b0Bb87894B0F60dD2a88d6a8Ab"
    );
  
    await vault.deployed();
  
    console.log("token VaultSushiWethDpx to:", vault.address);
}
  
// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });