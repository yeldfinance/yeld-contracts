pragma solidity 0.5.17;

interface IYeldDAI {
  function yDAIAddress() external view returns(address);
  function initialPrice() external view returns(uint256);
  function fromYeldDAIToYeld() external view returns(uint256);
  function fromDAIToYeldDAIPrice() external view returns(uint256);
  function yeldReward() external view returns(uint256);
  function yeldDAIDecimals() external view returns(uint256);
  function mint(address _to, uint256 _amount) external;
  function burn(address _to, uint256 _amount) external;
  function balanceOf(address _of) external view returns(uint256);
	function checkIfPriceNeedsUpdating() external view returns(bool);
	function updatePrice() external;
}

interface IYeldTUSD {
  function yTUSDAddress() external view returns(address);
  function initialPrice() external view returns(uint256);
  function fromYeldTUSDToYeld() external view returns(uint256);
  function fromTUSDToYeldTUSDPrice() external view returns(uint256);
  function yeldReward() external view returns(uint256);
  function yeldTUSDDecimals() external view returns(uint256);
  function mint(address _to, uint256 _amount) external;
  function burn(address _to, uint256 _amount) external;
  function balanceOf(address _of) external view returns(uint256);
	function checkIfPriceNeedsUpdating() external view returns(bool);
	function updatePrice() external;
}

interface IYeldUSDT {
  function yUSDTAddress() external view returns(address);
  function initialPrice() external view returns(uint256);
  function fromYeldUSDTToYeld() external view returns(uint256);
  function fromUSDTToYeldUSDTPrice() external view returns(uint256);
  function yeldReward() external view returns(uint256);
  function yeldUSDTDecimals() external view returns(uint256);
  function mint(address _to, uint256 _amount) external;
  function burn(address _to, uint256 _amount) external;
  function balanceOf(address _of) external view returns(uint256);
	function checkIfPriceNeedsUpdating() external view returns(bool);
	function updatePrice() external;
}

interface IYeldUSDC {
  function yUSDCAddress() external view returns(address);
  function initialPrice() external view returns(uint256);
  function fromYeldUSDCToYeld() external view returns(uint256);
  function fromUSDCToYeldUSDCPrice() external view returns(uint256);
  function yeldReward() external view returns(uint256);
  function yeldUSDCDecimals() external view returns(uint256);
  function mint(address _to, uint256 _amount) external;
  function burn(address _to, uint256 _amount) external;
  function balanceOf(address _of) external view returns(uint256);
	function checkIfPriceNeedsUpdating() external view returns(bool);
	function updatePrice() external;
}