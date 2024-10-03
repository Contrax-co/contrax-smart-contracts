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

const controller = "0xf3E4BC9F10521205fd1724E238B3eC6461Cdb915";
const oldController = "0x8121Fa4e27051DC3b86E4e7d6Fb2a02d62fe6F68";

const weth = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
let newStrategyHopWeth = "0xABEb0f715e95Ab0CD10B93c5715e376Fc22ae702";
let newStrategyHopDai = "0x3D59D64d33b0147Afb83Ecd17aa3ddC846DcFAf6";

async function main() {
  const [deployer] = await ethers.getSigners();

  // const HopController = await deploy({
  //   name: "HopController",
  //   args: [governance, governance, governance, governance, governance],
  //   contractPath: "contracts/controllers/hop-controller.sol:HopController",
  // });

  // const steerControllerFactory = await ethers.getContractFactory("SteerController");
  // const steerController = await steerControllerFactory.attach(controller);

  const StrategyHopDai = await deploy({
    name: "StrategyHopDai",
    args: [governance, governance, oldController, governance],
    contractPath: "contracts/strategies/hop/strategy-hop-dai.sol:StrategyHopDai",
  });

  /** Settings for updation of Strategy and Controller
   * =>> Set New strategy on old controller (call approveStrategy, setStrategy function on old controller)
   * =>> Deploy new controller and set it on strategy (call setController function on strategy)
   * =>> Call approveStrategy, setStrategy function on new controller
   * =>> Set Vault on new controller
   * =>> Set Controller on old Vault
   */

  // // Set Reward Token
  // await StrategySteerWethcbBtc.connect(deployer).setRewardToken(baseToken);
  // await sleep(10);
  // // Set Vault controller
  // await steerController.connect(deployer).setVault(steerVaultAddressWethcbBtc, VaultSteerBaseWethcbBTC.address);
  // await sleep(10);
  // // Approve Strategy
  // await steerController.connect(deployer).approveStrategy(steerVaultAddressWethcbBtc, StrategySteerWethcbBtc.address);
  // await sleep(10);
  // // Set Strategy
  // await steerController.connect(deployer).setStrategy(steerVaultAddressWethcbBtc, StrategySteerWethcbBtc.address);

  console.log("DEPLOYED SUCCESS");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

