const hre = require("hardhat");
const { ethers, network } = require("hardhat");
import {
    Signer,
    Contract,
    BigNumber
} from "ethers";

const BLACKHOLE = "0x0000000000000000000000000000000000000000";


export async function returnSigner(address: string): Promise<Signer> {
    await network.provider.send('hardhat_impersonateAccount', [address]);
    return ethers.provider.getSigner(address)
}

export async function setStrategy(name: string, Controller: Contract,
    timelockSigner: Signer, asset_addr: string, strategy_addr: string) {
    const setStrategy = await Controller.connect(timelockSigner).setStrategy(asset_addr, strategy_addr);
    const tx_setStrategy = await setStrategy.wait(1);
    if (!tx_setStrategy.status) {
        console.error(`Error setting the strategy for: ${name}`);
        return;
    }
    console.log(`Set Strategy in the Controller for: ${name}`);
}

export async function whitelistHarvester(name: string, Strategy: Contract,
    governanceSigner: Signer, wallet_addr: string) {
    const whitelist = await Strategy.connect(governanceSigner).whitelistHarvester(wallet_addr);
    const tx_whitelist = await whitelist.wait(1);
    if (!tx_whitelist.status) {
        console.error(`Error whitelisting harvester for: ${name}`);
        return;
    }
    console.log(`Whitelisted the harvester for: ${name}`);
}

export async function setKeeper(name: string, Strategy: Contract,
    governanceSigner: Signer, wallet_addr: string) {
    const keeper = await Strategy.connect(governanceSigner).addKeeper(wallet_addr);
    const tx_keeper = await keeper.wait(1);
    if (!tx_keeper.status) {
        console.error(`Error adding keeper for: ${name}`);
        return;
    }
    console.log(`added keeper for: ${name}`);
}

export async function vaultEarn(name: string, Vault: Contract) {
    const earn = await Vault.earn();
    const tx_earn = await earn.wait(1);
    if (!tx_earn.status) {
        console.error(`Error calling earn in the Vault for: ${name}`);
        return;
    }
    console.log(`Called earn in the Vault for: ${name}`);
}

export async function strategyFold(name: string, fold: boolean, Strategy: Contract, governanceSigner: Signer) {
    if (!fold) { return; }

    // Now leverage to max
    const leverage = await Strategy.connect(governanceSigner).leverageToMax();
    const tx_leverage = await leverage.wait(1);
    if (!tx_leverage.status) {
        console.error(`Error leveraging the strategy for: ${name}`);
        return;
    }
    console.log(`Leveraged the strategy for: ${name}`);
}

// what is the gauge??? Does this require an extra deployment step? 
async function getGaugeProxy(governanceSigner: Signer, gauge_proxy_addr: string) {
    const gauge_proxy_ABI = (await ethers.getContractFactory("GaugeProxyV2")).interface;
    const GaugeProxy = new ethers.Contract(gauge_proxy_addr, gauge_proxy_ABI, governanceSigner);
    return GaugeProxy;
}

// Means of token distribution 
export async function addGauge(name: string, Vault: Contract, governanceSigner: Signer, gauge_proxy_addr = "0x215D5eDEb6A6a3f84AE9d72962FEaCCdF815BF27") {
    const GaugeProxy = await getGaugeProxy(governanceSigner, gauge_proxy_addr)
    const gauge_governance_addr = await GaugeProxy.governance();

    console.log(`gaugeProxy governance: ${gauge_governance_addr}`);
    const gaugeGovernanceSigner = await returnSigner(gauge_governance_addr);
    const gauge = await GaugeProxy.getGauge(Vault.address);
    if (gauge == BLACKHOLE) {
        await network.provider.send("hardhat_setBalance", [gauge_governance_addr, "0x10000000000000000000000",]);
        const addGauge = await GaugeProxy.connect(gaugeGovernanceSigner).addGauge(Vault.address);
        const tx_addGauge = await addGauge.wait(1);
        if (!tx_addGauge.status) {
            console.error(`Error adding the gauge for: ${name}`);
            return;
        }
        console.log(`addGauge for ${name}`);
    }
}


export async function overwriteTokenAmount(assetAddr: string, walletAddr: string, amount: string, slot: number = 0) {
    const index = ethers.utils.solidityKeccak256(["uint256", "uint256"], [walletAddr, slot]);
    const BN = ethers.BigNumber.from(amount)._hex.toString();
    const number = ethers.utils.hexZeroPad(BN, 32);

    await ethers.provider.send("hardhat_setStorageAt", [assetAddr, index, number]);
    await hre.network.provider.send("evm_mine");
}

export async function increaseBlock(block: number) {
    //console.log(`⌛ Advancing ${block} blocks`);
    for (let i = 1; i <= block; i++) {
        await hre.network.provider.send("evm_mine");
    }
}

export async function increaseTime(sec: number) {
    await hre.network.provider.send("evm_increaseTime", [sec]);
    await hre.network.provider.send("evm_mine");
}

export function returnController(controller: string): string {
    let address;
    switch (controller) {
        case "sushi": address = "0x1C233a46eAE1F928c0467a3C75228E26Ea9888d4"; break;
        case "dpx": address = "0x19390136f374A1Ef3CD15C97d8a430eDa26596cC"; break;
        case "gmx": address= "0x6cCc135D543f8fFD7D93174f8A11Ba4860695808"; break;
        case "dodo": address= "0xaC58Ff6C1f02779869beB4Db5dF9d25A6213ae95"; break;
        case "plutus": address = "0xAFC36887EE43EDDeB5773fedC877481ec97625a7"; break;
        case "jones": address = "0xF6e1d062DEfe3AEBF8674B930f621Adc36Ad870c"; break;
        case "stargate": address = "0x8B82E63D4494bE23a479201ADb75F7E43247E859"; break;
        case "fish": address="0xF36059454bE1e87E88506DdcF2aa65a1CEF8C1bF"; break; 
        case "hop": address="0x8121Fa4e27051DC3b86E4e7d6Fb2a02d62fe6F68";break;
        default: address = ""; break;
    }
    return address;
}

export async function fastForwardAWeek() {
    //console.log(`⌛ Fast Forwarding 3600 blocks within a week`);
    let i = 0;
    do {
        await increaseTime(60 * 60 * 24);
        await increaseBlock(60 * 60);
        i++;
    } while (i < 8);
}

export async function getBalancesETH(walletSigner: Signer) {
    const user = Number(ethers.utils.formatEther(await walletSigner.getBalance()));

    return user; 
}