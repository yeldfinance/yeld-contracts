const yDAI = artifacts.require('yDAI');
const yTUSD = artifacts.require('yTUSD');
const yUSDC = artifacts.require('yUSDC');
const yUSDT = artifacts.require('yUSDT');

const yeld = '0x468ab3b1f63A1C14b361bC367c3cC92277588Da1'
const retirementYield = '0xF572096BbB414C6cC0C8915e9BF9e77C89eff2bD'

module.exports = async deployer => {
  await deployer.deploy(yDAI, yeld, retirementYield);
  const deployedYDAI = await yDAI.deployed()
  console.log('Deployed YDAI', deployedYDAI.address)
  await deployer.deploy(yTUSD, yeld, retirementYield);
  const deployedYTUSD = await yTUSD.deployed()
  console.log('Deployed YTUSD', deployedYTUSD.address)
  await deployer.deploy(yUSDC, yeld, retirementYield);
  const deployedYUSDC = await yUSDC.deployed()
  console.log('Deployed YUSDC', deployedYUSDC.address)
  await deployer.deploy(yUSDT, yeld, retirementYield);
  const deployedYUSDT = await yUSDT.deployed()
  console.log('Deployed YUSDT', deployedYUSDT.address)
}
