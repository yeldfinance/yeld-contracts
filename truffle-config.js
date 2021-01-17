// Required for the ledger provider
const HDWalletProvider = require('truffle-hdwallet-provider');
// const LedgerWalletProvider = require('truffle-ledger-provider');
const infuraKey = "424377a7ed22481bbeb34bac96967b7b";
const fs = require('fs');
const mnemonic = fs.readFileSync(".secret").toString().trim();
// const ledgerOptions = {
//   networkId: 1, // mainnet
//   path: "44'/60'/0'/0", // ledger default derivation path
//   askConfirm: false,
//   accountsLength: 1,
//   accountsOffset: 0
// };

module.exports = {
  networks: {
    // development: {
    //  host: "127.0.0.1",     // Localhost (default: none)
    //  port: 8545,            // Standard Ethereum port (default: none)
    //  network_id: "*",       // Any network (default: none)
    // },
    ropsten: {
      provider: () => new HDWalletProvider(mnemonic, `https://ropsten.infura.io/v3/${infuraKey}`),
      network_id: 3,       // Ropsten's id
      gas: 8e6,        // Ropsten has a lower block limit than mainnet
      confirmations: 1,    // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    },

    rinkeby: {
      provider: () => new HDWalletProvider(mnemonic, `https://rinkeby.infura.io/v3/${infuraKey}`),
      network_id: 4,       // Ropsten's id
      gas: 8e6,        // Ropsten has a lower block limit than mainnet
      confirmations: 1,    // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    },

    mainnet: {
      // provider: new LedgerWalletProvider(ledgerOptions, `https://mainnet.infura.io/v3/${infuraKey}`),
      provider: new HDWalletProvider(mnemonic, `https://mainnet.infura.io/v3/${infuraKey}`),
      network_id: 1,
      gas: 46e6,
      confirmations: 1,    // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
    },
  },
  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },
  compilers: {
    solc: {
      version: "0.5.17",    // Fetch exact version from solc-bin (default: truffle's version)
      settings: {          // See the solidity docs for advice about optimization and evmVersion
       optimizer: {
         enabled: true,
         runs: 999999,
       },
      }
    }
  }
}
