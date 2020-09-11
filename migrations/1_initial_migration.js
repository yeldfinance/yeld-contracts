// yVault
// Controller
// Strategy
// Governance Proxy (? Maybe its a multisignature wallet
// TreasuryVault

const yVault = artifacts.require('yVault')
const Controller = artifacts.require('Controller')
const StrategyDAICurve = artifacts.require('StrategyDAICurve')
const Governance = artifacts.require()

module.exports = function(deployer) {
  deployer.deploy(yVault).then(yVault => {
    
  })
};
