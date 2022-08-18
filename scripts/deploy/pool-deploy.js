const hre = require("hardhat");
const { readFileSync, writeFileSync } = require("fs");
const { ethers } = require("hardhat");
require('dotenv').config();

async function main() {
    const verify = false;
    const poolsJSON = readFileSync("./scripts/deploy/deploy.json");//loded from files
    const pools = JSON.parse(poolsJSON);

    const [deployer] = await ethers.getSigners();
    console.log("Deploying/Repairing pools with the account:", deployer.address);

    const controller_ABI = [{"inputs":[{"internalType":"address","name":"_governance","type":"address"},{"internalType":"address","name":"_strategist","type":"address"},{"internalType":"address","name":"_timelock","type":"address"},{"internalType":"address","name":"_devfund","type":"address"},{"internalType":"address","name":"_treasury","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"inputs":[{"internalType":"address","name":"_token","type":"address"},{"internalType":"address","name":"_strategy","type":"address"}],"name":"approveStrategy","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_converter","type":"address"}],"name":"approveVaultConverter","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"address","name":"","type":"address"}],"name":"approvedStrategies","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"approvedVaultConverters","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_token","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"burn","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"convenienceFee","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"convenienceFeeMax","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"address","name":"","type":"address"}],"name":"converters","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"devfund","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_token","type":"address"},{"internalType":"uint256","name":"_amount","type":"uint256"}],"name":"earn","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_strategy","type":"address"},{"internalType":"address","name":"_token","type":"address"},{"internalType":"uint256","name":"parts","type":"uint256"}],"name":"getExpectedReturn","outputs":[{"internalType":"uint256","name":"expected","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"governance","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_strategy","type":"address"},{"internalType":"address","name":"_token","type":"address"}],"name":"inCaseStrategyTokenGetStuck","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_token","type":"address"},{"internalType":"uint256","name":"_amount","type":"uint256"}],"name":"inCaseTokensGetStuck","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"max","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"onesplit","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_token","type":"address"},{"internalType":"address","name":"_strategy","type":"address"}],"name":"revokeStrategy","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_converter","type":"address"}],"name":"revokeVaultConverter","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_convenienceFee","type":"uint256"}],"name":"setConvenienceFee","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_devfund","type":"address"}],"name":"setDevFund","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_governance","type":"address"}],"name":"setGovernance","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_onesplit","type":"address"}],"name":"setOneSplit","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_split","type":"uint256"}],"name":"setSplit","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_strategist","type":"address"}],"name":"setStrategist","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_token","type":"address"},{"internalType":"address","name":"_strategy","type":"address"}],"name":"setStrategy","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_timelock","type":"address"}],"name":"setTimelock","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_treasury","type":"address"}],"name":"setTreasury","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_token","type":"address"},{"internalType":"address","name":"_vault","type":"address"}],"name":"setVault","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"split","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"strategies","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"strategist","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_fromVault","type":"address"},{"internalType":"address","name":"_toVault","type":"address"},{"internalType":"uint256","name":"_fromVaultAmount","type":"uint256"},{"internalType":"uint256","name":"_toVaultMinAmount","type":"uint256"},{"internalType":"address payable[]","name":"_targets","type":"address[]"},{"internalType":"bytes[]","name":"_data","type":"bytes[]"}],"name":"swapExactVaultForVault","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"timelock","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"treasury","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"vaults","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_token","type":"address"},{"internalType":"uint256","name":"_amount","type":"uint256"}],"name":"withdraw","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_token","type":"address"}],"name":"withdrawAll","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_strategy","type":"address"},{"internalType":"address","name":"_token","type":"address"},{"internalType":"uint256","name":"parts","type":"uint256"}],"name":"yearn","outputs":[],"stateMutability":"nonpayable","type":"function"}];
    const vault_ABI = [{"inputs":[{"internalType":"address","name":"_token","type":"address"},{"internalType":"address","name":"_governance","type":"address"},{"internalType":"address","name":"_timelock","type":"address"},{"internalType":"address","name":"_controller","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"owner","type":"address"},{"indexed":true,"internalType":"address","name":"spender","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"from","type":"address"},{"indexed":true,"internalType":"address","name":"to","type":"address"},{"indexed":false,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Transfer","type":"event"},{"inputs":[{"internalType":"address","name":"owner","type":"address"},{"internalType":"address","name":"spender","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"available","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"balance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"account","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"controller","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"subtractedValue","type":"uint256"}],"name":"decreaseAllowance","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_amount","type":"uint256"}],"name":"deposit","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"depositAll","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"earn","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"getRatio","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"governance","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"reserve","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"harvest","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"addedValue","type":"uint256"}],"name":"increaseAllowance","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"max","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"min","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_controller","type":"address"}],"name":"setController","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_governance","type":"address"}],"name":"setGovernance","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_min","type":"uint256"}],"name":"setMin","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_timelock","type":"address"}],"name":"setTimelock","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"timelock","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"token","outputs":[{"internalType":"contract IERC20","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"sender","type":"address"},{"internalType":"address","name":"recipient","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_shares","type":"uint256"}],"name":"withdraw","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"withdrawAll","outputs":[],"stateMutability":"nonpayable","type":"function"}];
    const strategy_ABI = [{"type":"function","stateMutability":"nonpayable","outputs":[],"name":"addKeeper","inputs":[{"type":"address","name":"_keeper","internalType":"address"}]},{"type":"constructor","stateMutability":"nonpayable","inputs":[{"type":"address","name":"_governance","internalType":"address"},{"type":"address","name":"_strategist","internalType":"address"},{"type":"address","name":"_controller","internalType":"address"},{"type":"address","name":"_timelock","internalType":"address"}]},{"type":"function","stateMutability":"view","outputs":[{"type":"uint256","name":"","internalType":"uint256"}],"name":"balanceOf","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"uint256","name":"","internalType":"uint256"}],"name":"balanceOfPool","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"uint256","name":"","internalType":"uint256"}],"name":"balanceOfWant","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"address","name":"","internalType":"address"}],"name":"controller","inputs":[]},{"type":"function","stateMutability":"nonpayable","outputs":[],"name":"deposit","inputs":[]},{"type":"function","stateMutability":"payable","outputs":[{"type":"bytes","name":"response","internalType":"bytes"}],"name":"execute","inputs":[{"type":"address","name":"_target","internalType":"address"},{"type":"bytes","name":"_data","internalType":"bytes"}]},{"type":"function","stateMutability":"view","outputs":[{"type":"uint256","name":"","internalType":"uint256"}],"name":"getHarvestable","inputs":[]},{"type":"function","stateMutability":"pure","outputs":[{"type":"string","name":"","internalType":"string"}],"name":"getName","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"address","name":"","internalType":"address"}],"name":"governance","inputs":[]},{"type":"function","stateMutability":"nonpayable","outputs":[],"name":"harvest","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"bool","name":"","internalType":"bool"}],"name":"harvesters","inputs":[{"type":"address","name":"","internalType":"address"}]},{"type":"function","stateMutability":"view","outputs":[{"type":"uint256","name":"","internalType":"uint256"}],"name":"keep","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"uint256","name":"","internalType":"uint256"}],"name":"keepMax","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"address","name":"","internalType":"address"}],"name":"pangolinRouter","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"uint256","name":"","internalType":"uint256"}],"name":"performanceDevFee","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"uint256","name":"","internalType":"uint256"}],"name":"performanceDevMax","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"uint256","name":"","internalType":"uint256"}],"name":"performanceTreasuryFee","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"uint256","name":"","internalType":"uint256"}],"name":"performanceTreasuryMax","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"address","name":"","internalType":"address"}],"name":"png","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"address","name":"","internalType":"address"}],"name":"png_avax_snob_lp","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"address","name":"","internalType":"address"}],"name":"png_avax_snob_lp_rewards","inputs":[]},{"type":"function","stateMutability":"nonpayable","outputs":[],"name":"revokeHarvester","inputs":[{"type":"address","name":"_harvester","internalType":"address"}]},{"type":"function","stateMutability":"view","outputs":[{"type":"address","name":"","internalType":"address"}],"name":"rewards","inputs":[]},{"type":"function","stateMutability":"nonpayable","outputs":[],"name":"setController","inputs":[{"type":"address","name":"_controller","internalType":"address"}]},{"type":"function","stateMutability":"nonpayable","outputs":[],"name":"setGovernance","inputs":[{"type":"address","name":"_governance","internalType":"address"}]},{"type":"function","stateMutability":"nonpayable","outputs":[],"name":"setkeep","inputs":[{"type":"uint256","name":"_keep","internalType":"uint256"}]},{"type":"function","stateMutability":"nonpayable","outputs":[],"name":"setPerformanceDevFee","inputs":[{"type":"uint256","name":"_performanceDevFee","internalType":"uint256"}]},{"type":"function","stateMutability":"nonpayable","outputs":[],"name":"setPerformanceTreasuryFee","inputs":[{"type":"uint256","name":"_performanceTreasuryFee","internalType":"uint256"}]},{"type":"function","stateMutability":"nonpayable","outputs":[],"name":"setStrategist","inputs":[{"type":"address","name":"_strategist","internalType":"address"}]},{"type":"function","stateMutability":"nonpayable","outputs":[],"name":"setTimelock","inputs":[{"type":"address","name":"_timelock","internalType":"address"}]},{"type":"function","stateMutability":"nonpayable","outputs":[],"name":"setWithdrawalDevFundFee","inputs":[{"type":"uint256","name":"_withdrawalDevFundFee","internalType":"uint256"}]},{"type":"function","stateMutability":"nonpayable","outputs":[],"name":"setWithdrawalTreasuryFee","inputs":[{"type":"uint256","name":"_withdrawalTreasuryFee","internalType":"uint256"}]},{"type":"function","stateMutability":"view","outputs":[{"type":"address","name":"","internalType":"address"}],"name":"snob","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"address","name":"","internalType":"address"}],"name":"strategist","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"address","name":"","internalType":"address"}],"name":"timelock","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"address","name":"","internalType":"address"}],"name":"token1","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"address","name":"","internalType":"address"}],"name":"want","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"address","name":"","internalType":"address"}],"name":"wavax","inputs":[]},{"type":"function","stateMutability":"nonpayable","outputs":[],"name":"whitelistHarvester","inputs":[{"type":"address","name":"_harvester","internalType":"address"}]},{"type":"function","stateMutability":"nonpayable","outputs":[],"name":"withdraw","inputs":[{"type":"uint256","name":"_amount","internalType":"uint256"}]},{"type":"function","stateMutability":"nonpayable","outputs":[{"type":"uint256","name":"balance","internalType":"uint256"}],"name":"withdraw","inputs":[{"type":"address","name":"_asset","internalType":"contract IERC20"}]},{"type":"function","stateMutability":"nonpayable","outputs":[{"type":"uint256","name":"balance","internalType":"uint256"}],"name":"withdrawAll","inputs":[]},{"type":"function","stateMutability":"nonpayable","outputs":[{"type":"uint256","name":"balance","internalType":"uint256"}],"name":"withdrawForSwap","inputs":[{"type":"uint256","name":"_amount","internalType":"uint256"}]},{"type":"function","stateMutability":"view","outputs":[{"type":"uint256","name":"","internalType":"uint256"}],"name":"withdrawalDevFundFee","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"uint256","name":"","internalType":"uint256"}],"name":"withdrawalDevFundMax","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"uint256","name":"","internalType":"uint256"}],"name":"withdrawalTreasuryFee","inputs":[]},{"type":"function","stateMutability":"view","outputs":[{"type":"uint256","name":"","internalType":"uint256"}],"name":"withdrawalTreasuryMax","inputs":[]}];

    const timelock_addr = "0x0B11B4399DA7c88F5C7Cd42DE7F4290bBD150e80";
    const governance_addr = "0x0B11B4399DA7c88F5C7Cd42DE7F4290bBD150e80";
    const strategist_addr = timelock_addr;

    const deploy = async (name) => {
        console.log(`mending deploy for ${name}`);
        const strategy_name = `Strategy${name}`;
        const vault_name = `Vault${name}`;

        let lp, strategy, Strategy, vault, Vault, controller_addr;

        switch(pools[name].controller){
            case "sushi": controller_addr="0xaBfD0aB24F4291725627a6FDb9267f32b2a93d8C"; break;
        }

        // if there is no targets or data array, create one
        if (!pools[name].targets) {
            pools[name].targets = [];
        }
        if (!pools[name].data) {
            pools[name].data = [];
        }

        const Controller = new ethers.Contract(controller_addr, controller_ABI, deployer);
        const IController = new ethers.utils.Interface(controller_ABI);

         /* Deploy Strategy */
        if (!pools[name].strategy_addr) {
            strategy = await ethers.getContractFactory(strategy_name);
            Strategy = await strategy.deploy(governance_addr, strategist_addr, controller_addr, timelock_addr);

            pools[name].strategy_addr = Strategy.address;
            writeFileSync("./scripts/deploy/deploy.json", JSON.stringify(pools));
            console.log(`deployed ${strategy_name} at : ${Strategy.address}`);

            if (verify) {
                await hre.run("verify:verify", {
                  address: Strategy.address,
                  constructorArguments: [governance_addr, strategist_addr, controller_addr, timelock_addr],
                });
                pools[name].verifiedStrategy = true;
                writeFileSync("./scripts/deploy/deploy.json", JSON.stringify(pools));
                console.log(`verified ${strategy_name}`);
            }
        }

        else {
            /* Connect to Strategy */
            Strategy = new ethers.Contract(pools[name].strategy_addr, strategy_ABI, deployer);
            console.log(`connected to ${strategy_name} at : ${Strategy.address}`);
            let strategy_controller = await Strategy.controller();
            if(!pools[name].strategy_set_controller && strategy_controller != controller_addr) {
              pools[name].targets.push(Strategy.address);
              const IStrategy = new ethers.utils.Interface(strategy_ABI);
              pools[name].data.push(IStrategy.encodeFunctionData("setController", [controller_addr]));
              pools[name].strategy_set_controller = true;
              writeFileSync("./scripts/deploy/deploy.json", JSON.stringify(pools));
              console.log(`encoded setController in the Strategy for ${name}`);
            }
        }

        /* Deploy Vault */
        if (!pools[name].vault_addr) {
            lp = await Strategy.want();
            let vault_addr = await Controller.vaults(lp);
            console.log("vault_addr: ",vault_addr);

            // If we didn't supply a vault, but we found an old one...
            if (vault_addr != 0) {
                Vault = new ethers.Contract(vault_addr, vault_ABI, deployer);
                pools[name].vault_addr = Vault.address;
                pools[name].setVault=true;
                // pools[name].addGauge=true;
                writeFileSync("./scripts/deploy/deploy.json", JSON.stringify(pools));
            }
            // If we didn't supply a vault, and we didn't have one previously...
            else {
                vault = await ethers.getContractFactory(vault_name);
                Vault = await vault.deploy(lp, governance_addr, timelock_addr, controller_addr);
                console.log(`deployed ${vault_name} at : ${Vault.address}`);
                pools[name].vault_addr = Vault.address;
                writeFileSync("./scripts/deploy/deploy.json", JSON.stringify(pools));
                if (verify) {
                await hre.run("verify:verify", {
                    address: Vault.address,
                    constructorArguments: [lp, governance_addr, timelock_addr, controller_addr],
                });
                pools[name].verifiedVault = true;
                writeFileSync("./scripts/deploy/deploy.json", JSON.stringify(pools));
                console.log(`verified ${vault_name}`);
                }
            } 
        }

        else {
            lp = await Strategy.want();
            Vault = new ethers.Contract(pools[name].vault_addr, vault_ABI, deployer);
            console.log(`connected to ${vault_name} at : ${Vault.address}`);
            let vault_controller = await Vault.controller();
            if(!pools[name].vault_set_controller && vault_controller != controller_addr) {
              pools[name].targets.push(Vault.address);
              const IVault = new ethers.utils.Interface(vault_ABI);
              pools[name].data.push(IVault.encodeFunctionData("setController", [controller_addr]));
              pools[name].vault_set_controller = true;
              writeFileSync("./scripts/deploy/deploy.json", JSON.stringify(pools));
              console.log(`encoded setController in the Vault for ${name}`);
            }
      
            let old_vault_addr = await Controller.vaults(lp);
            console.log("old vault_addr: ",old_vault_addr);
            // If we supplied a vault and it is an old one...
            if (old_vault_addr == Vault.address) {
              pools[name].setVault=true;
              //pools[name].addGauge=true;
              writeFileSync("./scripts/deploy/deploy.json", JSON.stringify(pools));
            }
            else if(old_vault_addr != 0) {
              console.warn(`WARNING: Vault Previously Set: ${old_vault_addr}`);
            } 
        }

        /* Encoding for Set Vault */
        if(!pools[name].setVault){
            pools[name].targets.push(controller_addr);
            pools[name].data.push(IController.encodeFunctionData("setVault", [lp, pools[name].vault_addr]));
            pools[name].setVault = true;
            writeFileSync("./scripts/deploy/deploy.json", JSON.stringify(pools));
            console.log(`encoded setVault for ${name}`);
        }
        
        /* Encoding for Approve Strategy */
        if(!pools[name].approveStrategy){
            pools[name].targets.push(controller_addr);
            pools[name].data.push(IController.encodeFunctionData("approveStrategy", [lp, pools[name].strategy_addr]));
            pools[name].approveStrategy = true;
            writeFileSync("./scripts/deploy/deploy.json", JSON.stringify(pools));
            console.log(`encoded approveStrategy for ${name}`);
        }

        /* 
        Encoding Harvest for old strategy
        only runs if there was an old strategy on the same controller
        Be sure to check that the Timelock Controller has the correct permissions in the old strategy
        */
        if(!pools[name].harvest) {
            const old_strategy_addr = await Controller.strategies(lp);
            if (old_strategy_addr != 0) {
              const IStrategy = new ethers.utils.Interface(strategy_ABI);
              pools[name].targets.push(old_strategy_addr);
              pools[name].data.push(IStrategy.encodeFunctionData("harvest", []));
              pools[name].harvest = true;
              writeFileSync("./scripts/deploy/deploy.json", JSON.stringify(pools));
              console.log(`encoded harvest for ${name}`);
            }
            else {
              pools[name].harvest = true;
              writeFileSync("./scripts/deploy/deploy.json", JSON.stringify(pools));
            }
        }

        /* Encoding for Set Strategy */
        if (!pools[name].setStrategy){
            pools[name].targets.push(controller_addr);
            pools[name].data.push(IController.encodeFunctionData("setStrategy", [lp, pools[name].strategy_addr]));
            pools[name].setStrategy = true;
            writeFileSync("./scripts/deploy/deploy.json", JSON.stringify(pools));
            console.log(`encoded setStrategy for ${name}`);
        }

        /* Encoding for Earn */
        if (!pools[name].earn){
            const old_strategy_addr = await Controller.strategies(lp);
            if (old_strategy_addr != 0) {
            const IVault = new ethers.utils.Interface(vault_ABI);
            pools[name].targets.push(pools[name].vault_addr);
            pools[name].data.push(IVault.encodeFunctionData("earn", []));
            pools[name].earn = true;
            writeFileSync("./scripts/deploy/deploy.json", JSON.stringify(pools));
            console.log(`encoded earn for ${name}`);
            }
            else {
                pools[name].earn = true;
                writeFileSync("./scripts/deploy/deploy.json", JSON.stringify(pools));
            }
        }

        /* Encoding for Whitelist Harvester */
        if(!pools[name].whitelist){
            const IStrategy = new ethers.utils.Interface(strategy_ABI);
            pools[name].targets.push(pools[name].strategy_addr);
            pools[name].data.push(IStrategy.encodeFunctionData("whitelistHarvester", ["0x0B11B4399DA7c88F5C7Cd42DE7F4290bBD150e80"]));
            pools[name].whitelist = true;
            writeFileSync("./scripts/deploy/deploy.json", JSON.stringify(pools));
            console.log(`encoded whitelistHarvester for ${name}`);
        }
        return;
    };

    for (const name in pools) {
        await deploy(name);
    }

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });