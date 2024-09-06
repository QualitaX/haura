require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  networks: {
    sepolia: {
      chainId: Number(process.env.SEOPPLIA_CHAIN_ID),
      url: `${process.env.SEPOLIA_ENDPOINT}`,
      gasPrice: 2100000,
      accounts: [
        `${process.env.KEY1}`,
        `${process.env.KEY2}`,
        `${process.env.KEY3}`
      ]
    }
  },
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000
      }
    }
  }
};
