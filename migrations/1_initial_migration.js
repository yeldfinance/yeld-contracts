const testYDAI = artifacts.require('testYDAI')
const testYeldDAI = artifacts.require('testYeldDAI')
const Token = artifacts.require('Token')
let testYDAIDeployed
let testYeldDAIDeployed
let yeldToken
let daiToken

const asyncTimeout = time => {
  return new Promise(resolve => {
    setTimeout(resolve, time)
  })
}

module.exports = function(deployer, network, accounts) {
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
  }).then(async _testYDAI => {
    testYDAIDeployed = _testYDAI

    const balance = await web3.eth.getBalance("0x407d73d8a49eeb85d32cf465507dd71d507100c1")
    console.log('yeldDAI eth balance:', balance)

    await yeldToken.transfer(testYDAIDeployed.address, String(web3.utils.toWei('1000', 'ether'))) // 1000 tokens
    await testYeldDAIDeployed.setYDAI(testYDAIDeployed.address)
    // The price update will not work now that the contract has been changed to 1 day per price update
    const priceBeforeUpdate = String(await testYeldDAIDeployed.yeldReward())
    console.log('Price before update:', priceBeforeUpdate)
    console.log('Waiting 5 seconds to update the price...')
    await asyncTimeout(5e3)
    console.log('Updating price...')
    await testYeldDAIDeployed.updatePrice()
    const priceAfterUpdate = String(await testYeldDAIDeployed.yeldReward())
    console.log('Price after update:', priceAfterUpdate)
    console.log('Approving 1000 DAI tokens...')
    await daiToken.approve(testYeldDAIDeployed.address, String(web3.utils.toWei('1000', 'ether'))) // Approve 10 DAI tokens
    console.log('Depositing 1000 DAI tokens...')
    const yeldDAITokensBeforeDeposit = String(await testYeldDAIDeployed.balanceOf(accounts[0]))
    console.log('yeldDAI tokens before deposit:', yeldDAITokensBeforeDeposit)
    await testYDAIDeployed.deposit(String(web3.utils.toWei('1000', 'ether')))
    const yeldDAITokensAfterDeposit = String(await testYeldDAIDeployed.balanceOf(accounts[0]))
    console.log('yeldDAI tokens after deposit:', yeldDAITokensAfterDeposit)
  })
}
