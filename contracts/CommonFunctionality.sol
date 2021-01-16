pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

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
}