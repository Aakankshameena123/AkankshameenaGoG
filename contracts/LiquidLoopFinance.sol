State variables
    address public owner;
    uint256 public totalLiquidity;
    uint256 public rewardRate; Events
    event LiquidityAdded(address indexed provider, uint256 amount, uint256 timestamp);
    event LiquidityRemoved(address indexed provider, uint256 amount, uint256 timestamp);
    event RewardsClaimed(address indexed provider, uint256 reward, uint256 timestamp);
    event RewardRateUpdated(uint256 newRate, uint256 timestamp);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    5% default reward rate
    }
    
    /**
     * @dev Function 1: Add liquidity to the pool
     * Users can deposit ETH to become liquidity providers
     */
    function addLiquidity() external payable {
        require(msg.value > 0, "Must send ETH to add liquidity");
        
        LiquidityProvider storage provider = providers[msg.sender];
        
        Claim existing rewards before adding more liquidity
            uint256 pendingRewards = calculateRewards(msg.sender);
            provider.rewardsEarned += pendingRewards;
        }
        
        provider.amount += msg.value;
        provider.depositTime = block.timestamp;
        totalLiquidity += msg.value;
        
        emit LiquidityAdded(msg.sender, msg.value, block.timestamp);
    }
    
    /**
     * @dev Function 2: Remove liquidity from the pool
     * Users can withdraw their deposited ETH along with earned rewards
     */
    function removeLiquidity(uint256 amount) external hasLiquidity {
        LiquidityProvider storage provider = providers[msg.sender];
        require(amount > 0 && amount <= provider.amount, "Invalid withdrawal amount");
        
        Update provider state
        provider.amount -= amount;
        totalLiquidity -= amount;
        
        if (provider.amount == 0) {
            provider.isActive = false;
        }
        
        provider.depositTime = block.timestamp;
        
        Calculate total rewards
        uint256 pendingRewards = calculateRewards(msg.sender);
        uint256 totalRewards = provider.rewardsEarned + pendingRewards;
        
        require(totalRewards > 0, "No rewards to claim");
        require(address(this).balance >= totalRewards, "Insufficient contract balance");
        
        Transfer rewards
        payable(msg.sender).transfer(totalRewards);
        
        emit RewardsClaimed(msg.sender, totalRewards, block.timestamp);
    }
    
    /**
     * @dev Function 4: Calculate pending rewards for a provider
     * Returns the amount of rewards earned based on time and reward rate
     */
    function calculateRewards(address providerAddress) public view returns (uint256) {
        LiquidityProvider memory provider = providers[providerAddress];
        
        if (!provider.isActive || provider.amount == 0) {
            return 0;
        }
        
        uint256 timeElapsed = block.timestamp - provider.depositTime;
        uint256 rewards = (provider.amount * rewardRate * timeElapsed) / (365 days * 10000);
        
        return rewards;
    }
    
    /**
     * @dev Function 5: Update reward rate (only owner)
     * Allows the contract owner to adjust the annual reward rate
     */
    function updateRewardRate(uint256 newRate) external onlyOwner {
        require(newRate > 0 && newRate <= 10000, "Invalid reward rate"); Additional utility functions
    
    /**
     * @dev Get provider details
     */
    function getProviderInfo(address providerAddress) external view returns (
        uint256 amount,
        uint256 depositTime,
        uint256 rewardsEarned,
        uint256 pendingRewards,
        bool isActive
    ) {
        LiquidityProvider memory provider = providers[providerAddress];
        return (
            provider.amount,
            provider.depositTime,
            provider.rewardsEarned,
            calculateRewards(providerAddress),
            provider.isActive
        );
    }
    
    /**
     * @dev Get total number of liquidity providers
     */
    function getProviderCount() external view returns (uint256) {
        return providerAddresses.length;
    }
    
    /**
     * @dev Transfer ownership
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        address previousOwner = owner;
        owner = newOwner;
        
        emit OwnershipTransferred(previousOwner, newOwner);
    }
    
    /**
     * @dev Receive function to accept ETH
     */
    receive() external payable {
        totalLiquidity += msg.value;
    }
}
// 
End
// 
