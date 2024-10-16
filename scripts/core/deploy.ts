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

const governance = "0xcb6123060C52aFA2EF3a5F70e3d1253078d84B2f";
const timelock = governance;

const stCore = "0xb3A8F0f0da9ffC65318aA39E55079796093029AD"


async function main() {
  const [deployer] = await ethers.getSigners();

  const coreController = await deploy({
    name: "CoreController",
    args: [governance, governance, governance, governance, governance],
    contractPath: "contracts/controllers/core-controller.sol:CoreController",
  });

//   const steerControllerFactory = await ethers.getContractFactory("SteerController");
//   const coreController = await steerControllerFactory.attach(controller);

  const StrategyCore = await deploy({
    name: "StrategyCore",
    args: [
        stCore,
        governance,
        governance,
        coreController.address,
        governance
    ],
    contractPath: "contracts/strategies/core/strategy-core.sol:StrategyCore",
  });

  const VaultCoreBase = await deploy({
    name: "VaultCoreBase",
    args: [stCore,governance, timelock, coreController.address],
    contractPath: "contracts/vaults/core/vault-core.sol:VaultCoreBase",
  });

  const CoreZapperBase = await deploy({
    name: "CoreZapperBase",
    args: [
      governance,
      [VaultCoreBase.address],
    ],
    contractPath: "contracts/vaults/core/core-zapper/core-zapper.sol:CoreZapperBase",
  });

  /** Setup Core contracts
   * =>> Set Vault on Controller
   * =>> Aprrove Strategy on controller
   * =>> Set Strategy on Controller
   **/

  await sleep(10);
  // Set Vault controller
  await coreController.connect(deployer).setVault(stCore, VaultCoreBase.address);
  await sleep(10);
  // Approve Strategy
  await coreController.connect(deployer).approveStrategy(stCore, StrategyCore.address);
  await sleep(10);
  // Set Strategy
  await coreController.connect(deployer).setStrategy(stCore, StrategyCore.address);

  console.log("DEPLOYED SUCCESS");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
