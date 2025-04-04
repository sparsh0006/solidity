// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title TokenStaking
 * @dev A contract for staking tokens and earning rewards
 */
contract TokenStaking is AccessControl, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Access control roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant REWARDS_DISTRIBUTOR_ROLE = keccak256("REWARDS_DISTRIBUTOR_ROLE");

    // Staking token (what users deposit)
    IERC20 public stakingToken;
    
    // Rewards token (what users earn)
    IERC20 public rewardsToken;

    // Staking pools with different lock periods and reward multipliers
    struct StakingPool {
        uint256 lockPeriod;       // In seconds
        uint256 rewardMultiplier; // Basis points (100 = 1%)
        uint256 totalStaked;      // Total tokens staked in this pool
        bool isActive;            // Whether new stakes can be added to this pool
    }

    // Pool ID => Pool details
    mapping(uint256 => StakingPool) public stakingPools;
    uint256 public poolCount;

    // User staking information
    struct Stake {
        uint256 amount;           // Amount staked
        uint256 poolId;           // Pool ID where tokens are staked
        uint256 startTime;        // When stake was created
        uint256 endTime;          // When stake can be withdrawn without penalty
        uint256 lastRewardTime;   // Last time rewards were calculated
        uint256 unclaimedRewards; // Accumulated rewards not yet claimed
    }

    // User address => Stake ID => Stake details
    mapping(address => mapping(uint256 => Stake)) public userStakes;
    mapping(address => uint256) public userStakeCount;
    
    // Total tokens staked across all pools
    uint256 public totalStaked;
    
    // Rewards-related variables
    uint256 public rewardRate;             // Rewards distributed per second
    uint256 public lastUpdateTime;         // Last time the reward variables were updated
    uint256 public rewardPerTokenStored;   // Accumulated rewards per token
    
    // Early withdrawal penalty (in basis points, e.g., 1000 = 10%)
    uint256 public earlyWithdrawalPenalty = 1000;
    
    // Address where penalties go
    address public penaltyCollector;
    
    // Events
    event PoolCreated(uint256 indexed poolId, uint256 lockPeriod, uint256 rewardMultiplier);
    event PoolUpdated(uint256 indexed poolId, uint256 lockPeriod, uint256 rewardMultiplier, bool isActive);
    event Staked(address indexed user, uint256 indexed poolId, uint256 stakeId, uint256 amount);
    event Withdrawn(address indexed user, uint256 indexed poolId, uint256 stakeId, uint256 amount);
    event RewardClaimed(address indexed user, uint256 stakeId, uint256 reward);
    event RewardRateUpdated(uint256 newRate);
    event EarlyWithdrawalPenaltyUpdated(uint256 newPenalty);

    /**
     * @dev Constructor
     * @param _stakingToken The token users will stake
     * @param _rewardsToken The token users will receive as rewards
     * @param _penaltyCollector Address where early withdrawal penalties go
     */
    constructor(
        IERC20 _stakingToken,
        IERC20 _rewardsToken,
        address _penaltyCollector
    ) {
        stakingToken = _stakingToken;
        rewardsToken = _rewardsToken;
        penaltyCollector = _penaltyCollector;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(REWARDS_DISTRIBUTOR_ROLE, msg.sender);
        
        lastUpdateTime = block.timestamp;
    }
    
    /**
     * @dev Create a new staking pool
     * @param lockPeriod Time in seconds tokens must be locked
     * @param rewardMultiplier Reward multiplier in basis points
     */
    function createPool(uint256 lockPeriod, uint256 rewardMultiplier) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        uint256 poolId = poolCount;
        stakingPools[poolId] = StakingPool({
            lockPeriod: lockPeriod,
            rewardMultiplier: rewardMultiplier,
            totalStaked: 0,
            isActive: true
        });
        
        poolCount = poolCount + 1;
        
        emit PoolCreated(poolId, lockPeriod, rewardMultiplier);
    }
    
    /**
     * @dev Update an existing staking pool
     * @param poolId ID of the pool to update
     * @param lockPeriod New lock period
     * @param rewardMultiplier New reward multiplier
     * @param isActive Whether pool is active for new stakes
     */
    function updatePool(uint256 poolId, uint256 lockPeriod, uint256 rewardMultiplier, bool isActive) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(poolId < poolCount, "Pool doesn't exist");
        
        StakingPool storage pool = stakingPools[poolId];
        pool.lockPeriod = lockPeriod;
        pool.rewardMultiplier = rewardMultiplier;
        pool.isActive = isActive;
        
        emit PoolUpdated(poolId, lockPeriod, rewardMultiplier, isActive);
    }
    
    /**
     * @dev User stakes tokens in a specific pool
     * @param amount Amount to stake
     * @param poolId Pool to stake in
     */
    function stake(uint256 amount, uint256 poolId) external nonReentrant {
        require(amount > 0, "Cannot stake 0");
        require(poolId < poolCount, "Pool doesn't exist");
        
        StakingPool storage pool = stakingPools[poolId];
        require(pool.isActive, "Pool is not active");
        
        updateReward(msg.sender);
        
        uint256 stakeId = userStakeCount[msg.sender];
        uint256 lockEnd = block.timestamp + pool.lockPeriod;
        
        userStakes[msg.sender][stakeId] = Stake({
            amount: amount,
            poolId: poolId,
            startTime: block.timestamp,
            endTime: lockEnd,
            lastRewardTime: block.timestamp,
            unclaimedRewards: 0
        });
        
        userStakeCount[msg.sender] = stakeId + 1;
        
        totalStaked = totalStaked.add(amount);
        pool.totalStaked = pool.totalStaked.add(amount);
        
        // Transfer tokens from user to this contract
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        
        emit Staked(msg.sender, poolId, stakeId, amount);
    }
    
    /**
     * @dev Withdraw staked tokens and claim rewards
     * @param stakeId ID of the stake to withdraw
     * @param amount Amount to withdraw (can be partial)
     */
    function withdraw(uint256 stakeId, uint256 amount) external nonReentrant {
        require(stakeId < userStakeCount[msg.sender], "Stake doesn't exist");
        
        Stake storage userStake = userStakes[msg.sender][stakeId];
        require(amount > 0 && amount <= userStake.amount, "Invalid amount");
        
        updateReward(msg.sender);
        
        uint256 poolId = userStake.poolId;
        StakingPool storage pool = stakingPools[poolId];
        
        // Check if withdrawal is early
        bool isEarly = block.timestamp < userStake.endTime;
        
        // Calculate penalty if withdrawal is early
        uint256 penalty = 0;
        if (isEarly) {
            penalty = amount.mul(earlyWithdrawalPenalty).div(10000);
        }
        
        // Update stake amount
        userStake.amount = userStake.amount.sub(amount);
        
        // Update totals
        totalStaked = totalStaked.sub(amount);
        pool.totalStaked = pool.totalStaked.sub(amount);
        
        // Transfer tokens to user minus penalty
        uint256 transferAmount = amount.sub(penalty);
        stakingToken.safeTransfer(msg.sender, transferAmount);
        
        // Transfer penalty to collector
        if (penalty > 0) {
            stakingToken.safeTransfer(penaltyCollector, penalty);
        }
        
        emit Withdrawn(msg.sender, poolId, stakeId, amount);
        
        // Claim rewards if any
        if (userStake.unclaimedRewards > 0) {
            claimRewards(stakeId);
        }
    }
    
    /**
     * @dev Claim accumulated rewards without withdrawing stake
     * @param stakeId ID of the stake to claim rewards for
     */
    function claimRewards(uint256 stakeId) public nonReentrant {
        require(stakeId < userStakeCount[msg.sender], "Stake doesn't exist");
        
        updateReward(msg.sender);
        
        Stake storage userStake = userStakes[msg.sender][stakeId];
        uint256 reward = userStake.unclaimedRewards;
        
        require(reward > 0, "No rewards to claim");
        
        userStake.unclaimedRewards = 0;
        
        // Transfer rewards to user
        rewardsToken.safeTransfer(msg.sender, reward);
        
        emit RewardClaimed(msg.sender, stakeId, reward);
    }
    
    /**
     * @dev Update reward variables for a user
     * @param user Address of the user
     */
    function updateReward(address user) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        
        if (user != address(0)) {
            uint256 stakeCount = userStakeCount[user];
            
            for (uint256 i = 0; i < stakeCount; i++) {
                Stake storage userStake = userStakes[user][i];
                
                // Skip if stake is empty
                if (userStake.amount == 0) continue;
                
                // Calculate time since last reward update
                uint256 timeElapsed = block.timestamp.sub(userStake.lastRewardTime);
                
                if (timeElapsed > 0) {
                    // Get pool reward multiplier
                    uint256 poolId = userStake.poolId;
                    StakingPool storage pool = stakingPools[poolId];
                    
                    // Calculate rewards based on time elapsed, stake amount, reward rate, and pool multiplier
                    uint256 reward = timeElapsed
                        .mul(rewardRate)
                        .mul(userStake.amount)
                        .mul(pool.rewardMultiplier)
                        .div(10000)
                        .div(totalStaked > 0 ? totalStaked : 1);
                    
                    // Add to unclaimed rewards
                    userStake.unclaimedRewards = userStake.unclaimedRewards.add(reward);
                    userStake.lastRewardTime = block.timestamp;
                }
            }
        }
    }
    
    /**
     * @dev Calculate current reward per token
     * @return Reward per token
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        
        return rewardPerTokenStored.add(
            block.timestamp
                .sub(lastUpdateTime)
                .mul(rewardRate)
                .mul(1e18)
                .div(totalStaked)
        );
    }
    
    /**
     * @dev Get user's stake details
     * @param user Address of the user
     * @param stakeId ID of the stake
     * @return amount Amount staked
     * @return poolId Pool ID
     * @return startTime Start time of stake
     * @return endTime End time of lock period
     * @return rewards Unclaimed rewards
     */
    function getUserStake(address user, uint256 stakeId) 
        external 
        view 
        returns (
            uint256 amount,
            uint256 poolId, 
            uint256 startTime, 
            uint256 endTime, 
            uint256 rewards
        ) 
    {
        require(stakeId < userStakeCount[user], "Stake doesn't exist");
        
        Stake storage userStake = userStakes[user][stakeId];
        
        amount = userStake.amount;
        poolId = userStake.poolId;
        startTime = userStake.startTime;
        endTime = userStake.endTime;
        
        // Calculate current rewards
        uint256 timeElapsed = block.timestamp.sub(userStake.lastRewardTime);
        StakingPool storage pool = stakingPools[userStake.poolId];
        
        uint256 additionalRewards = 0;
        if (amount > 0 && timeElapsed > 0 && totalStaked > 0) {
            additionalRewards = timeElapsed
                .mul(rewardRate)
                .mul(amount)
                .mul(pool.rewardMultiplier)
                .div(10000)
                .div(totalStaked);
        }
        
        rewards = userStake.unclaimedRewards.add(additionalRewards);
    }
    
    /**
     * @dev Set the reward rate
     * @param _rewardRate New reward rate (tokens per second)
     */
    function setRewardRate(uint256 _rewardRate) 
        external 
        onlyRole(REWARDS_DISTRIBUTOR_ROLE) 
    {
        updateReward(address(0));
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }
    
    /**
     * @dev Set the early withdrawal penalty
     * @param _penalty New penalty in basis points
     */
    function setEarlyWithdrawalPenalty(uint256 _penalty) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(_penalty <= 3000, "Penalty too high"); // Max 30%
        earlyWithdrawalPenalty = _penalty;
        emit EarlyWithdrawalPenaltyUpdated(_penalty);
    }
    
    /**
     * @dev Set the penalty collector address
     * @param _penaltyCollector New penalty collector address
     */
    function setPenaltyCollector(address _penaltyCollector) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(_penaltyCollector != address(0), "Cannot be zero address");
        penaltyCollector = _penaltyCollector;
    }
    
    /**
     * @dev Add rewards to the contract
     * @param amount Amount of rewards to add
     */
    function addRewards(uint256 amount) 
        external 
        onlyRole(REWARDS_DISTRIBUTOR_ROLE) 
    {
        require(amount > 0, "Cannot add 0 rewards");
        
        rewardsToken.safeTransferFrom(msg.sender, address(this), amount);
    }
    
    /**
     * @dev Recover mistakenly sent tokens
     * @param token Token address
     * @param amount Amount to recover
     */
    function recoverERC20(address token, uint256 amount) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(token != address(stakingToken), "Cannot withdraw staking token");
        
        // If trying to withdraw reward token, ensure it's only the excess
        if (token == address(rewardsToken)) {
            uint256 totalRewards = 0;
            
            // Sum up all unclaimed rewards
            for (uint256 poolId = 0; poolId < poolCount; poolId++) {
                StakingPool storage pool = stakingPools[poolId];
                // Calculate maximum rewards that could be claimed from this pool
                uint256 poolMaxRewards = pool.totalStaked
                    .mul(rewardRate)
                    .mul(30 days) // Assume 30 days of rewards as buffer
                    .mul(pool.rewardMultiplier)
                    .div(10000);
                
                totalRewards = totalRewards.add(poolMaxRewards);
            }
            
            uint256 rewardBalance = rewardsToken.balanceOf(address(this));
            require(amount <= rewardBalance.sub(totalRewards), "Cannot withdraw reserved rewards");
        }
        
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}