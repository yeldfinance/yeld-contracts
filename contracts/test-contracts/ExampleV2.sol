pragma solidity 0.5.17;

contract ExampleV2 {
  uint256 public myNumber;
  string public myText;

  function initialize(uint256 _num) public {
    myNumber = _num;
  }
  
  function setNumber(uint256 _num) public {
    myNumber = _num;
  }

  function setText(string memory _text) public {
    myText = _text;
  }
}