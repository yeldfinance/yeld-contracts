require("regenerator-runtime/runtime");

const { deployProxy } = require('@openzeppelin/truffle-upgrades')
const Example = artifacts.require('Example')
const Examplev2 = artifacts.require('Examplev2')

module.exports = async function(deployer, network, accounts) {
  const instance = await deployProxy(Example, [14], { deployer })
  console.log('Deployed', instance.address)
}





// const { deployProxy } = require('@openzeppelin/truffle-upgrades');

// const Box = artifacts.require('Box');

// module.exports = async function (deployer) {
//   const instance = await deployProxy(Box, [42], { deployer });
//   console.log('Deployed', instance.address);
// };