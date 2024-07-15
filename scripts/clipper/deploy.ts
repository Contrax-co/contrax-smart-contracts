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
const controller = "";
let clipperAddress = "0x769728b5298445BA2828c0f3F5384227fbF590C5";

async function main() {
  const [deployer] = await ethers.getSigners();

  const clipperController = await deploy({
    name: "ClipperController",
    args: [governance, governance, governance, governance, governance],
    contractPath: "contracts/controllers/clipper-controller.sol:ClipperController",
  });

  const clipperVault = await deploy({
    name: "VaultClipperBase",
    args: [clipperAddress, governance, governance, clipperController.address],
    contractPath: "contracts/vaults/vault-clipper-base.sol:VaultClipperBase",
  });

  const clipperStrategy = await deploy({
    name: "StrategyClipper",
    args: [clipperVault.address, governance, governance, clipperController.address, governance],
    contractPath: "contracts/strategies/clipper/strategy-clipper.sol:StrategyClipper",
  });

  const clipperZapper = await deploy({
    name: "ClipperZapperBase",
    args: [governance, [clipperVault.address]],
    contractPath: "contracts/vaults/clipper/clipper-zapper/clipper-zapper.sol:ClipperZapperBase",
  });
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
