import hre, { ethers } from "hardhat";

const sleep = async (s: number) => {
  for (let i = s; i > 0; i--) {
    process.stdout.write(`\r \\ ${i} waiting..`);
    await new Promise((resolve) => setTimeout(resolve, 250));
    process.stdout.write(`\r | ${i} waiting..`);
    await new Promise((resolve) => setTimeout(resolve, 250));
    process.stdout.write(`\r / ${i} waiting..`);
    await new Promise((resolve) => setTimeout(resolve, 250));
    process.stdout.write(`\r - ${i} waiting..`);
    await new Promise((resolve) => setTimeout(resolve, 250));
    if (i === 1) process.stdout.clearLine(0);
  }
};

const verify = async (contractAddress: string, args: (string | number)[] = [], name?: string, wait: number = 100) => {
  try {
    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
    });
    return true;
  } catch (e) {
    if (
      String(e).indexOf(`${contractAddress} has no bytecode`) !== -1 ||
      String(e).indexOf(`${contractAddress} does not have bytecode`) !== -1
    ) {
      console.log(`Verification failed, waiting ${wait} seconds for etherscan to pick the deployed contract`);
      await sleep(wait);
    }

    try {
      await hre.run("verify:verify", {
        address: contractAddress,
        constructorArguments: args,
      });
      return true;
    } catch (e) {
      if (String(e).indexOf("Already Verified") !== -1 || String(e).indexOf("Already verified") !== -1) {
        console.log(name ?? contractAddress, "is already verified!");
        return true;
      } else {
        console.log(e);
        return false;
      }
    }
  }
};

const deploy = async (name: string, args: any[] = [], verificationWait = 100) => {
  const contractFactory = await ethers.getContractFactory(name);
  const contract = await contractFactory.deploy(...args);
  await contract.deployed();
  console.log(`${name}: ${contract.address}`);

  if (hre.network.name === "localhost") return contract;

  console.log("Verifying...");
  await verify(contract.address, args, name);

  return contract;
};
const governance = "0xCb410A689A03E06de0a6247b13C13D14237DecC8";
const timelock = governance;
const vaultName = "VaultSteerSushiUsdcUsdce";

async function main() {
  const [deployer] = await ethers.getSigners();
  // const VaultSteerSushiWethUsdc = await deploy("VaultSteerSushiWethUsdc", [governance, timelock]);
  // const VaultSteerSushiUsdcUsdce = await deploy("VaultSteerSushiUsdcUsdce", [governance, timelock]);

  // const SteerZapperBase = await deploy("SteerZapperBase", [
  //   governance,
  //   ["0x20d2Bf806184790b0b9E4BfCedFD0D665a1DD5F0", VaultSteerSushiUsdcUsdce.address],
  // ]);

  // await hre.run("verify:verify", {
  //   address: "0x2eC47ee3323D40CbB254C6d139a05dBF30823048",
  //   constructorArguments: [governance, timelock],
  //   contract: "contracts/vaults/steer/vault-steer-usdc-usdc.e.sol:VaultSteerSushiUsdcUsdce",
  // });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
