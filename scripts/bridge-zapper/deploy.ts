import hre, { ethers } from "hardhat";

const WETH_USDC_POOL_ARB = "0xC6962004f452bE9203591991D15f6b388e09E8D0";

let wethArb = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
let usdcArb = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831";

const wethBase = "0x4200000000000000000000000000000000000006";
const usdcBase = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";

let wCore = "0x40375C92d9FAf44d2f9db9Bd9ba41a3317a2404f";
let usdcCore = "0xa4151B2B3e269645181dCcF2D426cE75fcbDeca9";

const uniV3RouterArb = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
const sushiV3RouterBase = "0xFB7eF66a7e61224DD6FcD0D7d9C3be5C8B049b9f";
const coreXV3RouterCore = "0xcc85A7870902f5e3dCef57E4d44F42b613c87a2E";

const uniV3FactoryArb = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
const sushiV3FactoryBase = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";
const coreXFactoryCore = "0x526190295AFB6b8736B14E4b42744FBd95203A3a";

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

async function main() {
  const [deployer] = await ethers.getSigners();

  const zapper = await deploy({
    name: "ZapperBridge",
    args: [deployer.address, wethArb, usdcArb, uniV3RouterArb, uniV3FactoryArb],
    contractPath: "contracts/Utils/zapperForBridge.sol:ZapperBridge",
  });

  await sleep(10);

  await zapper.connect(deployer).approveToken(usdcArb, "0xA45B5130f36CDcA45667738e2a258AB09f4A5f7F");

  await zapper.connect(deployer).approveToken(usdcArb, "0xe8CDF27AcD73a434D661C84887215F7598e7d0d3");

  await zapper.connect(deployer).approveToken(usdcArb, "0x29d096cD18C0dA7500295f082da73316d704031A");

  console.log("done");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

