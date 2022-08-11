const hre = "hardhat";
const { ethers, network } = require("hardhat");
import { Signer, BigNumber } from "ethers";

export const reward_addr: string = "0xd4d42F0b6DEF4CE0383636770eF773390d85c61A";
export const treasury_addr: string = "0x0B11B4399DA7c88F5C7Cd42DE7F4290bBD150e80";
/***
 * NOTE: Single Staking expects the timelock signer to have the address of the strategist.
 */
 export async function setupSigners(timelockIsStrategist: boolean = false) {
    const governanceAddr: string = "0x0B11B4399DA7c88F5C7Cd42DE7F4290bBD150e80";
    const strategistAddr: string = "0x0B11B4399DA7c88F5C7Cd42DE7F4290bBD150e80";
    const timelockAddr: string = timelockIsStrategist ? "0x0B11B4399DA7c88F5C7Cd42DE7F4290bBD150e80" : "0x0B11B4399DA7c88F5C7Cd42DE7F4290bBD150e80";

    await network.provider.send('hardhat_impersonateAccount', [timelockAddr]);
    await network.provider.send('hardhat_impersonateAccount', [strategistAddr]);
    await network.provider.send('hardhat_impersonateAccount', [governanceAddr]);

    let timelockSigner: Signer = ethers.provider.getSigner(timelockAddr);
    let strategistSigner: Signer = ethers.provider.getSigner(strategistAddr);
    let governanceSigner: Signer = ethers.provider.getSigner(governanceAddr);

    let governance_addr = await governanceSigner.getAddress()
    let timelock_addr = await timelockSigner.getAddress()
    let strategist_addr = await strategistSigner.getAddress()

    let balance: string = "0x10000000000000000000000";
    await network.provider.send("hardhat_setBalance", [governance_addr, balance,]);
    await network.provider.send("hardhat_setBalance", [timelock_addr, balance,]);
    await network.provider.send("hardhat_setBalance", [strategist_addr, balance,]);

    return [timelockSigner, strategistSigner, governanceSigner];
};

