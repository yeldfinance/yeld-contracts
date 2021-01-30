pragma solidity =0.6.2;

import '@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol';

abstract contract IFreeFromUpTo is IERC20 {
    function freeFromUpTo(address from, uint256 value) external virtual returns(uint256 freed);
}

/// @notice This contract allows you to lock liquidity LP tokens and receive earnings
/// It also allows you to extract those earnings
contract UpgradableRetirementYield is Initializable, OwnableUpgradeSafe {
    using SafeMath for uint256;

    // How many LP tokens each user has
    mapping (address => uint256) public amountLocked;
    // The price when you extracted your earnings so we can whether you got new earnings or not
    mapping (address => uint256) public lastPriceEarningsExtracted;
    // When the user started locking his LP tokens
    mapping (address => uint256) public lockingTime;
    // The uniswap LP token contract
    address public yeld;
    // How many LP tokens are locked
    uint256 public totalLiquidityLocked;
    // The total YELDFee generated
    uint256 public totalYeldFeeMined;
    uint256 public yeldFeePrice;
    uint256 public accomulatedRewards;
    uint256 public pricePadding;
    uint256 public timeToExitLiquidity;
    address public chi; // The gastoken
    address payable public devTreasury;
    uint256 public devTreasuryPercentage;

    modifier discountCHI {
        uint256 gasStart = gasleft();
        _;
        uint256 gasSpent = 21000 + gasStart - gasleft() + 16 * msg.data.length;
        IFreeFromUpTo(chi).freeFromUpTo(msg.sender, (gasSpent + 14154) / 41947);
    }
    
    // increase the yeldFeePrice
    receive() external payable {
        addFeeAndUpdatePrice(msg.value);
    }

    function initialize(address _yeld, address payable _devTreasury) public initializer {
        __Ownable_init();
        yeld = _yeld;
        pricePadding = 1e18;
        timeToExitLiquidity = 365 days;
        chi = 0x0000000000004946c0e9F43F4Dee607b0eF1fA1c;
        devTreasury = _devTreasury;
        devTreasuryPercentage = 50e18; // 50% padded 1e18
    }

    function setYeld(address _yeld) public onlyOwner {
        yeld = _yeld;
    }

    function setTimeToExitLiquidity(uint256 _time) public onlyOwner {
        timeToExitLiquidity = _time;
    }

    /// @notice When ETH is added, the price is increased
    /// Price is = (feeIn / totalYELDFeeDistributed) + currentPrice
    /// padded with 18 zeroes that get removed after the calculations
    /// if there are no locked LPs, the price is 0
    function addFeeAndUpdatePrice(uint256 _feeIn) internal {
        accomulatedRewards = accomulatedRewards.add(_feeIn);
        if (totalLiquidityLocked == 0) {
            yeldFeePrice = 0;
        } else {
            yeldFeePrice = (_feeIn.mul(pricePadding).div(totalLiquidityLocked)).add(yeldFeePrice);
        }
    }

    function lockLiquidity(uint256 _amount) public {
        require(_amount > 0, 'UpgradableRetirementYield: Amount must be larger than zero');
        // Transfer UNI-LP-V2 tokens inside here forever while earning fees from every transfer, LP tokens can't be extracted
        uint256 approval = IERC20(yeld).allowance(msg.sender, address(this));
        require(approval >= _amount, 'UpgradableRetirementYield: You must approve the desired amount of YELD tokens to this contract first');
        IERC20(yeld).transferFrom(msg.sender, address(this), _amount);
        totalLiquidityLocked = totalLiquidityLocked.add(_amount);
        // Extract earnings in case the user is not a new Locked LP
        if (lastPriceEarningsExtracted[msg.sender] != 0 && lastPriceEarningsExtracted[msg.sender] != yeldFeePrice) {
            extractEarnings();
        }
        // Set the initial price
        if (yeldFeePrice == 0) {
            yeldFeePrice = accomulatedRewards.mul(pricePadding).div(_amount).add(1e18);
            lastPriceEarningsExtracted[msg.sender] = 1e18;
        } else {
            lastPriceEarningsExtracted[msg.sender] = yeldFeePrice;
        }
        // The price doesn't change when locking liquidity. It changes when fees are generated from transfers
        amountLocked[msg.sender] = amountLocked[msg.sender].add(_amount);
        // Notice that the locking time is reset when new liquidity is added
        lockingTime[msg.sender] = now;
    }

    // We check for new earnings by seeing if the price the user last extracted his earnings
    // is the same or not to determine whether he can extract new earnings or not
    function extractEarnings() public {
        require(amountLocked[msg.sender] > 0, 'UpgradableRetirementYield: You must have locked liquidity provider tokens to extract your earnings');
        require(yeldFeePrice != lastPriceEarningsExtracted[msg.sender], 'UpgradableRetirementYield: You have already extracted your earnings');
        // The amountLocked price minus the last price extracted
        uint256 myPrice = yeldFeePrice.sub(lastPriceEarningsExtracted[msg.sender]);
        uint256 earnings = amountLocked[msg.sender].mul(myPrice).div(pricePadding);
        lastPriceEarningsExtracted[msg.sender] = yeldFeePrice;
        accomulatedRewards = accomulatedRewards.sub(earnings);
        uint256 devTreasuryEarnings = earnings.mul(devTreasuryPercentage).div(1e20);
        uint256 remaining = earnings.sub(devTreasuryEarnings);

        // Transfer the ETH earnings
        devTreasury.transfer(devTreasuryEarnings);
        msg.sender.transfer(remaining);
    }

    // The user must lock the liquidity for 1 year and only then can extract his Locked LP tokens
    // he must extract all the LPs for simplicity and security purposes
    function extractLiquidity() public {
        require(amountLocked[msg.sender] > 0, 'UpgradableRetirementYield: You must have locked liquidity provider tokens to extract them');
        require(now - lockingTime[msg.sender] >= timeToExitLiquidity, 'UpgradableRetirementYield: You must wait the specified locking time to extract your liquidity provider tokens');
        // Extract earnings in case there are some
        if (lastPriceEarningsExtracted[msg.sender] != 0 && lastPriceEarningsExtracted[msg.sender] != yeldFeePrice) {
            extractEarnings();
        }
        uint256 locked = amountLocked[msg.sender];
        amountLocked[msg.sender] = 0;
        lockingTime[msg.sender] = now;
        lastPriceEarningsExtracted[msg.sender] = 0;
        totalLiquidityLocked = totalLiquidityLocked.sub(locked);
        IERC20(yeld).transfer(msg.sender, locked);
    }

    function getAmountLocked(address _user) public view returns (uint256) {
        return amountLocked[_user];
    }

    function extractTokensIfStuck(address _token, uint256 _amount) public onlyOwner {
        IERC20(_token).transfer(owner(), _amount);
    }

    function extractETHIfStruck() public onlyOwner {
        payable(address(owner())).transfer(address(this).balance);
    }
}