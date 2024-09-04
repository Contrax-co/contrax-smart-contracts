import '@nomiclabs/hardhat-waffle';
require("dotenv").config();

import { HardhatUserConfig, task } from "hardhat/config";

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.4',
        settings: {
          optimizer: {
              enabled: true,
              runs: 200,
          },
        },
      }
    ]
  },
  networks: {
    hardhat: {
      chainId: 42161,
      forking: {
          url: "https://arb1.arbitrum.io/rpc",
      },
    },
    // arbitrum: {
    //   chainId: 42161,
    //   url: "https://arb1.arbitrum.io/rpc",
    //   accounts: [process.env.PRIVATE_KEY ?? '']
    // },
    // mainnet: {
    //   chainId: 42161,
    //   url: "https://arb1.arbitrum.io/rpc",
    //   accounts: [process.env.PRIVATE_KEY ?? '']
    // },
    // testnet: {
    //   chainId: 421611,
    //   url: "https://rinkeby.arbitrum.io/rpc",
    //   accounts: [process.env.PRIVATE_KEY ?? '']
    // },
  },
  mocha: {
    timeout: 1000000
  },

}
export default config;