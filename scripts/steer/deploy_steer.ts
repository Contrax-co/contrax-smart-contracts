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

const WETH_USDC_POOL_BASE = "0xd0b53D9277642d899DF5C87A3966A349A798F224";
const WETH_USDC_POOL_ARB = "0xC6962004f452bE9203591991D15f6b388e09E8D0";

const governance = "0xcb6123060C52aFA2EF3a5F70e3d1253078d84B2f";
const timelock = governance;

const controller = "0x0Af9B6e31eAcBF7dDDecB483C93bB4E4c8E6F58d";

const v3SushiFactory = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";
const baseV3Factory = "0x38015D05f4fEC8AFe15D7cc0386a126574e8077B";

const wethBase = "0x4200000000000000000000000000000000000006";

const sushiV3Router = "0xFB7eF66a7e61224DD6FcD0D7d9C3be5C8B049b9f";
const baseV3Router = "0x1B8eea9315bE495187D873DA7773a874545D9D48";

const steerVaultAddressWethUsdbcPool = "0x571A582064a07E0FA1d62Cb1cE4d1B7fcf9095d3";
const steerVaultAddressWethSnsy = "0x3C88c76783a9f2975C6d58F2aa1437f1E8229335";
const steerVaultAddressWethcbBtc = "0xD5A49507197c243895972782C01700ca27090Ee1";

const steerPeripheryArb = "0x806c2240793b3738000fcb62C66BF462764B903F";
const steerPeripheryBase = "0x16BA7102271dC83Fff2f709691c2B601DAD7668e";

const baseToken = "0xd07379a755A8f11B57610154861D694b2A0f615a";


async function main() {
  const [deployer] = await ethers.getSigners();

  // const steerController = await deploy({
  //   name: "SteerController",
  //   args: [governance, governance, governance, governance, governance],
  //   contractPath: "contracts/controllers/steer-controller.sol:SteerController",
  // });

  const steerControllerFactory = await ethers.getContractFactory("SteerController");
  const steerController = await steerControllerFactory.attach(controller);

  const StrategySteerWethcbBtc = await deploy({
    name: "StrategySteerWethcbBtc",
    args: [
      governance,
      governance,
      controller,
      governance,
      wethBase,
      baseV3Factory,
      steerPeripheryBase,
      WETH_USDC_POOL_BASE,
    ],
    contractPath: "contracts/strategies/steer/steer-base/strategy-steer-weth-cbBtc.sol:StrategySteerWethcbBtc",
  });

  const VaultSteerBaseWethcbBTC = await deploy({
    name: "VaultSteerBaseWethcbBTC",
    args: [governance, timelock, controller],
    contractPath: "contracts/vaults/steer/steer-vault-base/vault-steer-weth-cbBTC.sol:VaultSteerBaseWethcbBTC",
  });

  const SteerZapperBase = await deploy({
    name: "SteerZapperBase",
    args: [
      governance,
      wethBase,
      baseV3Router,
      baseV3Factory,
      steerPeripheryBase,
      WETH_USDC_POOL_BASE,
      [VaultSteerBaseWethcbBTC.address, 
        "0x76512AB6a1DEDD45B75dee47841eB9feD2411789"
      ],
    ],
    contractPath: "contracts/vaults/steer/steer-zapper/steer-zapper.sol:SteerZapperBase",
  });

  /** Setup Steer contracts
   * =>> Set Reward Token on Strategy
   * =>> Set Vault on Controller
   * =>> Aprrove Strategy on controller
   * =>> Set Strategy on Controller
   **/

  // Set Reward Token
  await StrategySteerWethcbBtc.connect(deployer).setRewardToken(baseToken);
  await sleep(10);
  // Set Vault controller
  await steerController.connect(deployer).setVault(steerVaultAddressWethcbBtc, VaultSteerBaseWethcbBTC.address);
  await sleep(10);
  // Approve Strategy
  await steerController.connect(deployer).approveStrategy(steerVaultAddressWethcbBtc, StrategySteerWethcbBtc.address);
  await sleep(10);
  // Set Strategy
  await steerController.connect(deployer).setStrategy(steerVaultAddressWethcbBtc, StrategySteerWethcbBtc.address);

  console.log("DEPLOYED SUCCESS");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

