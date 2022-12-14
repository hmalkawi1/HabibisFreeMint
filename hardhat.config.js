const { version } = require("chai");

require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("hardhat-gas-reporter");
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
module.exports = {
  solidity: {
    compilers: [{ version: "0.8.7" }, { version: "0.8.17" }],
  },
  gasReporter: {
    enabled: true,
    coinmarketcap: "2bd639b0-ef37-4768-8aa5-b1f6dd6ed437",
    currency: "USD",
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
  },

  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
  allowUnlimitedContractSize: true,
  blockGasLimit: 0x1fffffffffffff,
};
