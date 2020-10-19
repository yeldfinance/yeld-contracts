const Web3 = require('web3')
const HDWalletProvider = require('@truffle/hdwallet-provider');
const infuraKey = "424377a7ed22481bbeb34bac96967b7b";
const fs = require('fs');
const mnemonic = fs.readFileSync(".secret").toString().trim();
const yeldOracleAddress = '0xDA014c50762A97824b28AAc490953381049F1a50'
const yeldOracleAbi = require('./build/contracts/YeldOracle.json').abi
let provider = new HDWalletProvider(mnemonic, `https://mainnet.infura.io/v3/${infuraKey}`)
let web3 = new Web3(provider)
let yeldOracle = {}
let counter = 0
let account

const rebalance = async () => {
  console.log('Rebalancing... ' + counter)
  try {
    provider = new HDWalletProvider(mnemonic, `https://mainnet.infura.io/v3/${infuraKey}`)
    web3 = new Web3(provider)
    account = (await web3.eth.getAccounts())[0]
    yeldOracle = new web3.eth.Contract(yeldOracleAbi, yeldOracleAddress)
    yeldOracle.methods.rebalance().send({
      from: account,
      gas: 8e6,
    })
    counter++
  } catch (e) {
    console.log('Error rabalancing, skipping...')
  }
}

setInterval(() => {
  rebalance()
}, 24 * 60 * 60 * 1e3)