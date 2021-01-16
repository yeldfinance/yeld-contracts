const yDAI = artifacts.require('yDAI');
const yTUSD = artifacts.require('yTUSD');
const yUSDC = artifacts.require('yUSDC');
const yUSDT = artifacts.require('yUSDT');

const yeld = '0x468ab3b1f63A1C14b361bC367c3cC92277588Da1'
const retirementYield = '0xF572096BbB414C6cC0C8915e9BF9e77C89eff2bD'

module.exports = async deployer => {
  const deployedYDAI = await deployer.deploy(yDAI, [yeld, retirementYield]);
  console.log('Deployed YDAI', deployedYDAI)
  const deployedYTUSD = await deployer.deploy(yTUSD, [yeld, retirementYield]);
  console.log('Deployed YTUSD', deployedYTUSD)
  const deployedYUSDC = await deployer.deploy(yUSDC, [yeld, retirementYield]);
  console.log('Deployed YUSDC', deployedYUSDC)
  const deployedYUSDT = await deployer.deploy(yUSDT, [yeld, retirementYield]);
  console.log('Deployed YUSDT', deployedYUSDT)
}
