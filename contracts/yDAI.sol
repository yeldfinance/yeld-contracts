pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import './ContractImports.sol';
import './CommonFunctionality.sol';

contract yDAI is ERC20, ERC20Detailed, ReentrancyGuard, Structs, Ownable, CommonFunctionality {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  uint256 public pool;
  address public token;
  address public compound;
  address public fulcrum;
  address public aave;
  address public aavePool;
  address public aaveToken;
  address public dydx;
  uint256 public dToken;
  address public apr;
  address public chai;
  // Add other tokens if implemented for another stablecoin
  address public uniswapRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  address public dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
  address public weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address payable public retirementYeldTreasury;
  IERC20 public yeldToken;
  uint256 public maximumTokensToBurn = 50000 * 1e18;

  mapping(address => uint256) public depositBlockStarts;
  mapping(address => uint256) public depositAmount;
  uint256 public constant oneDayInBlocks = 6500;
  uint256 public yeldToRewardPerDay = 50e18; // 50 YELD per day per 1 million stablecoins padded with 18 zeroes to have that flexibility
  uint256 public constant oneMillion = 1e6;
  uint256 public holdPercentage = 15e18;
  address public devTreasury;

  enum Lender {
      NONE,
      DYDX,
      COMPOUND,
      AAVE,
      FULCRUM
  }

  Lender public provider = Lender.NONE;

  constructor (address _yeldToken, address payable _retirementYeldTreasury, address _devTreasury) public payable ERC20Detailed("yearn DAI", "yDAI", 18) {
    token = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    apr = address(0xdD6d648C991f7d47454354f4Ef326b04025a48A8);
    dydx = address(0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e);
    aave = address(0x24a42fD28C976A61Df5D00D0599C34c4f90748c8);
    aavePool = address(0x3dfd23A6c5E8BbcFc9581d2E864a68feb6a076d3);
    fulcrum = address(0x493C57C4763932315A328269E1ADaD09653B9081);
    aaveToken = address(0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d);
    compound = address(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
    chai = address(0x06AF07097C9Eeb7fD685c692751D5C66dB49c215);
    dToken = 3;
    yeldToken = IERC20(_yeldToken);
    retirementYeldTreasury = _retirementYeldTreasury;
    devTreasury = _devTreasury;
    approveToken();
  }

  // To receive ETH after converting it from DAI
  function () external payable {}

  function setRetirementYeldTreasury(address payable _treasury) public onlyOwner {
    retirementYeldTreasury = _treasury;
  }

  // In case a new uniswap router version is released
  function setUniswapRouter(address _uniswapRouter) public onlyOwner {
    uniswapRouter = _uniswapRouter;
  }

  function setYeldToken(address _yeldToken) public onlyOwner {
    yeldToken = IERC20(_yeldToken);
  }

  function extractTokensIfStuck(address _token, uint256 _amount) public onlyOwner {
    IERC20(_token).transfer(msg.sender, _amount);
  }

  function extractETHIfStuck() public onlyOwner {
    owner().transfer(address(this).balance);
  }

  function changeYeldToRewardPerDay(uint256 _amount) public onlyOwner {
    yeldToRewardPerDay = _amount;
  }

  function getGeneratedYelds() public view returns(uint256) {
    uint256 blocksPassed;
    if (depositBlockStarts[msg.sender] > 0) {
      blocksPassed = block.number.sub(depositBlockStarts[msg.sender]);
    } else {
      return 0;
    }
    uint256 generatedYelds = depositAmount[msg.sender].div(oneMillion).mul(yeldToRewardPerDay).div(1e18).mul(blocksPassed).div(oneDayInBlocks);
    return generatedYelds;
  }

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

  function deposit(uint256 _amount)
      external
      nonReentrant
      noContract
  {
    require(_amount > 0, "deposit must be greater than 0");
    yeldHoldingRequirement(_amount);
    pool = calcPoolValueInToken();
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
    pool = calcPoolValueInToken();
    _mint(msg.sender, shares);
    rebalance();
  }

  // Converts DAI to ETH and returns how much ETH has been received from Uniswap
  function daiToETH(uint256 _amount) internal returns(uint256) {
      IERC20(dai).safeApprove(uniswapRouter, 0);
      IERC20(dai).safeApprove(uniswapRouter, _amount);
      address[] memory path = new address[](2);
      path[0] = dai;
      path[1] = weth;
      // swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
      // 'amounts' is an array where [0] is input DAI amount and [1] is the resulting ETH after the conversion
      // even tho we've specified the WETH address, we'll receive ETH since that's how it works on uniswap
      // https://uniswap.org/docs/v2/smart-contracts/router02/#swapexacttokensforeth
      uint[] memory amounts = IUniswap(uniswapRouter).swapExactTokensForETH(_amount, uint(0), path, address(this), now.add(1800));
      return amounts[1];
  }

  // Buys YELD tokens paying in ETH on Uniswap and removes them from circulation
  // Returns how many YELD tokens have been burned
  function buyNBurn(uint256 _ethToSwap) internal returns(uint256) {
    address[] memory path = new address[](2);
    path[0] = weth;
    path[1] = address(yeldToken);
    // Burns the tokens by taking them out of circulation, sending them to the 0x0 address
    uint[] memory amounts = IUniswap(uniswapRouter).swapExactETHForTokens.value(_ethToSwap)(uint(0), path, address(0), now.add(1800));
    return amounts[1];
  }

  // No rebalance implementation for lower fees and faster swaps
  function withdraw(uint256 _shares)
      external
      nonReentrant
      noContract
  {
      require(_shares > 0, "withdraw must be greater than 0");
      uint256 ibalance = balanceOf(msg.sender);
      require(_shares <= ibalance, "insufficient balance");
      pool = calcPoolValueInToken();
      // Yeld
      uint256 generatedYelds = getGeneratedYelds();
      // Yeld
      uint256 stablecoinsToWithdraw = (pool.mul(_shares)).div(_totalSupply);
      yeldHoldingRequirement(stablecoinsToWithdraw);
      _balances[msg.sender] = _balances[msg.sender].sub(_shares, "redeem amount exceeds balance");
      _totalSupply = _totalSupply.sub(_shares, '#1 Total supply sub error');
      emit Transfer(msg.sender, address(0), _shares);
      uint256 b = IERC20(token).balanceOf(address(this));
      if (b < stablecoinsToWithdraw) {
        _withdrawSome(stablecoinsToWithdraw.sub(b, '#2 Withdraw some sub error'));
      }

      // Yeld
      uint256 totalPercentage = percentageRetirementYield.add(percentageDevTreasury).add(percentageBuyBurn);
      uint256 combined = stablecoinsToWithdraw.mul(totalPercentage).div(1e20);
      depositBlockStarts[msg.sender] = block.number;
      depositAmount[msg.sender] = depositAmount[msg.sender].sub(stablecoinsToWithdraw);
      yeldToken.transfer(msg.sender, generatedYelds);

      // Take a portion of the profits for the buy and burn and retirement yeld
      // Convert half the DAI earned into ETH for the protocol algorithms
      uint256 stakingProfits = daiToETH(combined); // 5%
      uint256 tokensAlreadyBurned = yeldToken.balanceOf(address(0));
      uint256 devTreasuryAmount = stakingProfits.mul(uint256(100e18).mul(percentageDevTreasury).div(totalPercentage)).div(100e18);
      if (tokensAlreadyBurned < maximumTokensToBurn) {
        // buynburn 5% -> 100% so 1% -> 20%
        uint256 ethToSwap = stakingProfits.mul(uint256(100e18).mul(percentageBuyBurn).div(totalPercentage)).div(100e18);
        // Buy and burn only applies up to 50k tokens burned
        buyNBurn(ethToSwap);
        // RY 1.5% where 5% -> 100% so 1.5% -> 30%
        uint256 retirementYeld = stakingProfits.mul(uint256(100e18).mul(percentageRetirementYield).div(totalPercentage)).div(100e18);
        // Send to the treasury
        retirementYeldTreasury.transfer(retirementYeld);
      } else {
        // If we've reached the maximum burn point, send half the profits to the treasury to reward holders
        uint256 retirementYeld = stakingProfits.sub(devTreasuryAmount);
        // Send to the treasury
        retirementYeldTreasury.transfer(retirementYeld);
      }
      // DT 2.5% where 5% -> 100% so 2.5% -> 50%
      (bool success, ) = devTreasury.call.value(devTreasuryAmount)("");
      require(success, "Dev treasury transfer failed");
      IERC20(token).safeTransfer(msg.sender, stablecoinsToWithdraw.sub(combined));
      // Yeld

      pool = calcPoolValueInToken();
      rebalance();
  }

  function recommend() public view returns (Lender) {
    (,uint256 capr,uint256 iapr,uint256 aapr,uint256 dapr) = IIEarnManager(apr).recommend(token);
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

  function getAave() public view returns (address) {
    return LendingPoolAddressesProvider(aave).getLendingPool();
  }
  function getAaveCore() public view returns (address) {
    return LendingPoolAddressesProvider(aave).getLendingPoolCore();
  }

  function approveToken() public {
      IERC20(token).safeApprove(compound, uint(-1));
      IERC20(token).safeApprove(dydx, uint(-1));
      IERC20(token).safeApprove(getAaveCore(), uint(-1));
      IERC20(token).safeApprove(fulcrum, uint(-1));
  }

  function balance() public view returns (uint256) {
    return IERC20(token).balanceOf(address(this));
  }
  function balanceDydxAvailable() public view returns (uint256) {
      return IERC20(token).balanceOf(dydx);
  }
  function balanceDydx() public view returns (uint256) {
      Wei memory bal = DyDx(dydx).getAccountWei(Info(address(this), 0), dToken);
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
  function balanceFulcrumAvailable() public view returns (uint256) {
      return IERC20(chai).balanceOf(fulcrum);
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
  function balanceAaveAvailable() public view returns (uint256) {
      return IERC20(token).balanceOf(aavePool);
  }
  function balanceAave() public view returns (uint256) {
    return IERC20(aaveToken).balanceOf(address(this));
  }

  function rebalance() public {
    Lender newProvider = recommend();

    if (newProvider != provider) {
      _withdrawAll();
    }

    if (balance() > 0) {
      if (newProvider == Lender.DYDX) {
        _supplyDydx(balance());
      } else if (newProvider == Lender.FULCRUM) {
        _supplyFulcrum(balance());
      } else if (newProvider == Lender.COMPOUND) {
        _supplyCompound(balance());
      } else if (newProvider == Lender.AAVE) {
        _supplyAave(balance());
      }
    }

    provider = newProvider;
  }

  function _withdrawAll() internal {
    uint256 amount = balanceCompound();
    if (amount > 0) {
      _withdrawSomeCompound(balanceCompoundInToken().sub(1));
    }
    amount = balanceDydx();
    if (amount > 0) {
      if (amount > balanceDydxAvailable()) {
        amount = balanceDydxAvailable();
      }
      _withdrawDydx(amount);
    }
    amount = balanceFulcrum();
    if (amount > 0) {
      if (amount > balanceFulcrumAvailable().sub(1)) {
        amount = balanceFulcrumAvailable().sub(1);
      }
      _withdrawSomeFulcrum(amount);
    }
    amount = balanceAave();
    if (amount > 0) {
      if (amount > balanceAaveAvailable()) {
        amount = balanceAaveAvailable();
      }
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

  function _withdrawSomeFulcrum(uint256 _amount) internal {
    uint256 b = balanceFulcrum();
    uint256 bT = balanceFulcrumInToken();
    require(bT >= _amount, "insufficient funds");
    // can have unintentional rounding errors
    uint256 amount = (b.mul(_amount)).div(bT).add(1);
    _withdrawFulcrum(amount);
  }


  function _withdrawSome(uint256 _amount) internal returns (bool) {
    uint256 origAmount = _amount;

    uint256 amount = balanceCompound();
    if (amount > 0) {
      if (_amount > balanceCompoundInToken().sub(1)) {
        _withdrawSomeCompound(balanceCompoundInToken().sub(1));
        _amount = origAmount.sub(IERC20(token).balanceOf(address(this)));
      } else {
        _withdrawSomeCompound(_amount);
        return true;
      }
    }

    amount = balanceDydx();
    if (amount > 0) {
      if (_amount > balanceDydxAvailable()) {
        _withdrawDydx(balanceDydxAvailable());
        _amount = origAmount.sub(IERC20(token).balanceOf(address(this)));
      } else {
        _withdrawDydx(_amount);
        return true;
      }
    }

    amount = balanceFulcrum();
    if (amount > 0) {
      if (_amount > balanceFulcrumAvailable().sub(1)) {
        amount = balanceFulcrumAvailable().sub(1);
        _withdrawSomeFulcrum(balanceFulcrumAvailable().sub(1));
        _amount = origAmount.sub(IERC20(token).balanceOf(address(this)));
      } else {
        _withdrawSomeFulcrum(amount);
        return true;
      }
    }

    amount = balanceAave();
    if (amount > 0) {
      if (_amount > balanceAaveAvailable()) {
        _withdrawAave(balanceAaveAvailable());
        _amount = origAmount.sub(IERC20(token).balanceOf(address(this)));
      } else {
        _withdrawAave(_amount);
        return true;
      }
    }

    return true;
  }

  function _supplyDydx(uint256 amount) internal {
      Info[] memory infos = new Info[](1);
      infos[0] = Info(address(this), 0);

      AssetAmount memory amt = AssetAmount(true, AssetDenomination.Wei, AssetReference.Delta, amount);
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

  function _supplyAave(uint amount) internal {
      Aave(getAave()).deposit(token, amount, 0);
  }
  function _supplyFulcrum(uint amount) internal {
      require(Fulcrum(fulcrum).mint(address(this), amount) > 0, "FULCRUM: supply failed");
  }
  function _supplyCompound(uint amount) internal {
      require(Compound(compound).mint(amount) == 0, "COMPOUND: supply failed");
  }
  function _withdrawAave(uint amount) internal {
      AToken(aaveToken).redeem(amount);
  }
  function _withdrawFulcrum(uint amount) internal {
      require(Fulcrum(fulcrum).burn(address(this), amount) > 0, "FULCRUM: withdraw failed");
  }
  function _withdrawCompound(uint amount) internal {
      require(Compound(compound).redeem(amount) == 0, "COMPOUND: withdraw failed");
  }

  function _withdrawDydx(uint256 amount) internal {
      Info[] memory infos = new Info[](1);
      infos[0] = Info(address(this), 0);

      AssetAmount memory amt = AssetAmount(false, AssetDenomination.Wei, AssetReference.Delta, amount);
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

  function calcPoolValueInToken() public view returns (uint) {
    return balanceCompoundInToken()
      .add(balanceFulcrumInToken())
      .add(balanceDydx())
      .add(balanceAave())
      .add(balance());
  }

  function getPricePerFullShare() public view returns (uint) {
    uint _pool = calcPoolValueInToken();
    return _pool.mul(1e18).div(_totalSupply);
  }
}
