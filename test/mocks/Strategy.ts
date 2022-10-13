const hre = require("hardhat")
const { ethers } = require("hardhat")
import {
    Contract,
    Signer
} from "ethers";

export async function setupMockStrategy(
    contract_name: string, strategy_addr: string, fold: boolean,
    Controller: Contract, walletSigner: Signer, timelockSigner: Signer,
    governanceSigner: Signer, strategistSigner: Signer) {

    await hre.network.provider.send("hardhat_setBalance", [
        await walletSigner.getAddress(), 
        "0x10000000000000000000000",]
    );

    let Strategy: Contract
    let asset_addr: string
    let stratABI = (await ethers.getContractFactory(contract_name)).interface;

    if (strategy_addr == "") { // strategy not prodivded -- DEPLOY MOCK
        let timelock_addr = await timelockSigner.getAddress()
        let governance_addr = await governanceSigner.getAddress()
        let strategist_addr = await strategistSigner.getAddress()
        let controller_addr = Controller.address;

        console.log(`Deploying strategy ${contract_name}`);
        const stratFactory = await ethers.getContractFactory(contract_name);

        // Now we can deploy the new strategy
        Strategy = await stratFactory.connect(walletSigner).deploy(
            governance_addr,
            strategist_addr,
            controller_addr,
            timelock_addr
        );
        console.log(`Deployed new strategy at ${Strategy.address}`);

        strategy_addr = Strategy.address;
        asset_addr = await Strategy.want();
        console.log(`Asset address: ${asset_addr}`);

        const approveStrategy = await Controller.connect(timelockSigner).approveStrategy(asset_addr, strategy_addr);
        const tx_approveStrategy = await approveStrategy.wait(1);

        if (!tx_approveStrategy.status) {
            console.error(`Error approving the strategy for: ${contract_name}`);
            return Strategy;
        }
        console.log(`Approved Strategy in the Controller for: ${contract_name}\n`);

        /* Handle old strategy */
        const oldStrategy_addr = await Controller.strategies(asset_addr);
        if (oldStrategy_addr != 0) {
            /// NB When funds are stuck because of a harvesting issue, we need a way to 
            /// retrieve them and withdraw it into the new strategy.
            // The console.logic below runs for old strategies that don't present a major harvesting issue. 
            console.log(`Old strategy address: ${oldStrategy_addr}`);
            
            const oldStrategy = new ethers.Contract(oldStrategy_addr, stratABI, governanceSigner);

            if (oldStrategy.functions['harvest']) {
                const harvest = await oldStrategy.connect(governanceSigner).harvest();
                const tx_harvest = await harvest.wait(1);
                if (!tx_harvest.status) {
                    console.error(`Error harvesting the old strategy for: ${contract_name}`);
                    return Strategy;
                 }
                 console.log(`Harvested the old strategy for: ${contract_name}`);
            }
            if (fold) {

                console.log("folding")
                // Before we can setup new strategy we must deleverage from old one
                const deleverage = await oldStrategy.connect(governanceSigner).deleverageToMin();
                const tx_deleverage = await deleverage.wait(1);
                if (!tx_deleverage.status) {
                    console.error(`Error deleveraging the old strategy for: ${contract_name}`);
                    return Strategy;
                }
                console.log(`Deleveraged the old strategy for: ${contract_name}`);
            }
        }
    } else {  // Get current Strategy 
        Strategy = new ethers.Contract(strategy_addr, stratABI, governanceSigner);
    }
    return Strategy;
}