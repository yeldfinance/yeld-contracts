const yDAI = artifacts.require('yDAI')
const yTUSD = artifacts.require('yTUSD')
const yUSDC = artifacts.require('yUSDC')
const yUSDT = artifacts.require('yUSDT')

const yeld = '0x468ab3b1f63A1C14b361bC367c3cC92277588Da1'
const retirementYield = '0xF572096BbB414C6cC0C8915e9BF9e77C89eff2bD'
const devTreasury = '0x7c5bAe6BC84AE74954Fd5672feb6fB31d2182EC6'

// "0x468ab3b1f63A1C14b361bC367c3cC92277588Da1", "0xF572096BbB414C6cC0C8915e9BF9e77C89eff2bD", "0x7c5bAe6BC84AE74954Fd5672feb6fB31d2182EC6"

module.exports = async deployer => {
	// console.log('Starting deployment...')
	// deployer
	// 	.deploy(yDAI, yeld, retirementYield, devTreasury)
	// 	.then(deployed => {
	// 		console.log('Deployed YDAI', deployed.address)
	// 		return deployer.deploy(yTUSD, yeld, retirementYield, devTreasury)
	// 	})
	// 	.then(deployed => {
	// 		console.log('Deployed YTUSD', deployed.address)
	// 		return deployer.deploy(yUSDC, yeld, retirementYield, devTreasury)
	// 	})
	// 	.then(deployed => {
	// 		console.log('Deployed YUSDC', deployed.address)
	// 		return deployer.deploy(yUSDT, yeld, retirementYield, devTreasury)
	// 	})
	// 	.then(deployed => {
	// 		console.log('Deployed YUSDT', deployed.address)
	// 	})
	// 	.catch(e => {
	// 		console.log('err', e)
	// 	})
}
