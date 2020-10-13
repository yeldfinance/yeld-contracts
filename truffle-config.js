// Required for the ledger provider
require("@babel/polyfill")

const HDWalletProvider = require('truffle-hdwallet-provider');
const LedgerWalletProvider = require('truffle-ledger-provider');
const infuraKey = "424377a7ed22481bbeb34bac96967b7b";
const fs = require('fs');
const mnemonic = fs.readFileSync(".secret").toString().trim();
const ledgerOptions = {
  networkId: 1, // mainnet
  path: "44'/60'/0'/0", // ledger default derivation path
  askConfirm: false,
  accountsLength: 1,
  accountsOffset: 0
};

module.exports = {
  networks: {
    // Useful for testing. The `development` name is special - truffle uses it by default
    // if it's defined here and no other network is specified at the command line.
    // You should run a client (like ganache-cli, geth or parity) in a separate terminal
    // tab if you use this network and you must also set the `host`, `port` and `network_id`
    // options below to some value.
    //
    // development: {
    //  host: "127.0.0.1",     // Localhost (default: none)
    //  port: 8545,            // Standard Ethereum port (default: none)
    //  network_id: "*",       // Any network (default: none)
    // },

    // Another network with more advanced options...
    // advanced: {
      // port: 8777,             // Custom port
      // network_id: 1342,       // Custom network
      // gas: 8500000,           // Gas sent with each transaction (default: ~6700000)
      // gasPrice: 20000000000,  // 20 gwei (in wei) (default: 100 gwei)
      // from: <address>,        // Account to send txs from (default: accounts[0])
      // websockets: true        // Enable EventEmitter interface for web3 (default: false)
    // },

    // Useful for deploying to a public network.
    // NB: It's important to wrap the provider as a function.
    ropsten: {
      provider: () => new HDWalletProvider(mnemonic, `https://ropsten.infura.io/v3/${infuraKey}`),
      network_id: 3,       // Ropsten's id
      gas: 5500000,        // Ropsten has a lower block limit than mainnet
      confirmations: 1,    // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    },

    mainnet: {
      provider: new LedgerWalletProvider(ledgerOptions, `https://mainnet.infura.io/v3/${infuraKey}`),
      network_id: 1,
      gas: 46000000,
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
