pragma solidity 0.5.17;

contract Example {
  uint256 public myNumber;

  function initialize(uint256 _num) public {
    myNumber = _num;
  }

  function setNumber(uint256 _num) public {
    myNumber = _num;
  }
}