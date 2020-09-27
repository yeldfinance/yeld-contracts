pragma solidity =0.5.17;

import './ERC1155Tradable.sol';

/**
 * @title Yeldies By YELD Finance
 * Rinkeby:
 * proxyRegistryAddress = "0xf57b2c51ded3a29e6891aba85459d600256cf317";
 * 
 * Mainnet:
 * proxyRegistryAddress = "0xa5409ec958c83c3f309868babaca7c86dcb077c1";
 */
contract Yeldies is ERC1155Tradable {
	constructor(address _proxyRegistryAddress) public ERC1155Tradable("Yeldies", "YLDS", _proxyRegistryAddress) {
		_setBaseMetadataURI("https://api.yeld.finance/items/");
	}

	function contractURI() public view returns (string memory) {
		return "https://api.yeld.finance/contract/erc1155";
	}
}