pragma solidity 0.5.0;

contract YeldFunctions {

  // YELD
  uint256 rewardPerBlock = 0.015; // How much YELD is distributed every block, roughtly 100 YELD a day
  uint256 lastBlockIncreasedPrice = block.number + 6500 * 3; // The first 3 days blocks have a 10x times reward
  uint256 initialBlock = block.number; // Used to count how many blocks have passed
  uint256 yeldRedeemed = 0; // When users withdraw, this gets updated
  uint256 public totalDeposited = 0;
  address public yeldTokenAddress;
  uint256 public totalYeldRedeemed;
  mapping (address => uint256) public deposited; // How much DAI has been deposited by a specific address
  mapping (address => uint256) public blockStartedStaking; // When the user has started staking

  // In a separate function to allow the frontend to check the rewards
  function calculateYeldReward() public view returns(uint256) {
    // !!Potential issue here we gotta count the blocks since the user started staking
    // Otherwise a whale could come anytime, get a 90% of the staking power and extract all the earnings
    uint256 blocksPassed = block.number - blockStartedStaking[msg.sender];
    uint256 myRewardPerBlock = rewardPerBlock;
    
    // To reward users even if they started staking with increased rewards
    if (blockStartedStaking[msg.sender] < lastBlockIncreasedPrice && block.number > lastBlockIncreasedPrice) {
      uint256 blocksWithIncreasedReward = lastBlockIncreasedPrice - blockStartedStaking[msg.sender];
      uint256 regularBlocks = block.number - lastBlockIncreasedPrice;
      myRewardPerBlock = (myRewardPerBlock.mul(10).mul(blocksWithIncreasedReward)).add(myRewardPerBlock.mul(regularBlocks));
    } else if (block.number <= lastBlockIncreasedPrice) {
      myRewardPerBlock = myRewardPerBlock.mul(10).mul(blocksPassed);
    } else {
      myRewardPerBlock = myRewardPerBlock.mul(blocksPassed);
    }

    // We can't have a division with a smaller than 0 number with decimals gotta implement some library 
    // since deposited[msg.sender] will almost always be smaller than totalDeposited

    uint256 yeldReward = myRewardPerBlock * (deposited[msg.sender] / totalDeposited) - yeldRedeemed;
  }

//   To withdraw all them tokens
//   This contract must hold the YELD tokens to be able to execute this
  function withdrawYeld() public {
    uint256 yeldReward = calculateYeldReward();
    if (yeldReward == 0) return;
    
    IERC20(yeldTokenAddress).transfer(msg.sender, yeldReward);
    
    yeldRedeemed = yeldRedeemed.add(yeldReward);
    totalDeposited = totalDeposited.sub(deposited[msg.sender]);
    deposited[msg.sender] = 0;
    blockStartedStaking[msg.sender] = 0;
  }
}