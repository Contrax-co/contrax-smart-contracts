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

const controller = "0x0Af9B6e31eAcBF7dDDecB483C93bB4E4c8E6F58d";

const sushiV3FactoryArb = "0x1af415a1EbA07a4986a52B6f2e7dE7003D82231e";
const sushiV3FactoryBase = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4";
const baseV3FactoryBase = "0x38015D05f4fEC8AFe15D7cc0386a126574e8077B";
const uniV3FactoryArb = "0x1F98431c8aD98523631AE4a59f267346ea31F984";
const uniV3FactoryBase = "0x33128a8fC17869897dcE68Ed026d694621f6FDfD";
const uniV3FactoryPol = "0x1F98431c8aD98523631AE4a59f267346ea31F984";

const wethBase = "0x4200000000000000000000000000000000000006";

const wethArb = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
let usdcArb = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831";

let usdcPol = "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359";
let wPol = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";

const sushiV3RouterBase = "0xFB7eF66a7e61224DD6FcD0D7d9C3be5C8B049b9f";
const baseV3RouterBase = "0x1B8eea9315bE495187D873DA7773a874545D9D48";
const uniV3RouterArb = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
const sushiV2RouterArb = "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506";
const uniV3RouterBase = "0x2626664c2603336E57B271c5C0b26F421741e481";
const uniV3RouterPol = "0xE592427A0AEce92De3Edee1F18E0157C05861564";

const gammaVaultWpolWeth = "0x02203f2351E7aC6aB5051205172D3f772db7D814";

const gammaUniProxy = "0xA42d55074869491D60Ac05490376B74cF19B00e6";

async function main() {
  const [deployer] = await ethers.getSigners();

  const gammaController = await deploy({
    name: "GammaController",
    args: [governance, governance, governance, governance, governance],
    contractPath: "contracts/controllers/gamma-controller.sol:GammaController",
  });

  // const gammaControllerFactory = await ethers.getContractFactory("gammaController");
  // const gammaController = await gammaControllerFactory.attach(controller);

  const StrategyGamma = await deploy({
    name: "StrategyGamma",
    args: [gammaVaultWpolWeth, governance, governance, controller, governance],
    contractPath: "contracts/strategies/gamma/strategy/strategy-gamma.sol:StrategyGamma",
  });

  const VaultGammaWpolWeth = await deploy({
    name: "VaultGammaWpolWeth",
    args: [governance, timelock, controller],
    contractPath: "contracts/vaults/gamma/gamma-vault-polygon/vault-gamma-wpol-weth.sol:VaultGammaWpolWeth",
  });

  const GammaZapperBase = await deploy({
    name: "GammaZapperBase",
    args: [governance, wPol, uniV3RouterPol, uniV3FactoryPol, gammaUniProxy, [VaultGammaWpolWeth.address]],
    contractPath: "contracts/vaults/gamma/gamma-zapper/gamma-zapper.sol:GammaZapperBase",
  });

  /** Setup Steer contracts
   * =>> Set Reward Token on Strategy
   * =>> Set Vault on Controller
   * =>> Aprrove Strategy on controller
   * =>> Set Strategy on Controller
   **/

  // Set Reward Token
  //   await StrategyGamma.connect(deployer).setRewardToken(baseToken);
  await sleep(10);
  // Set Vault controller
  await gammaController.connect(deployer).setVault(gammaVaultWpolWeth, VaultGammaWpolWeth.address);
  await sleep(10);
  // Approve Strategy
  await gammaController.connect(deployer).approveStrategy(gammaVaultWpolWeth, StrategyGamma.address);
  await sleep(10);
  // Set Strategy
  await gammaController.connect(deployer).setStrategy(gammaVaultWpolWeth, StrategyGamma.address);

  console.log("DEPLOYED SUCCESS");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
