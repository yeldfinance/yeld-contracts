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
  deployed.deploy(Token).then(dai => {
    daiToken = dai
    return deployed.deploy(Token)
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
  })
};
