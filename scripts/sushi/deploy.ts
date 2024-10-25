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

const verify = async (
  contractAddress: string,
  args: (string | number)[] = [],
  name?: string,
  wait: number = 20,
  contractPath?: string
) => {
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
        contract: contractPath,
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

const deploy = async (params: { name: string; args: any[]; verificationWait?: number; contractPath?: string }) => {
  const contractFactory = await ethers.getContractFactory(params.name);
  const contract = await contractFactory.deploy(...params.args);
  await contract.deployed();
  console.log(`${params.name}: ${contract.address}`);

  if (hre.network.name === "localhost") return contract;

  console.log("Verifying...");
  await verify(contract.address, params.args, params.name, params.verificationWait, params.contractPath);

  return contract;
};

const governance = "0xCb410A689A03E06de0a6247b13C13D14237DecC8";
const timelock = governance;

const sushiVaults = [
  "0x3C0c76ceb491Cb0Bacb31F8e7dc6407A25FD87C0",
  "0x3F9012f9bF3172c26B1B7246B8bc62148842B013",
  "0xeb952db71c594299cEEe7c03C3AA26FE0fDBC8eb",
  "0xdf9d86bC4765a9C64e85323A9408dbee0115d22E",
  "0xb58004E106409B00b854aBBF8CCB8618673d9346",
  "0xf8bDcf1Cf4134b2864cdbE685A8128F90ED0E16e",
];

async function main() {
  const [deployer] = await ethers.getSigners();

  // const clipperController = await deploy({
  //   name: "ClipperController",
  //   args: [governance, governance, governance, governance, governance],
  //   contractPath: "contracts/controllers/clipper-controller.sol:ClipperController",
  // });

  // await verify(
  //   "0xa752C41Ca7De8B6852D9f6e17E224D166dCC456b",
  //   [clipperAddress, governance, governance, controller],
  //   "VaultClipperBase",
  //   0,
  //   "contracts/vaults/clipper/vault-clipper-base.sol:VaultClipperBase"
  // );

  // const clipperVault = await deploy({
  //   name: "VaultClipperBase",
  //   args: [clipperAddress, governance, governance, clipperController.address],
  //   contractPath: "contracts/vaults/clipper/vault-clipper-base.sol:VaultClipperBase",
  // });

  // const clipperStrategy = await deploy({
  //   name: "StrategyClipperBase",
  //   args: [want, governance, governance, controller, governance],
  //   contractPath: "contracts/strategies/clipper/strategy-clipper-base.sol:StrategyClipperBase",
  // });

  const sushiZapper = await deploy({
    name: "ZapperSushi",
    args: [sushiVaults],
    contractPath: "contracts/strategies/sushi/sushi-zapper/sushi-vault-zapper.sol:ZapperSushi",
  });
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

