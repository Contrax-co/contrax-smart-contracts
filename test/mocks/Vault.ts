const hre = require("hardhat")
const { ethers } = require("hardhat")
import {
    Contract,
    Signer
} from "ethers";

const BLACKHOLE = "0x0000000000000000000000000000000000000000"

export async function setupMockVault(
    contract_name: string, vault_addr: string, asset_addr: string,
    Controller: Contract, timelockSigner: Signer,
    governanceSigner: Signer) {

    let vaultABI = (await ethers.getContractFactory(contract_name)).interface;
    let Vault: Contract

    if (vault_addr == "") {
        let vault_function = await Controller.functions['vaults'] ? 'vaults' : 'globes'; 
        vault_addr = await Controller.functions[vault_function](asset_addr); 

        console.log(`controller_addr: ${Controller.address}`);
        console.log(`vault_addr: ${vault_addr}`);

        if (vault_addr != BLACKHOLE) {
            Vault = new ethers.Contract(vault_addr, vaultABI, governanceSigner);
            console.log(`connected to vault at ${Vault.address}`);

        } else {
            const vaultFactory = await ethers.getContractFactory(contract_name);
            const governance_addr = await governanceSigner.getAddress()
            const controller_addr = Controller.address
            const timelock_addr = await timelockSigner.getAddress()
            Vault = await vaultFactory.deploy(
                asset_addr,
                governance_addr,
                timelock_addr,
                controller_addr
            );
            console.log(`deployed new vault at ${Vault.address}`);
            const setVault = await Controller.setVault(asset_addr, Vault.address);
            const tx_setVault = await setVault.wait(1);
            if (!tx_setVault.status) {
                console.error(`Error setting the vault for: ${contract_name}`);
                return Vault;
            }
            console.log(`Set Vault in the Controller for: ${contract_name}`);
            vault_addr = Vault.address;
        }
    } else {
        Vault = new ethers.Contract(vault_addr, vaultABI, governanceSigner);
        console.log(`Connected to vault at ${Vault.address}`);
    }

    return Vault;
}