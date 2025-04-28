// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.1;

// Version : 0.0.1 
// - Initial implementation of LuminaryToken ERC-20 with pull — based rewards.
// - Added mintRewards and claimReward for reward distribution.
// - Implemented swapCount, swapThreshold, and rewardEligibility for reward mechanics.
// - Added 1% fee and minimum swap amount (0.01% of supply) for swapCount increments.

import "./imports/ERC20.sol";
import "./imports/SafeMath.sol";
import "./imports/ReentrancyGuard.sol";

// Interface for LuminaryToken
interface ILuminaryToken {
    function mintRewards() external;
    function claimReward() external;
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract LuminaryToken is ERC20, ReentrancyGuard {
    using SafeMath for uint256;

    // Token details
    string private constant _name = "Luminary Token";
    string private constant _symbol = "LUX";
    uint256 private constant INITIAL_SUPPLY = 250_000 * 10**18; // 250,000 tokens, 18 decimals

    // Reward mechanics
    uint256 public swapCount;
    uint256 public swapThreshold;
    uint256 private constant MAX_THRESHOLD = 2500;
    mapping(address => uint256) public rewardEligibility;

    // Constants
    uint256 private constant FEE_PERCENT = 1; // 1% fee
    uint256 private constant MIN_SWAP_PERCENT = 1; // 0.01% of supply
    uint256 private constant MIN_SWAP_DENOMINATOR = 10_000; // For 0.01%
    uint256 private constant REWARD_PERCENT = 25; // 25% of balance or supply
    uint256 private constant ONE_MONTH = 2_592_000; // 30 days in seconds

    constructor() ERC20(_name, _symbol) {
        _mint(msg.sender, INITIAL_SUPPLY);
        swapThreshold = 0; // Initial threshold
    }

    // Helper: Mint 25% of current supply to contract
    function _mintToContract() internal {
        uint256 amount = totalSupply().mul(REWARD_PERCENT).div(100);
        _mint(address(this), amount);
    }

    // Helper: Reset swapCount to 0
    function _resetSwapCount() internal {
        swapCount = 0;
    }

    // Helper: Increment swapThreshold by 1, cap at MAX_THRESHOLD
    function _updateSwapThreshold() internal {
        if (swapThreshold < MAX_THRESHOLD) {
            swapThreshold = swapThreshold.add(1);
        }
    }

    // Mint 25% of supply to contract, reset swapCount, update threshold
    function mintRewards() external nonReentrant {
        require(swapCount > swapThreshold, "Swap count below threshold");

        // Execute steps via helpers
        _mintToContract();
        _resetSwapCount();
        _updateSwapThreshold();
    }

    // Claim reward: 25% of caller's balance, if eligible
    function claimReward() external {
        require(rewardEligibility[msg.sender] + ONE_MONTH <= block.timestamp, "Claim not yet eligible");

        uint256 reward = balanceOf(msg.sender).mul(REWARD_PERCENT).div(100);
        require(reward > 0, "No reward available");
        require(balanceOf(address(this)) >= reward, "Insufficient contract balance");

        // Update eligibility before transfer
        rewardEligibility[msg.sender] = block.timestamp;

        // Transfer reward
        _transfer(address(this), msg.sender, reward);
    }

    // Override transfer to include fee and eligibility
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        uint256 fee = amount.mul(FEE_PERCENT).div(100);
        uint256 netAmount = amount.sub(fee);

        // Check if swapCount should increment
        uint256 minSwapAmount = totalSupply().mul(MIN_SWAP_PERCENT).div(MIN_SWAP_DENOMINATOR);
        if (amount >= minSwapAmount) {
            swapCount = swapCount.add(1);
        }

        // Set eligibility for new recipient
        if (balanceOf(recipient) == 0) {
            rewardEligibility[recipient] = block.timestamp;
        }

        // Transfer fee to contract, net amount to recipient
        _transfer(msg.sender, address(this), fee);
        _transfer(msg.sender, recipient, netAmount);

        return true;
    }

    // Override transferFrom to include fee and eligibility
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 fee = amount.mul(FEE_PERCENT).div(100);
        uint256 netAmount = amount.sub(fee);

        // Check if swapCount should increment
        uint256 minSwapAmount = totalSupply().mul(MIN_SWAP_PERCENT).div(MIN_SWAP_DENOMINATOR);
        if (amount >= minSwapAmount) {
            swapCount = swapCount.add(1);
        }

        // Set eligibility for new recipient
        if (balanceOf(recipient) == 0) {
            rewardEligibility[recipient] = block.timestamp;
        }

        // Transfer fee to contract, net amount to recipient
        _transfer(sender, address(this), fee);
        _transfer(sender, recipient, netAmount);

        // Update allowance
        uint256 currentAllowance = allowance(sender, msg.sender);
        require(currentAllowance >= amount, "Transfer amount exceeds allowance");
        _approve(sender, msg.sender, currentAllowance.sub(amount));

        return true;
    }
}