pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import './ContractImports.sol';

/// @notice To block contracts from interacting with the designated functions
contract CommonFunctionality {
  function isContract(address account) internal view returns (bool) {
    // This method relies on extcodesize, which returns 0 for contracts in
    // construction, since the code is only stored at the end of the
    // constructor execution.

    uint256 size;
    // solhint-disable-next-line no-inline-assembly
    assembly { size := extcodesize(account) }
    return size > 0;
  }

  modifier noContract() {
      require(isContract(msg.sender) == false, 'Contracts are not allowed to interact with the farm');
      _;
  }

  function getYeldPriceInDai(address _yeld, address _weth, address _dai, address _uniswap) public view returns(uint256) {
    address[] memory path = new address[](3);
    path[0] = _yeld;
    path[1] = _weth;
    path[2] = _dai;
    uint256[] memory amounts = IUniswap(_uniswap).getAmountsOut(1e18, path);
    return amounts[2];
  }
}