pragma solidity =0.5.17;

import './Yeldies.sol';

contract YeldNFT {
    using SafeMath for uint256;

    struct Deposit {
        uint256 amount;
        uint256 start; // Block when it started
    }

    mapping(address => Deposit) public deposits;
    address public yeld;
    address public yeldies;
    uint256 public constant oneDayInBlocks = 6500;
    
    /// The contract will receive the Yeldies YLDS ERC20 token to distribute
    constructor (address _yeld, address _yeldies) public {
        yeld = _yeld;
        yeldies = _yeldies;
    }
    
    /// When someone deposits again, we check if there's a withdrawal first and extract it before depositing again
    function deposit(uint256 _amount) public {
        if (getGeneratedYeldies() > 0) {
            extractEarningsWhileKeepingDeposit();
        }
        IERC20(yeld).transferFrom(msg.sender, address(this), _amount);
        // TransferFrom user to here. User must approve() YELD beforehand
        deposits[msg.sender] = Deposit(deposits[msg.sender].amount.add(_amount), block.number);
    }
    
    /// Extracts your generated Yeldies while keeping the same deposit so it continues generating yeldies
    function extractEarningsWhileKeepingDeposit() public {
        require(deposits[msg.sender].start > 0 && deposits[msg.sender].amount > 0, 'Must have deposited YELD beforehand');
        uint256 generatedYeldies = getGeneratedYeldies();
        deposits[msg.sender] = Deposit(deposits[msg.sender].amount, block.number);
        
        IERC20(yeldies).transfer(msg.sender, generatedYeldies);
    }

    /// Withdraw
    function withdraw(uint256 _amount) public {
        require(deposits[msg.sender].start > 0 && deposits[msg.sender].amount > 0, 'Must have deposited YELD beforehand');
        require(_amount <= deposits[msg.sender].amount, "You can't withdraw more than the deposited balance");
        uint256 generatedYeldies = getGeneratedYeldies();
        uint256 yeldToSend = _amount;
        deposits[msg.sender] = Deposit(deposits[msg.sender].amount.sub(_amount), block.number);
        
        IERC20(yeldies).transfer(msg.sender, generatedYeldies);
        IERC20(yeld).transfer(msg.sender, yeldToSend);
    }
    
    /// Withdraws all
    function withdrawAll() public {
        withdraw(deposits[msg.sender].amount);
    }
    
    function getGeneratedYeldies() public view returns(uint256) {
        uint256 blocksPassed;
        if (deposits[msg.sender].start > 0) {
            blocksPassed = block.number.sub(deposits[msg.sender].start);
        } else {
            blocksPassed = 0;
        }
        // This will work because amount is a token with 18 decimals
        uint256 generatedYeldies = deposits[msg.sender].amount.mul(blocksPassed).div(oneDayInBlocks);
        return generatedYeldies;
    }
}


interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor (string memory name, string memory symbol, uint8 decimals) public {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
    }
    function name() public view returns (string memory) {
        return _name;
    }
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    function decimals() public view returns (uint8) {
        return _decimals;
    }
}


contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 _totalSupply;
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "ERC20: burn amount exceeds allowance"));
    }
}
