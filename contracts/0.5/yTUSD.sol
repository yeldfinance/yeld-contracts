pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "./ContractImports.sol";
import "./CommonFunctionality.sol";

contract yTUSD is
    ERC20,
    ERC20Detailed,
    ReentrancyGuard,
    Ownable,
    Structs,
    CommonFunctionality
{
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    uint256 public pool;
    address public token;
    address public compound;
    address public fulcrum;
    address public aave;
    address public aaveToken;
    address public dydx;
    uint256 public dToken;
    address public apr;

    // Yeld
    mapping(address => uint256) public depositBlockStarts;
    mapping(address => uint256) public depositAmount;
    address public uniswapRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public tusd = 0x0000000000085d4780B73119b644AE5ecd22b376;
    address public weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address payable public retirementYeldTreasury;
    IERC20 public yeldToken;
    uint256 public maximumTokensToBurn = 50000 * 1e18;
    uint256 public constant oneDayInBlocks = 6500;
    uint256 public yeldToRewardPerDay = 50e18; // 50 YELD per day per 1 million stablecoins padded with 18 zeroes to have that flexibility
    uint256 public constant oneMillion = 1e6;
    uint256 public holdPercentage = 15e18;
    address public devTreasury;
    // Yeld

    enum Lender {NONE, DYDX, COMPOUND, AAVE, FULCRUM}

    Lender public provider = Lender.NONE;

    constructor(address _yeldToken, address payable _retirementYeldTreasury, address _devTreasury)
        public
        ERC20Detailed("yearn TUSD", "yTUSD", 18)
    {
        token = address(0x0000000000085d4780B73119b644AE5ecd22b376);
        apr = address(0xdD6d648C991f7d47454354f4Ef326b04025a48A8);
        dydx = address(0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e);
        aave = address(0x24a42fD28C976A61Df5D00D0599C34c4f90748c8);
        fulcrum = address(0x49f4592E641820e928F9919Ef4aBd92a719B4b49);
        aaveToken = address(0x4DA9b813057D04BAef4e5800E36083717b4a0341);
        compound = address(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
        dToken = 0;
        yeldToken = IERC20(_yeldToken);
        retirementYeldTreasury = _retirementYeldTreasury;
        devTreasury = _devTreasury;
        approveToken();
    }

    // Yeld
    // To receive ETH after converting it from TUSD
    function() external payable {}

    function setRetirementYeldTreasury(address payable _treasury)
        public
        onlyOwner
    {
        retirementYeldTreasury = _treasury;
    }

    // In case a new uniswap router version is released
    function setUniswapRouter(address _uniswapRouter) public onlyOwner {
        uniswapRouter = _uniswapRouter;
    }

    function setYeldToken(address _yeldToken) public onlyOwner {
      yeldToken = IERC20(_yeldToken);
    }

    function setDevTreasury(address _devTreasury) public onlyOwner {
        devTreasury = _devTreasury;
    }

    function extractTokensIfStuck(address _token, uint256 _amount)
        public
        onlyOwner
    {
        IERC20(_token).transfer(msg.sender, _amount);
    }

    function extractETHIfStuck() public onlyOwner {
        owner().transfer(address(this).balance);
    }

    function changeYeldToRewardPerDay(uint256 _amount) public onlyOwner {
        yeldToRewardPerDay = _amount;
    }

    function getGeneratedYelds() public view returns (uint256) {
        uint256 blocksPassed;
        if (depositBlockStarts[msg.sender] > 0) {
            blocksPassed = block.number.sub(depositBlockStarts[msg.sender]);
        } else {
            return 0;
        }
        uint256 generatedYelds = depositAmount[msg.sender].div(oneMillion).mul(yeldToRewardPerDay).div(1e18).mul(blocksPassed).div(oneDayInBlocks);
        return generatedYelds;
    }

    function tusdToETH(uint256 _amount) internal returns (uint256) {
        IERC20(tusd).safeApprove(uniswapRouter, 0);
        IERC20(tusd).safeApprove(uniswapRouter, _amount);
        address[] memory path = new address[](2);
        path[0] = tusd;
        path[1] = weth;
        uint256[] memory amounts =
            IUniswap(uniswapRouter).swapExactTokensForETH(
                _amount,
                uint256(0),
                path,
                address(this),
                now.add(1800)
            );
        return amounts[1];
    }

    function buyNBurn(uint256 _ethToSwap) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = address(yeldToken);
        // Burns the tokens by taking them out of circulation, sending them to the 0x0 address
        uint256[] memory amounts =
            IUniswap(uniswapRouter).swapExactETHForTokens.value(_ethToSwap)(
                uint256(0),
                path,
                address(0),
                now.add(1800)
            );
        return amounts[1];
    }

    // Yeld
    function setHoldPercentage(uint256 _holdPercentage) public onlyOwner {
      holdPercentage = _holdPercentage;
    }

    function yeldHoldingRequirement(uint256 _amount) internal view {
        uint256 yeldHold = yeldToken.balanceOf(msg.sender);
        uint256 yeldPriceInDai = getYeldPriceInDai(address(yeldToken), weth, dai, uniswapRouter);
        uint256 amountPercentage = _amount.mul(holdPercentage).div(1e20);
        uint256 yeldRequirement = amountPercentage.div(yeldPriceInDai);
        require(yeldHold >= yeldRequirement, 'You must hold a % of your deposit in YELD tokens to be able to stake or withdraw');
    }

    // Quick swap low gas method for pool swaps
    function deposit(uint256 _amount) external nonReentrant noContract {
        require(_amount > 0, "deposit must be greater than 0");
        yeldHoldingRequirement(_amount);

        pool = _calcPoolValueInToken();

        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);

        // Yeld
        depositBlockStarts[msg.sender] = block.number;
        depositAmount[msg.sender] = depositAmount[msg.sender].add(_amount);
        // Yeld

        // Calculate pool shares
        uint256 shares = 0;
        if (pool == 0) {
            shares = _amount;
            pool = _amount;
        } else {
            shares = (_amount.mul(_totalSupply)).div(pool);
        }
        pool = _calcPoolValueInToken();
        _mint(msg.sender, shares);
        rebalance();
    }

    // No rebalance implementation for lower fees and faster swaps
    function withdraw(uint256 _shares) external nonReentrant noContract {
        require(_shares > 0, "withdraw must be greater than 0");
        uint256 ibalance = balanceOf(msg.sender);
        require(_shares <= ibalance, "insufficient balance");
        // Could have over value from cTokens
        pool = _calcPoolValueInToken();
        // Yeld
        uint256 generatedYelds = getGeneratedYelds();
        // Yeld
        // Calc to redeem before updating balances
        uint256 stablecoinsToWithdraw = (pool.mul(_shares)).div(_totalSupply);
        yeldHoldingRequirement(stablecoinsToWithdraw);
        _balances[msg.sender] = _balances[msg.sender].sub(
            _shares,
            "redeem amount exceeds balance"
        );
        _totalSupply = _totalSupply.sub(_shares);
        emit Transfer(msg.sender, address(0), _shares);
        // Check balance
        uint256 b = IERC20(token).balanceOf(address(this));
        if (b < stablecoinsToWithdraw) {
            _withdrawSome(stablecoinsToWithdraw.sub(b));
        }

        // Yeld
        uint256 totalPercentage = percentageRetirementYield.add(percentageDevTreasury).add(percentageBuyBurn);
        uint256 combined = stablecoinsToWithdraw.mul(totalPercentage).div(1e20);
        depositBlockStarts[msg.sender] = block.number;
        if (stablecoinsToWithdraw > depositAmount[msg.sender]) {
            depositAmount[msg.sender] = 0;
        } else {
            depositAmount[msg.sender] = depositAmount[msg.sender].sub(stablecoinsToWithdraw);
        }
        yeldToken.transfer(msg.sender, generatedYelds);
        // Take a portion of the profits for the buy and burn and retirement yeld
        // Convert half the TUSD earned into ETH for the protocol algorithms
        uint256 stakingProfits = tusdToETH(combined);
        uint256 tokensAlreadyBurned = yeldToken.balanceOf(address(0));
        uint256 devTreasuryAmount = stakingProfits.mul(uint256(100e18).mul(percentageDevTreasury).div(totalPercentage)).div(100e18);
        if (tokensAlreadyBurned < maximumTokensToBurn) {
            uint256 ethToSwap = stakingProfits.mul(uint256(100e18).mul(percentageBuyBurn).div(totalPercentage)).div(100e18);
            buyNBurn(ethToSwap);
            uint256 retirementYeld = stakingProfits.mul(uint256(100e18).mul(percentageRetirementYield).div(totalPercentage)).div(100e18);
            retirementYeldTreasury.transfer(retirementYeld);
        } else {
            // If we've reached the maximum burn point, send half the profits to the treasury to reward holders
            uint256 retirementYeld = stakingProfits.sub(devTreasuryAmount);
            // Send to the treasury
            retirementYeldTreasury.transfer(retirementYeld);
        }
        (bool success, ) = devTreasury.call.value(devTreasuryAmount)("");
        require(success, "Dev treasury transfer failed");
        IERC20(token).safeTransfer(msg.sender, stablecoinsToWithdraw.sub(combined));
        // Yeld

        pool = _calcPoolValueInToken();
        rebalance();
    }

    // Ownable setters incase of support in future for these systems
    function set_new_APR(address _new_APR) public onlyOwner {
        apr = _new_APR;
    }

    function set_new_COMPOUND(address _new_COMPOUND) public onlyOwner {
        compound = _new_COMPOUND;
    }

    function set_new_DTOKEN(uint256 _new_DTOKEN) public onlyOwner {
        dToken = _new_DTOKEN;
    }

    function recommend() public view returns (Lender) {
        (, uint256 capr, uint256 iapr, uint256 aapr, uint256 dapr) =
            IIEarnManager(apr).recommend(token);
        uint256 max = 0;
        if (capr > max) {
            max = capr;
        }
        if (iapr > max) {
            max = iapr;
        }
        if (aapr > max) {
            max = aapr;
        }
        if (dapr > max) {
            max = dapr;
        }

        Lender newProvider = Lender.NONE;
        if (max == capr) {
            newProvider = Lender.COMPOUND;
        } else if (max == iapr) {
            newProvider = Lender.FULCRUM;
        } else if (max == aapr) {
            newProvider = Lender.AAVE;
        } else if (max == dapr) {
            newProvider = Lender.DYDX;
        }
        return newProvider;
    }

    function supplyDydx(uint256 amount) public returns (uint256) {
        Info[] memory infos = new Info[](1);
        infos[0] = Info(address(this), 0);

        AssetAmount memory amt =
            AssetAmount(
                true,
                AssetDenomination.Wei,
                AssetReference.Delta,
                amount
            );
        ActionArgs memory act;
        act.actionType = ActionType.Deposit;
        act.accountId = 0;
        act.amount = amt;
        act.primaryMarketId = dToken;
        act.otherAddress = address(this);

        ActionArgs[] memory args = new ActionArgs[](1);
        args[0] = act;

        DyDx(dydx).operate(infos, args);
    }

    function _withdrawDydx(uint256 amount) internal {
        Info[] memory infos = new Info[](1);
        infos[0] = Info(address(this), 0);

        AssetAmount memory amt =
            AssetAmount(
                false,
                AssetDenomination.Wei,
                AssetReference.Delta,
                amount
            );
        ActionArgs memory act;
        act.actionType = ActionType.Withdraw;
        act.accountId = 0;
        act.amount = amt;
        act.primaryMarketId = dToken;
        act.otherAddress = address(this);

        ActionArgs[] memory args = new ActionArgs[](1);
        args[0] = act;

        DyDx(dydx).operate(infos, args);
    }

    function getAave() public view returns (address) {
        return LendingPoolAddressesProvider(aave).getLendingPool();
    }

    function getAaveCore() public view returns (address) {
        return LendingPoolAddressesProvider(aave).getLendingPoolCore();
    }

    function approveToken() public {
        IERC20(token).safeApprove(compound, uint256(-1)); //also add to constructor
        IERC20(token).safeApprove(dydx, uint256(-1));
        IERC20(token).safeApprove(getAaveCore(), uint256(-1));
        IERC20(token).safeApprove(fulcrum, uint256(-1));
    }

    function balance() public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function balanceDydx() public view returns (uint256) {
        Wei memory bal =
            DyDx(dydx).getAccountWei(Info(address(this), 0), dToken);
        return bal.value;
    }

    function balanceCompound() public view returns (uint256) {
        return IERC20(compound).balanceOf(address(this));
    }

    function balanceCompoundInToken() public view returns (uint256) {
        // Mantisa 1e18 to decimals
        uint256 b = balanceCompound();
        if (b > 0) {
            b = b.mul(Compound(compound).exchangeRateStored()).div(1e18);
        }
        return b;
    }

    function balanceFulcrumInToken() public view returns (uint256) {
        uint256 b = balanceFulcrum();
        if (b > 0) {
            b = Fulcrum(fulcrum).assetBalanceOf(address(this));
        }
        return b;
    }

    function balanceFulcrum() public view returns (uint256) {
        return IERC20(fulcrum).balanceOf(address(this));
    }

    function balanceAave() public view returns (uint256) {
        return IERC20(aaveToken).balanceOf(address(this));
    }

    function _balance() internal view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function _balanceDydx() internal view returns (uint256) {
        Wei memory bal =
            DyDx(dydx).getAccountWei(Info(address(this), 0), dToken);
        return bal.value;
    }

    function _balanceCompound() internal view returns (uint256) {
        return IERC20(compound).balanceOf(address(this));
    }

    function _balanceCompoundInToken() internal view returns (uint256) {
        // Mantisa 1e18 to decimals
        uint256 b = balanceCompound();
        if (b > 0) {
            b = b.mul(Compound(compound).exchangeRateStored()).div(1e18);
        }
        return b;
    }

    function _balanceFulcrumInToken() internal view returns (uint256) {
        uint256 b = balanceFulcrum();
        if (b > 0) {
            b = Fulcrum(fulcrum).assetBalanceOf(address(this));
        }
        return b;
    }

    function _balanceFulcrum() internal view returns (uint256) {
        return IERC20(fulcrum).balanceOf(address(this));
    }

    function _balanceAave() internal view returns (uint256) {
        return IERC20(aaveToken).balanceOf(address(this));
    }

    function _withdrawAll() internal {
        uint256 amount = _balanceCompound();
        if (amount > 0) {
            _withdrawCompound(amount);
        }
        amount = _balanceDydx();
        if (amount > 0) {
            _withdrawDydx(amount);
        }
        amount = _balanceFulcrum();
        if (amount > 0) {
            _withdrawFulcrum(amount);
        }
        amount = _balanceAave();
        if (amount > 0) {
            _withdrawAave(amount);
        }
    }

    function _withdrawSomeCompound(uint256 _amount) internal {
        uint256 b = balanceCompound();
        uint256 bT = balanceCompoundInToken();
        require(bT >= _amount, "insufficient funds");
        // can have unintentional rounding errors
        uint256 amount = (b.mul(_amount)).div(bT).add(1);
        _withdrawCompound(amount);
    }

    // 1999999614570950845
    function _withdrawSomeFulcrum(uint256 _amount) internal {
        // Balance of fulcrum tokens, 1 iDAI = 1.00x DAI
        uint256 b = balanceFulcrum(); // 1970469086655766652
        // Balance of token in fulcrum
        uint256 bT = balanceFulcrumInToken(); // 2000000803224344406
        require(bT >= _amount, "insufficient funds");
        // can have unintentional rounding errors
        uint256 amount = (b.mul(_amount)).div(bT).add(1);
        _withdrawFulcrum(amount);
    }

    function _withdrawSome(uint256 _amount) internal {
        if (provider == Lender.COMPOUND) {
            _withdrawSomeCompound(_amount);
        }
        if (provider == Lender.AAVE) {
            require(balanceAave() >= _amount, "insufficient funds");
            _withdrawAave(_amount);
        }
        if (provider == Lender.DYDX) {
            require(balanceDydx() >= _amount, "insufficient funds");
            _withdrawDydx(_amount);
        }
        if (provider == Lender.FULCRUM) {
            _withdrawSomeFulcrum(_amount);
        }
    }

    function rebalance() public {
        Lender newProvider = recommend();

        if (newProvider != provider) {
            _withdrawAll();
        }

        if (balance() > 0) {
            if (newProvider == Lender.DYDX) {
                supplyDydx(balance());
            } else if (newProvider == Lender.FULCRUM) {
                supplyFulcrum(balance());
            } else if (newProvider == Lender.COMPOUND) {
                supplyCompound(balance());
            } else if (newProvider == Lender.AAVE) {
                supplyAave(balance());
            }
        }

        provider = newProvider;
    }

    // Internal only rebalance for better gas in redeem
    function _rebalance(Lender newProvider) internal {
        if (_balance() > 0) {
            if (newProvider == Lender.DYDX) {
                supplyDydx(_balance());
            } else if (newProvider == Lender.FULCRUM) {
                supplyFulcrum(_balance());
            } else if (newProvider == Lender.COMPOUND) {
                supplyCompound(_balance());
            } else if (newProvider == Lender.AAVE) {
                supplyAave(_balance());
            }
        }
        provider = newProvider;
    }

    function supplyAave(uint256 amount) public {
        Aave(getAave()).deposit(token, amount, 0);
    }

    function supplyFulcrum(uint256 amount) public {
        require(
            Fulcrum(fulcrum).mint(address(this), amount) > 0,
            "FULCRUM: supply failed"
        );
    }

    function supplyCompound(uint256 amount) public {
        require(
            Compound(compound).mint(amount) == 0,
            "COMPOUND: supply failed"
        );
    }

    function _withdrawAave(uint256 amount) internal {
        AToken(aaveToken).redeem(amount);
    }

    function _withdrawFulcrum(uint256 amount) internal {
        require(
            Fulcrum(fulcrum).burn(address(this), amount) > 0,
            "FULCRUM: withdraw failed"
        );
    }

    function _withdrawCompound(uint256 amount) internal {
        require(
            Compound(compound).redeem(amount) == 0,
            "COMPOUND: withdraw failed"
        );
    }

    function _calcPoolValueInToken() internal view returns (uint256) {
        return
            _balanceCompoundInToken()
                .add(_balanceFulcrumInToken())
                .add(_balanceDydx())
                .add(_balanceAave())
                .add(_balance());
    }

    function calcPoolValueInToken() public view returns (uint256) {
        return
            balanceCompoundInToken()
                .add(balanceFulcrumInToken())
                .add(balanceDydx())
                .add(balanceAave())
                .add(balance());
    }

    function getPricePerFullShare() public view returns (uint256) {
        uint256 _pool = calcPoolValueInToken();
        return _pool.mul(1e18).div(_totalSupply);
    }
}
