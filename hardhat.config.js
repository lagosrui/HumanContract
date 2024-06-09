

require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  sepolia: {
    url: process.env.ALCHEMY_TESTNET_RPC_URL,
    accounts: [`${process.env.TESTNET_PRIVATE_KEY}`]
  }
};
