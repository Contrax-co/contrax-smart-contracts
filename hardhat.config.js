require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-ethers");
require("solidity-coverage");
require("hardhat-deploy");
require("hardhat-gas-reporter");
require("hardhat-contract-sizer");
const { removeConsoleLog } = require("hardhat-preprocessor");
require("dotenv").config();

module.exports = {
  defaultNetwork: "rinkeby",
  solidity: {
    compilers: [
      {
        version: "0.6.7",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
            details: {
              yul: false
            }
          },
        },
      },
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
            details: {
              yul: false
            }
          },
        },
      },
    ],
  },
  networks: {
    // hardhat: {
    //   forking: {
    //     url: `https://ftmrpc.ultimatenodes.io/`,
    //   },
    //   accounts: {
    //     mnemonic: process.env.MNEMONIC,
    //   },
    //   hardfork: "london",
    //   gasPrice: "auto",
    //   gas: 2500000,
    // },
    // mainnet: {
    //   url: `https://mainnet.infura.io/v3/${process.env.INFURA_KEY}`,
    //   accounts: [`0x${process.env.MNEMONIC}`],
    // },
    // matic: {
    //   url: "https://polygon-rpc.com/",
    //   accounts: [`0x${process.env.MNEMONIC}`],
    // },
    // arbitrum: {
    //   url: `https://arb1.arbitrum.io/rpc/`,
    //   accounts: [`0x${process.env.MNEMONIC}`],
    // },
    // metis: {
    //   url: `https://andromeda.metis.io/?owner=1088`,
    //   accounts: [`0x${process.env.MNEMONIC}`],
    // },
    // moonbeam: {
    //   url: `https://rpc.api.moonbeam.network`,
    //   accounts: [`0x${process.env.MNEMONIC}`]
    // },
    // fantom: {
    //   url: `https://rpc.ftm.tools/`,
    //   accounts: [`0x${process.env.MNEMONIC}`],
    //   gas: 4000000
    // },
    rinkeby: {
      url: "https://rinkeby.infura.io/v3/d02f9a7da35c4efdb76746541d803608",
      accounts: ["Add private key here"],
    },
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: false,
  },
  etherscan: {
    apiKey: "DCQ9MBWPQ37WZ9NGZX4F14A53N3SQPPJY7",
  },
  paths: {
    sources: "./src",
    tests: "./src/tests/strategies",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  // gasReporter: {
  //   enabled: true,
  //   coinmarketcap: process.env.COINMARKETCAP,
  //   currency: "USD",
  //   gasPrice: 32,
  // },
  preprocess: {
    eachLine: removeConsoleLog((hre) => hre.network.name !== "hardhat" && hre.network.name !== "localhost"),
  },
  mocha: {
    timeout: 20000000,
  },
  vyper: {
    version: "0.2.7",
  },
};
