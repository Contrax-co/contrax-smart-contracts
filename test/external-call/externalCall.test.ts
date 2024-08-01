import { ethers, network } from "hardhat";
import { expect } from "chai";
import { Signer, Contract } from "ethers";
import { returnSigner } from "../utils/helpers";
import { setupSigners } from "../utils/static";

const walletAddress = process.env.WALLET_ADDR === undefined ? "" : process.env["WALLET_ADDR"];

let timelockIsStrategist = false;

let walletSigner: Signer;
let timelockSigner: Signer;
let callerContract: Contract;
let arbContract: Contract;
let stratContract: Contract;
let targetAddress: string;

let data =
  "0x5e7b5fbf0000000000000000000000003ef3d8ba38ebe18db133cec108f4d14ce00dd9ae000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000003c471ee95c0000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000000100000000000000000000000021b0e4b9b1c1738ecb2f99d66b8e1e903e44f0050000000000000000000000000000000000000000000000000000000000000001000000000000000000000000912ce59144191c1204e64559fe8253a0e49e65480000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000037b54cbbfb0a0b400000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001121fd6ed196334bfe2540e981e712ee3dff3a5a4aee16670f4483dc121f6f0e7e3a5b6b0aa407b12913b1c9b5b3c448f4a60606f26177af33cdca7749da9e77f49b1612dd0cac110484b25744dd81a58e10e4c3773934c1ba7cff60b9407415638d8db6e73a61c8a5ef09491358e3eef213317f2fd5fdf261ae1f23fb910750d59a2c8e20db9bfecbf598da720782794222f3b42a4ce445baaa76ed47472ef357a458cbbb813c0a15687e7e07405a7b41042bed30c7a3cb8dc0e410628bf99f5c62be9069c048d18cf809c041ea366292ac046dab13b7dc3f3de779a7ceea42535a4f23c5c9f9d19d4b6e3216bd4ecc9be5d08e35f2f34349714673c6beac18ffc918e9e1eca9c5743df76c549b1fe76a8344cfbdf3548b493abe5d758c6a4a67dd94093147b83e8d9942daaef8a55579b1365f632948717ab0d427ba7e5b808e7aecd73af5e143e78b60260e9eb083536f792481ef9dfe3905d60801508f60ea2a77011d0f942011527cf354508d50cbbdbd67e4da70b7abd2cab8a23477e1c5779070aba5eab6635b330263118298ce4754ed2db0dca3af773431776ff9dab138eeb1b8a9fd131576953ed1811a5786c8d3096152609db84598cb4f62b48a0ad346e22ddba1d9f1e4ba0524ec297e2bd69da2ba09fc617a417abd68f1eb256533fcb24efd8c464f586d5bb4f1480a23b8ba722d9080f460818e04493ce12334395842d529929aa1a3555e07a815748facd09d3a378e075fd0e01c1c3ec2347a00000000000000000000000000000000000000000000000000000000";

let arbAddress = "0x912CE59144191C1204E64559FE8253a0e49E6548";
let strategeyAdd = "0x21b0e4b9b1c1738ecb2f99d66b8e1e903e44f005";

describe("Test for External Call", async () => {
  console.log("In Test block account: ");

  before(async () => {
    await network.provider.send("hardhat_impersonateAccount", [walletAddress]);
    console.log(`Impersonating account: ${walletAddress}`);

    // Getting some eth
    await ethers.provider.send("hardhat_setBalance", [
      walletAddress,
      "0x1158e460913d00000", // 20 ETH
    ]);
    let ethBalance = await ethers.provider.getBalance(walletAddress);
    console.log(`User's balance of ether is ${ethBalance}`);

    walletSigner = await returnSigner(walletAddress);

    [timelockSigner] = await setupSigners(timelockIsStrategist);

    const callerFactory = await ethers.getContractFactory("CallerContract");

    callerContract = await callerFactory.connect(walletSigner).deploy();

    arbContract = await ethers.getContractAt("contracts/lib/erc20.sol:ERC20", arbAddress, walletSigner);

    stratContract = await ethers.getContractAt(
      "contracts/strategies/steer/strategy-steer-usdc-usdce.sol:StrategySteerUsdcUsdce",
      strategeyAdd,
      walletSigner
    );
  });

  it("Should call external contract", async function () {
    const balBefore = await arbContract.connect(walletSigner).balanceOf(strategeyAdd);
    console.log("balBefore: ", balBefore);
    const tx = await stratContract.connect(timelockSigner).execute(callerContract.address, data);
    const receipt = await tx.wait();
    expect(receipt.status).to.equal(1);

    const balAfter = await arbContract.connect(walletSigner).balanceOf(strategeyAdd);

    console.log("balAfter: ", balAfter);

    expect(balAfter).to.be.gt(balBefore);
  });
});
