// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.2;

import "./imports/IERC20.sol";

// Significant changes:
// - Contract named LightSource.
// - Removed setToken function; claim takes token address as parameter.
// - Added reentrancy protection for claim function.
// - Included event emission for transparency.
// - Verified 18 decimals and contract balance before transfer.
// - Used mapping and array to track claimants and prevent repeat claims.

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint256);
}

contract LightSource {
    // Tracks if an address has claimed
    mapping(address => bool) public hasClaimed;
    // Stores all claimant addresses
    address[] public claimants;
    // Reentrancy guard state
    bool private locked;

    // Events for transparency
    event Claim(address indexed claimant, address indexed token, uint256 amount);

    // Reentrancy guard modifier
    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    // Transfers 0.01 (1e16 wei) tokens to msg.sender if not claimed before
    function claim(address token) external nonReentrant {
        // Check if already claimed
        require(!hasClaimed[msg.sender], "Already claimed");

        // Verify token address
        require(token != address(0), "Invalid token address");

        IERC20 tokenContract = IERC20(token);

        // Verify decimals (assume 18 for consistency)
        uint256 decimals = tokenContract.decimals();
        require(decimals == 18, "Unsupported decimals");

        // Calculate amount (0.01 = 1e16 wei for 18 decimals)
        uint256 amount = 1e16;

        // Check contract balance
        uint256 balance = tokenContract.balanceOf(address(this));
        require(balance >= amount, "Insufficient contract balance");

        // Mark as claimed
        hasClaimed[msg.sender] = true;
        claimants.push(msg.sender);

        // Transfer tokens
        bool success = tokenContract.transfer(msg.sender, amount);
        require(success, "Transfer failed");

        // Emit event
        emit Claim(msg.sender, token, amount);
    }
}