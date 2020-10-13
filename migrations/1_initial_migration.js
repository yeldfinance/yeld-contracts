require("regenerator-runtime/runtime");

const Token = artifacts.require('Token')
const RetirementYieldTreasury = artifacts.require('RetirementYieldTreasury')

const asyncTimeout = time => {
  return new Promise(resolve => {
    setTimeout(resolve, time)
  })
}

module.exports = async function(deployer, network, accounts) {
  const treasury = await RetirementYieldTreasury.deploy()
  console.log('Treasury', await treasury.deployed())
}
