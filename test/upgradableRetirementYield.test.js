const BigNumber = require('bignumber.js')
const { deployProxy } = require('@openzeppelin/truffle-upgrades')
const { assert } = require('chai')
const utils = require('./utils')
const UpgradableRetirementYield = artifacts.require('UpgradableRetirementYield')
const TestToken = artifacts.require('TestToken')
let yeld
let chi
let upgradableRetirementYield
let devTreasury

contract('UpgradableRetirementYield', accs => {
	const defaultAmount = BigNumber(1e18)
	const defaultPriceIncrease = BigNumber(1e18) // The price increases in 1e18

	beforeEach(async () => {
		devTreasury = accs[8]
		chi = await deployProxy(TestToken, [])
		yeld = await deployProxy(TestToken, [])
		upgradableRetirementYield = await deployProxy(UpgradableRetirementYield, [
			yeld.address,
			devTreasury,
			chi.address,
		])
	})

	// Works
	it("addFeeAndUpdatePrice should not change the price if there aren't yeld tokens", async () => {
		const yeldFeePriceBefore = await upgradableRetirementYield.yeldFeePrice()
		const balance = BigNumber(await web3.eth.getBalance(upgradableRetirementYield.address))

		await web3.eth.sendTransaction({
			from: accs[0],
			to: upgradableRetirementYield.address,
			value: defaultAmount,
		})

		const balance2 = BigNumber(await web3.eth.getBalance(upgradableRetirementYield.address))
		const yeldFeePriceAfter = await upgradableRetirementYield.yeldFeePrice()
		assert.ok(
			yeldFeePriceBefore.eq(yeldFeePriceAfter),
			'The price should be unchanged'
		)
		assert.ok(
			balance.plus(defaultAmount).eq(balance2),
			'The eth has not been added to the contract'
		)
	})

	// Works
	it('addFeeAndUpdatePrice|lockLiquidity should add a liquidity provider successfully with previously locked yeld tokens', async () => {
		await web3.eth.sendTransaction({
			from: accs[0],
			to: upgradableRetirementYield.address,
			value: defaultAmount,
		})
		const amountLocked = await upgradableRetirementYield.amountLocked(accs[0])
		// First approve yeld tokens
		await yeld.approve(upgradableRetirementYield.address, defaultAmount)
		// Then lock liquidity
		await upgradableRetirementYield.lockLiquidity(defaultAmount)
		const amountLocked2 = await upgradableRetirementYield.amountLocked(accs[0])
		assert.ok(
			BigNumber(amountLocked).plus(defaultAmount).eq(amountLocked2),
			'The liquidity has not been updated correctly'
		)
	})

	// Works
	it('should setup the initial yeldFeePrice', async () => {
		await addInitialLiquidityWithFee(
			accs,
			defaultAmount,
		)
		const updatedYeldFeePrice = Number(await upgradableRetirementYield.yeldFeePrice())

		assert.ok(
			BigNumber(updatedYeldFeePrice).eq(2e18),
			'The updated yeldFeePrice is not correct'
		)
	})

	// Works
	it('should update the yeldFee price correctly after the initial price for 1 staker', async () => {
		await addInitialLiquidityWithFee(
			accs,
			defaultAmount,
		)
		// Add some fee ETH to distribute and see if the price changes
		await web3.eth.sendTransaction({
			from: accs[0],
			to: upgradableRetirementYield.address,
			value: defaultAmount,
		})
		const finalUpdatedYeldFeePrice = String(await upgradableRetirementYield.yeldFeePrice())
		assert.ok(
			finalUpdatedYeldFeePrice == 1e18 + defaultPriceIncrease * 2,
			'The final updated yeldFeePrice is not correct after 2 liquidity provisions and providers'
		)
	})

	// Works
	it('should update the yeldFee price correctly after many fee additions', async () => {
		await addInitialLiquidityWithFee(
			accs,
			defaultAmount,
		)
		// Add some YELDs to distribute and see if the price changes
		for (let i = 0; i < 9; i++) {
			await web3.eth.sendTransaction({
				from: accs[0],
				to: upgradableRetirementYield.address,
				value: defaultAmount,
			})
		}
		const finalUpdatedYeldFeePrice = String(await upgradableRetirementYield.yeldFeePrice())
		assert.ok(
			finalUpdatedYeldFeePrice == 1e18 + defaultPriceIncrease * 10,
			'The final updated yeldFeePrice is not correct after 10 liquidity provisions and providers'
		)
	})

	// Works
	it('should extract the right amount of fee correctly', async () => {
		const expectedDevEarnings = defaultAmount / 2
		// 1. send YELD tokens to acc 2
		await yeld.transfer(accs[2], defaultAmount, { from: accs[0] })
		await yeld.approve(upgradableRetirementYield.address, defaultAmount, {
			from: accs[2],
		})
		await upgradableRetirementYield.lockLiquidity(defaultAmount, { from: accs[2] })
		// 2. Add ETH
		await web3.eth.sendTransaction({
			from: accs[0],
			to: upgradableRetirementYield.address,
			value: defaultAmount,
		})
		const balance = await web3.eth.getBalance(devTreasury)
		// 3. Extract earnings
		await upgradableRetirementYield.extractEarnings({
			from: accs[2],
		})
		const balance2 = await web3.eth.getBalance(devTreasury)
		assert.ok(
			BigNumber(balance).plus(expectedDevEarnings).eq(balance2),
			"The final balance isn't correct"
		)
	})

	// Works
	it('should extract the liquidity after locking it successfully', async () => {
		const daysToPass = 3.456e+7; // 400 days in seconds
		// await upgradableRetirementYield.setTimeToExitLiquidity(0); // Make sure to remove the 365 days wait
		const balance = await yeld.balanceOf(accs[0])
		// Lock some tokens
		await yeld.approve(upgradableRetirementYield.address, defaultAmount)
		await upgradableRetirementYield.lockLiquidity(defaultAmount)
		const balance2 = await yeld.balanceOf(accs[0])
		assert.ok(BigNumber(balance).minus(defaultAmount).eq(balance2), 'The yeld tokens should be transfered when locking liquidity')
		await utils.advanceTimeAndBlock(daysToPass)
		// Extract them
		await upgradableRetirementYield.extractLiquidity()
		const balance3 = await yeld.balanceOf(accs[0])
		assert.ok(BigNumber(balance).eq(balance3), 'The yeld tokens should be extracted successfully')
	})

	// Works
	it('should not allow you to extract your liquidity before the required days', async () => {
		try {
			// Lock some tokens
			await yeld.approve(upgradableRetirementYield.address, defaultAmount)
			await upgradableRetirementYield.lockLiquidity(defaultAmount)
			// Extract them
			await upgradableRetirementYield.extractLiquidity()
			assert.ok(false, "a) The test should fail since it shouldn't allow you to extract liquidity before 365 days")
		} catch (e) {
			assert.ok(true, "b) The test should fail since it shouldn't allow you to extract liquidity before 365 days")
		}
	})
})

const addInitialLiquidityWithFee = async (
	accs,
	defaultAmount,
) => {
	// Add some fee ETH to the contract
	await web3.eth.sendTransaction({
		from: accs[0],
		to: upgradableRetirementYield.address,
		value: defaultAmount,
	})
	// First approve yeld
	await yeld.approve(upgradableRetirementYield.address, defaultAmount)
	// Then lock liquidity
	await upgradableRetirementYield.lockLiquidity(defaultAmount)
}