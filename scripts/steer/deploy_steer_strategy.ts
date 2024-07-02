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

  if (hre.network.name === "localhost" || hre.network.name === "hardhat") return contract;

  console.log("Verifying...");
  await verify(contract.address, params.args, params.name, params.verificationWait, params.contractPath);

  return contract;
};

const governance = "0xCb410A689A03E06de0a6247b13C13D14237DecC8";
const timelock = governance;
const controller = "0x0Af9B6e31eAcBF7dDDecB483C93bB4E4c8E6F58d";

const poolFees = [
  {
    poolFee: 100,
    token0: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
    token1: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
  }, // usdc-usdce
  {
    poolFee: 500,
    token0: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
    token1: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
  }, // usdc-weth
  {
    poolFee: 100,
    token0: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
    token1: "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9",
  }, // usdc-usdt
  {
    poolFee: 500,
    token0: "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9",
    token1: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
  }, // usdt-weth
  {
    poolFee: 500,
    token0: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
    token1: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
  }, // usdce-weth
];

async function main() {
  const [deployer] = await ethers.getSigners();

  // const VaultSteerSushiUsdtUsdc = await deploy({
  //   name: "VaultSteerSushiUsdtUsdc",
  //   args: [governance, timelock, controller],
  //   contractPath: "contracts/vaults/steer/vault-steer-usdt-usdc.sol:VaultSteerSushiUsdtUsdc",
  // });

  // const VaultSteerSushiWethSushi = await deploy({
  //   name: "VaultSteerSushiWethSushi",
  //   args: [governance, timelock, controller],
  //   contractPath: "contracts/vaults/steer/vault-steer-weth-sushi.sol:VaultSteerSushiWethSushi",
  // });

  // const VaultSteerSushiWethUsdc = await deploy({
  //   name: "VaultSteerSushiWethUsdc",
  //   args: [governance, timelock, controller],
  //   contractPath: "contracts/vaults/steer/vault-steer-weth-usdc.sol:VaultSteerSushiWethUsdc",
  // });

  // deploy strategy
  // const StrategySteerUsdcUsdce = await deploy({
  //   name: "StrategySteerUsdcUsdce",
  //   args: [governance, governance, controller, governance],
  //   contractPath: "contracts/strategies/steer/strategy-steer-usdc-usdce.sol:StrategySteerUsdcUsdce",
  // });

  // const StrategySteerUsdcUsdt = await deploy({
  //   name: "StrategySteerUsdcUsdt",
  //   args: [governance, governance, controller, governance],
  //   contractPath: "contracts/strategies/steer/strategy-steer-usdc-usdt.sol:StrategySteerUsdcUsdt",
  // });

  await verify(
    "0xc3138161693981075Bb5911551906114CD1ea52b",
    [governance, governance, controller, governance],
    "StrategySteerUsdcUsdce",
    0,
    "contracts/strategies/steer/strategy-steer-usdc-usdce.sol:StrategySteerUsdcUsdce"
  );

  // await verify(
  //   "0x297006F9E1A6d0e7EEf3514aC10d5684D7b9A454",
  //   [governance, governance, controller, governance],
  //   "StrategySteerUsdcUsdt",
  //   0,
  //   "contracts/strategies/steer/strategy-steer-usdc-usdt.sol:StrategySteerUsdcUsdt"
  // );

  // const StrategySteerWethSushi = await deploy({
  //   name: "StrategySteerWethSushi",
  //   args: [governance, governance, controller, governance],
  //   contractPath: "contracts/strategies/steer/strategy-steer-weth-sushi.sol:StrategySteerWethSushi",
  // });

  // const StrategySteerUsdcWeth = await deploy({
  //   name: "StrategySteerUsdcWeth",
  //   args: [governance, governance, controller, governance],
  //   contractPath: "contracts/strategies/steer/strategy-steer-weth-usdc.sol:StrategySteerUsdcWeth",
  // });

  // const SteerZapperBase = await deploy({
  //   name: "SteerZapperBase",
  //   args: [
  //     governance,
  //     ["0x76512AB6a1DEDD45B75dee47841eB9feD2411789", VaultSteerSushiUsdtUsdc.address, VaultSteerSushiWethUsdc.address],
  //     poolFees.map((e) => e.token0),
  //     poolFees.map((e) => e.token1),
  //     poolFees.map((e) => e.poolFee),
  //   ],
  //   contractPath: "contracts/vaults/steer/steer-zapper/steer-zapper.sol:SteerZapperBase",
  // });

  // const SteerSushiZapperBase = await deploy({
  //   name: "SteerSushiZapperBase",
  //   args: [governance, [VaultSteerSushiWethSushi.address]],
  //   contractPath: "contracts/vaults/steer/steer-zapper/steer-sushi-zapper.sol:SteerSushiZapperBase",
  // });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
