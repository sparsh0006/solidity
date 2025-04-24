// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title TokenSale
 * @dev A contract for managing a simple token sale with vesting periods
 */
contract TokenSale {
    // Token details
    string public name = "ExampleToken";
    string public symbol = "EXT";
    uint8 public decimals = 18;
    uint256 public totalSupply = 1000000 * (10 ** decimals); // 1 million tokens

    // Owner address
    address public owner;
    
    // Token price in ETH (1 token = 0.001 ETH)
    uint256 public tokenPrice = 0.001 ether;
    
    // Sale status
    bool public saleActive = false;
    
    // Maximum purchase per address
    uint256 public maxPurchase = 10000 * (10 ** decimals); // 10,000 tokens
    
    // Token balances mapping
    mapping(address => uint256) public balances;
    
    // Allowances mapping for ERC-20 transfers
    mapping(address => mapping(address => uint256)) public allowances;
    
    // Vesting schedules
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
    }
    
    // Vesting schedules mapping
    mapping(address => VestingSchedule) public vestingSchedules;
    
    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);
    event SaleStatusChanged(bool newStatus);
    event TokensVested(address indexed beneficiary, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier whenSaleActive() {
        require(saleActive, "Sale is not active");
        _;
    }
    
    // Constructor - mint all tokens to the contract creator
    constructor() {
        owner = msg.sender;
        balances[msg.sender] = totalSupply;
    }
    
    /**
     * @dev Start or pause the token sale
     * @param _status New sale status
     */
    function setSaleStatus(bool _status) external onlyOwner {
        saleActive = _status;
        emit SaleStatusChanged(_status);
    }
    
    /**
     * @dev Change the token price
     * @param _newPrice New price in ETH
     */
    function setTokenPrice(uint256 _newPrice) external onlyOwner {
        require(_newPrice > 0, "Price must be greater than 0");
        tokenPrice = _newPrice;
    }
    
    /**
     * @dev Purchase tokens with ETH
     */
    function purchaseTokens() external payable whenSaleActive {
        require(msg.value > 0, "Must send ETH to purchase tokens");
        
        // Calculate tokens to purchase
        uint256 tokenAmount = (msg.value * (10 ** decimals)) / tokenPrice;
        
        // Check purchase limit
        require(balances[msg.sender] + tokenAmount <= maxPurchase, "Purchase exceeds maximum allowed");
        
        // Check if contract has enough tokens
        require(balances[owner] >= tokenAmount, "Not enough tokens available for sale");
        
        // Transfer tokens from owner to buyer
        balances[owner] -= tokenAmount;
        balances[msg.sender] += tokenAmount;
        
        emit Transfer(owner, msg.sender, tokenAmount);
        emit TokensPurchased(msg.sender, tokenAmount, msg.value);
    }
    
    /**
     * @dev Create a vesting schedule for a beneficiary
     * @param _beneficiary Address of the beneficiary
     * @param _amount Total amount of tokens to vest
     * @param _cliffDuration Duration in seconds of the cliff
     * @param _vestingDuration Total duration in seconds of the vesting
     */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _amount,
        uint256 _cliffDuration,
        uint256 _vestingDuration
    ) external onlyOwner {
        require(_beneficiary != address(0), "Beneficiary cannot be zero address");
        require(_amount > 0, "Amount must be greater than 0");
        require(_vestingDuration >= _cliffDuration, "Vesting duration must be greater than or equal to cliff");
        
        // Check if contract has enough tokens
        require(balances[owner] >= _amount, "Not enough tokens available for vesting");
        
        // Create vesting schedule
        vestingSchedules[_beneficiary] = VestingSchedule({
            totalAmount: _amount,
            releasedAmount: 0,
            startTime: block.timestamp,
            cliffDuration: _cliffDuration,
            vestingDuration: _vestingDuration
        });
        
        // Transfer tokens from owner to contract (escrowed)
        balances[owner] -= _amount;
        balances[address(this)] += _amount;
        
        emit Transfer(owner, address(this), _amount);
    }
    
    /**
     * @dev Release vested tokens for the caller
     */
    function releaseVestedTokens() external {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No vesting schedule found");
        
        uint256 vestedAmount = calculateVestedAmount(msg.sender);
        uint256 releasableAmount = vestedAmount - schedule.releasedAmount;
        
        require(releasableAmount > 0, "No tokens available for release");
        
        // Update released amount
        schedule.releasedAmount += releasableAmount;
        
        // Transfer tokens from contract to beneficiary
        balances[address(this)] -= releasableAmount;
        balances[msg.sender] += releasableAmount;
        
        emit Transfer(address(this), msg.sender, releasableAmount);
        emit TokensVested(msg.sender, releasableAmount);
    }
    
    /**
     * @dev Calculate the amount of tokens that have vested for a beneficiary
     * @param _beneficiary Address of the beneficiary
     * @return The amount of vested tokens
     */
    function calculateVestedAmount(address _beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];
        
        // If no vesting schedule or before cliff, return 0
        if (schedule.totalAmount == 0 || block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }
        
        // If after vesting duration, return total amount
        if (block.timestamp >= schedule.startTime + schedule.vestingDuration) {
            return schedule.totalAmount;
        }
        
        // Calculate vested amount based on time elapsed
        uint256 timeElapsed = block.timestamp - schedule.startTime;
        return (schedule.totalAmount * timeElapsed) / schedule.vestingDuration;
    }
    
    /**
     * @dev Transfer tokens to another address (ERC-20 function)
     * @param _to Recipient address
     * @param _value Amount to transfer
     * @return Success status
     */
    function transfer(address _to, uint256 _value) external returns (bool) {
        require(_to != address(0), "Cannot transfer to zero address");
        require(balances[msg.sender] >= _value, "Insufficient balance");
        
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        
        emit Transfer(msg.sender, _to, _value);
        return true;
    }
    
    /**
     * @dev Approve spender to transfer tokens on behalf of the owner (ERC-20 function)
     * @param _spender Address authorized to spend
     * @param _value Amount authorized to spend
     * @return Success status
     */
    function approve(address _spender, uint256 _value) external returns (bool) {
        allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    /**
     * @dev Transfer tokens from one address to another (ERC-20 function)
     * @param _from Source address
     * @param _to Destination address
     * @param _value Amount to transfer
     * @return Success status
     */
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        require(_from != address(0), "Cannot transfer from zero address");
        require(_to != address(0), "Cannot transfer to zero address");
        require(balances[_from] >= _value, "Insufficient balance");
        require(allowances[_from][msg.sender] >= _value, "Allowance exceeded");
        
        balances[_from] -= _value;
        balances[_to] += _value;
        allowances[_from][msg.sender] -= _value;
        
        emit Transfer(_from, _to, _value);
        return true;
    }
    
    /**
     * @dev Get the balance of an account (ERC-20 function)
     * @param _owner The address to query
     * @return Balance of the address
     */
    function balanceOf(address _owner) external view returns (uint256) {
        return balances[_owner];
    }
    
    /**
     * @dev Get the allowance of a spender for an owner (ERC-20 function)
     * @param _owner The address that owns the tokens
     * @param _spender The address that can spend the tokens
     * @return Remaining allowance
     */
    function allowance(address _owner, address _spender) external view returns (uint256) {
        return allowances[_owner][_spender];
    }
    
    /**
     * @dev Withdraw ETH from contract to owner
     */
    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = owner.call{value: balance}("");
        require(success, "Withdrawal failed");
    }
    
    /**
     * @dev Fallback function to reject direct ETH transfers
     */
    receive() external payable {
        revert("Direct ETH transfers not allowed. Use purchaseTokens()");
    }
}