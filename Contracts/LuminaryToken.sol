// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.1;

// Version: 0.0.5
// Recent Changes:
// - 2025-05-19: Integrated TokenRegistry with initializeBalances calls in transfer and transferFrom.
// - 2025-05-19: Added setRegistry function, ownerOnly, with RegistrySet event.
// - 2025-05-19: Added RegistryError event for graceful degradation in registry interactions.
// - 2025-05-19: Added registry and owner state variables, updated constructor.
// - 2025-05-19: Updated ILuminaryToken to include setRegistry.

import "./imports/ERC20.sol";
import "./imports/SafeMath.sol";
import "./imports/ReentrancyGuard.sol";

// Interface for TokenRegistry
interface ITokenRegistry {
    function initializeBalances(address[] memory tokens, address[] memory users) external;
}

// Interface for LuminaryToken
interface ILuminaryToken {
    function mintRewards() external;
    function claimReward() external;
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function decimals() external pure returns (uint8);
    function setRegistry(address registry) external;
}

contract LuminaryToken is ERC20, ReentrancyGuard {
    using SafeMath for uint256;

    // Token details
    string private constant _name = "Luminary Token";
    string private constant _symbol = "LUX";
    uint256 private constant INITIAL_SUPPLY = 10 * 10**18; // 10 tokens, 18 decimals

    // Reward mechanics
    uint256 public swapCount;
    uint256 public constant swapThreshold = 500;
    mapping(address => uint256) public rewardEligibility;
    uint256 public mintedRewards;

    // Registry integration
    address public registry;
    address public owner;

    // Constants
    uint256 private constant FEE_PERCENT = 5; // 0.05%
    uint256 private constant FEE_DENOMINATOR = 10_000;
    uint256 private constant MIN_SWAP_PERCENT = 1; // 0.01% of supply
    uint256 private constant MIN_SWAP_DENOMINATOR = 10_000; // For 0.01%
    uint256 private constant REWARD_PERCENT = 25; // 25% of balance or supply
    uint256 private constant ONE_MONTH = 2_592_000; // 30 days in seconds

    // Events
    event Minted(address indexed to, uint256 amount);
    event RegistrySet(address indexed registry);
    event RegistryError(string message);

    constructor() ERC20(_name, _symbol) {
        _mint(msg.sender, INITIAL_SUPPLY);
        emit Minted(msg.sender, INITIAL_SUPPLY);
        owner = msg.sender;
    }

    // Set TokenRegistry address, owner only
    function setRegistry(address newRegistry) external {
        require(msg.sender == owner, "Owner only");
        require(newRegistry != address(0), "Invalid registry address");
        registry = newRegistry;
        emit RegistrySet(newRegistry);
    }

    // Override decimals to ensure 18
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    // Helper: Mint 25% of current supply to contract
    function _mintToContract() internal {
        uint256 amount = totalSupply().mul(REWARD_PERCENT).div(100);
        if (amount > 0) {
            _mint(address(this), amount);
            mintedRewards = mintedRewards.add(amount);
            emit Minted(address(this), amount);
        }
    }

    // Helper: Reset swapCount to 0
    function _resetSwapCount() internal {
        swapCount = 0;
    }

    // Mint 25% of supply to contract, reset swapCount
    function mintRewards() external nonReentrant {
        require(swapCount > swapThreshold, "Swap count below threshold");

        // Execute steps via helpers
        _mintToContract();
        _resetSwapCount();
    }

    // Claim reward: 25% of caller's balance, if eligible
    function claimReward() external nonReentrant {
        require(rewardEligibility[msg.sender] + ONE_MONTH <= block.timestamp, "Claim not yet eligible");

        uint256 reward = balanceOf(msg.sender).mul(REWARD_PERCENT).div(100);
        require(reward > 0, "No reward available");
        require(balanceOf(address(this)) >= reward, "Insufficient contract balance");

        // Update eligibility before transfer
        rewardEligibility[msg.sender] = block.timestamp;

        // Transfer reward
        _transfer(address(this), msg.sender, reward);
    }

    // Override transfer to include fee, eligibility, and registry update
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        uint256 fee = amount.mul(FEE_PERCENT).div(FEE_DENOMINATOR);
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

        // Update registry
        if (registry != address(0)) {
            address[] memory tokens = new address[](2);
            address[] memory users = new address[](2);
            tokens[0] = address(this);
            tokens[1] = address(this);
            users[0] = msg.sender;
            users[1] = recipient;
            try ITokenRegistry(registry).initializeBalances(tokens, users) {
                // Success, no action needed
            } catch {
                emit RegistryError("Failed to update registry");
            }
        } else {
            emit RegistryError("Registry not set");
        }

        return true;
    }

    // Override transferFrom to include fee, eligibility, and registry update
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 fee = amount.mul(FEE_PERCENT).div(FEE_DENOMINATOR);
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

        // Update registry
        if (registry != address(0)) {
            address[] memory tokens = new address[](2);
            address[] memory users = new address[](2);
            tokens[0] = address(this);
            tokens[1] = address(this);
            users[0] = sender;
            users[1] = recipient;
            try ITokenRegistry(registry).initializeBalances(tokens, users) {
                // Success, no action needed
            } catch {
                emit RegistryError("Failed to update registry");
            }
        } else {
            emit RegistryError("Registry not set");
        }

        return true;
    }
}