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
    const strategy_ABI = [{"inputs":[{"internalType":"address","name":"_governance","type":"address"},{"internalType":"address","name":"_strategist","type":"address"},{"internalType":"address","name":"_controller","type":"address"},{"internalType":"address","name":"_timelock","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"inputs":[],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"balanceOfPool","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"balanceOfWant","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"controller","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"dai","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"deposit","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_target","type":"address"},{"internalType":"bytes","name":"_data","type":"bytes"}],"name":"execute","outputs":[{"internalType":"bytes","name":"response","type":"bytes"}],"stateMutability":"payable","type":"function"},{"inputs":[],"name":"feeDistributor","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getHarvestable","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"getName","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"pure","type":"function"},{"inputs":[],"name":"governance","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"harvest","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"harvesters","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"keep","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"keepMax","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"keepReward","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"miniChef","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"performanceDevFee","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"performanceDevMax","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"performanceTreasuryFee","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"performanceTreasuryMax","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"poolId","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_harvester","type":"address"}],"name":"revokeHarvester","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_controller","type":"address"}],"name":"setController","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_feeDistributor","type":"address"}],"name":"setFeeDistributor","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_governance","type":"address"}],"name":"setGovernance","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_keepSUSHI","type":"uint256"}],"name":"setKeep","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_keepReward","type":"uint256"}],"name":"setKeepReward","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_performanceDevFee","type":"uint256"}],"name":"setPerformanceDevFee","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_performanceTreasuryFee","type":"uint256"}],"name":"setPerformanceTreasuryFee","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_rewardToken","type":"address"}],"name":"setRewardToken","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_strategist","type":"address"}],"name":"setStrategist","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_timelock","type":"address"}],"name":"setTimelock","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_withdrawalDevFundFee","type":"uint256"}],"name":"setWithdrawalDevFundFee","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_withdrawalTreasuryFee","type":"uint256"}],"name":"setWithdrawalTreasuryFee","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"strategist","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"sushi","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"sushiRouter","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"sushi_dai_poolId","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"sushi_weth_dai_lp","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"timelock","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"token0","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"token1","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"uni","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"univ2Router2","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"want","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"weth","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_harvester","type":"address"}],"name":"whitelistHarvester","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_amount","type":"uint256"}],"name":"withdraw","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"contract IERC20","name":"_asset","type":"address"}],"name":"withdraw","outputs":[{"internalType":"uint256","name":"balance","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"withdrawAll","outputs":[{"internalType":"uint256","name":"balance","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_amount","type":"uint256"}],"name":"withdrawForSwap","outputs":[{"internalType":"uint256","name":"balance","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"withdrawalDevFundFee","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"withdrawalDevFundMax","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"withdrawalTreasuryFee","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"withdrawalTreasuryMax","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"}];

    const timelock_addr = "0xCb410A689A03E06de0a6247b13C13D14237DecC8";
    const governance_addr = "0xCb410A689A03E06de0a6247b13C13D14237DecC8";
    const strategist_addr = timelock_addr;

    const deploy = async (name) => {
        console.log(`mending deploy for ${name}`);
        const strategy_name = `Strategy${name}`;
        const vault_name = `Vault${name}`;

        let lp, strategy, Strategy, vault, Vault, controller_addr;

        switch(pools[name].controller){
            case "sushi": controller_addr="0x1C233a46eAE1F928c0467a3C75228E26Ea9888d4"; break;
            case "dpx": controller_addr="0x19390136f374A1Ef3CD15C97d8a430eDa26596cC"; break;
            case "gmx": controller_addr="0x6322bf7c9ed6563DBe9f73bbE2085d6cd19371e7"; break;
            case "dodo": controller_addr="0xaC58Ff6C1f02779869beB4Db5dF9d25A6213ae95"; break;
            case "plutus": controller_addr="0xAFC36887EE43EDDeB5773fedC877481ec97625a7"; break;
            case "jones": controller_addr="0xF6e1d062DEfe3AEBF8674B930f621Adc36Ad870c"; break;
            case "stargate": controller_addr = "0x8B82E63D4494bE23a479201ADb75F7E43247E859"; break;
            case "fish": controller_addr="0xF36059454bE1e87E88506DdcF2aa65a1CEF8C1bF"; break; 
            case "hop": controller_addr="0x8121Fa4e27051DC3b86E4e7d6Fb2a02d62fe6F68"; break;
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
            pools[name].data.push(IStrategy.encodeFunctionData("whitelistHarvester", ["0x4E63cA83731351eBF109E16928a69d77d4e06469"]));
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