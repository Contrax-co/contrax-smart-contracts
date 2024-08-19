import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv";
import { network } from "hardhat";
dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },

  networks: {
    hardhat: {
      chainId: 42161,
      forking: {
        url: "https://arbitrum.llamarpc.com", //`https://arbitrum-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`, // "https://arb1.arbitrum.io/rpc",
        // blockNumber: 211889162,
      },
    },

    arbitrum: {
      chainId: 42161,
      url: "https://arb1.arbitrum.io/rpc",
      accounts: [process.env.PRIVATE_KEY ?? ""],
    },

    base: {
      chainId: 8453,
      url: "https://base.llamarpc.com",
      accounts: [process.env.PRIVATE_KEY ?? ""],
    },
    mainnet: {
      chainId: 42161,
      url: "https://arb1.arbitrum.io/rpc",
      accounts: [process.env.PRIVATE_KEY ?? ""],
    },
    testnet: {
      chainId: 421611,
      url: "https://rinkeby.arbitrum.io/rpc",
      accounts: [process.env.PRIVATE_KEY ?? ""],
    },
  },
  mocha: {
    timeout: 1000000,
  },
  etherscan: {
    apiKey: {
      base: process.env.BASE_API_KEY ?? "",
      arb: process.env.ETHERSCAN_API_KEY ?? "",
    },
    customChains: [
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org/",
        },
      },
    ],
  },
};
export default config;

