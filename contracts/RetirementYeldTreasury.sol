pragma solidity 0.5.17;

contract Ownable is Context {
    address payable private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor () internal {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }
    function owner() public view returns (address payable) {
        return _owner;
    }
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    function transferOwnership(address payable newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address payable newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

/// @notice The contract that holds the retirement yeld funds and distributes them
contract RetirementYeldTreasury is Ownable {
  using SafeMath for uint256;
  IERC20 yeld;
  uint256 public timeBetweenRedeems = 1 days;

  struct Snapshot {
    uint256 timestamp;
    uint256 yeldBalance;
  }

  mapping(address => Snapshot) public snapshots;

  // Fallback function to receive payments
  function () external payable {}

  // To set the YELD contract address
  constructor (address _yeld) public {
    yeld = IERC20(_yeld);
  }

  function addETH() public payable {}

  function takeSnapshot() public {
    snapshots[msg.sender] = Snapshot(now, yeld.balanceOf(msg.sender));
  }

  /// Checks how much YELD the user currently has and sends him some eth based on that
  function redeemETH() public {
    require(now >= snapshots[msg.sender].timestamp + timeBetweenRedeems, 'You must wait at least a day after the snapshot to redeem your earnings');
    require(yeld.balanceOf(msg.sender) >= snapshots[msg.sender].yeldBalance, 'Your balance must be equal or higher the snapshoted balance');
    // Calculate his holdings % in 1 per 10^18% instead of 1 per 100%
    uint256 burnedTokens = yeld.balanceOf(address(0));
    uint256 userPercentage = yeld.balanceOf(msg.sender).mul(1e18).div(yeld.totalSupply().sub(burnedTokens));
    uint256 earnings = address(this).balance.mul(userPercentage).div(1e16);
    snapshots[msg.sender] = Snapshot(now, yeld.balanceOf(msg.sender));
    msg.sender.transfer(earnings);
  }

  function setYeld(address _yeld) public onlyOwner {
    yeld = IERC20(_yeld);
  }

  function extractTokensIfStuck(address _token, uint256 _amount) public onlyOwner {
    IERC20(_token).transfer(msg.sender, _amount);
  }
}