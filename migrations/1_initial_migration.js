// yVault
// Controller
// Strategy
// Governance Proxy (? Maybe its a multisignature wallet
// TreasuryVault

const testYDAI = artifacts.require('testYDAI')
const testYeldDAI = artifacts.require('testYeldDAI')
const Token = artifacts.require('Token')
let testYDAIDeployed
let testYeldDAIDeployed
let yeldToken
let daiToken 

module.exports = function(deployer) {
  deployer.deploy(Token).then(dai => {
    daiToken = dai
    return deployer.deploy(Token)
  }).then(yeld => {
    yeldToken = yeld
    return deployer.deploy(testYeldDAI)
  }).then(_testYeldDAI => {
    testYeldDAIDeployed = _testYeldDAI
    return deployer.deploy(
      testYDAI, 
      yeldToken.address,
      _testYeldDAI.address,
    )
  }).then(_testYDAI => {
    testYDAIDeployed = _testYDAI

    yeldToken.transfer(testYDAIDeployed.address, 1000e18) // 1000 tokens
    testYeldDAIDeployed.setYDAI(testYDAIDeployed.address)
    testYeldDAIDeployed.startOracle({
      value: web3.toWei('0.5', 'ether'),
    })
    daiToken.approve(testYeldDAIDeployed.address, 1000e18) // Approve 1000 DAI tokens
    testYDAIDeployed.deposit(500e18)
  })
};
