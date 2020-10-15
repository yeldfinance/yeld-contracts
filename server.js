const Web3 = require('web3')
const HDWalletProvider = require('truffle-hdwallet-provider');
const infuraKey = "424377a7ed22481bbeb34bac96967b7b";
const fs = require('fs');
const mnemonic = fs.readFileSync(".secret").toString().trim();
const provider = new HDWalletProvider(mnemonic, `https://mainnet.infura.io/v3/${infuraKey}`)
const web3 = new Web3(provider)

console.log('web3', web3)
console.log('web3', web3.eth.getAccounts())