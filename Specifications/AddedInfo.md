# Immaterium Frontend ABIs and Function Explanations

This document provides the Application Binary Interfaces (ABIs) for the smart contract functions used in the Immaterium frontend, as specified in the `ImmateriumFEOnly.md` document. Each function is accompanied by an explanation of its behavior and its role in the frontend application. The contracts involved are `chapterMapper.sol`, `immateriumChapter.sol`, `LightSource.sol`, `luminaryToken.sol`, and `immateriumFactory.sol`, deployed on the Sonic Blaze Testnet (Chain ID: 57054). Additionally, concerns about typos and logical errors in the frontend specifications are noted separately.

---

## Table of Contents
1. [chapterMapper.sol Functions](#chaptermapper-sol-functions)
2. [immateriumChapter.sol Functions](#immateriumchapter-sol-functions)
3. [LightSource.sol Functions](#lightsource-sol-functions)
4. [luminaryToken.sol Functions](#luminarytoken-sol-functions)
5. [immateriumFactory.sol Functions](#immateriumfactory-sol-functions)
6. [Concerns and Recommendations](#concerns-and-recommendations)

---

## chapterMapper.sol Functions

### 1. `queryPartialName(string query)`
**ABI**:
```json
{
  "constant": true,
  "inputs": [{ "name": "query", "type": "string" }],
  "name": "queryPartialName",
  "outputs": [
    { "name": "", "type": "address[]" },
    { "name": "", "type": "string[]" }
  ],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0x01f2e8dc"
}
```
**Behavior**:
- Takes a string `query` and searches the `chapterNames` array for chapter names containing the query as a substring.
- Returns two arrays: one with matching chapter addresses and another with their corresponding names.
- Uses the `_isSubstring` helper to perform case-sensitive substring matching without external libraries.
- **Frontend Usage**: Called in the Search Modal to display chapter cards with names and addresses. Users click a card to open the Chapter Modal with the selected chapter’s address.
- **Notes**: The function iterates over all chapter names, which could be gas-intensive for large arrays. The frontend should handle empty or overly long queries gracefully.

### 2. `getHearerChapters(address hearer)`
**ABI**:
```json
{
  "constant": true,
  "inputs": [{ "name": "hearer", "type": "address" }],
  "name": "getHearerChapters",
  "outputs": [{ "name": "", "type": "address[]" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0x4efc3d12"
}
```
**Behavior**:
- Returns an array of chapter addresses that the specified `hearer` is subscribed to, stored in the `hearerChapters` mapping.
- **Frontend Usage**: Used in the User Feed Modal to fetch the list of chapters a connected user is subscribed to, enabling the display of their feed with the latest lumens from those chapters.
- **Notes**: The function assumes the hearer has a reasonable number of subscriptions (limited to 1000 chapters). The frontend should check for empty arrays to avoid displaying an empty feed.

### 3. `isHearerSubscribed(address hearer, address chapter)`
**ABI**:
```json
{
  "constant": true,
  "inputs": [
    { "name": "hearer", "type": "address" },
    { "name": "chapter", "type": "address" }
  ],
  "name": "isHearerSubscribed",
  "outputs": [{ "name": "", "type": "bool" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0x1d3b9cb0"
}
```
**Behavior**:
- Checks if a `hearer` is subscribed to a specific `chapter` by iterating through the `hearerChapters` array for that hearer.
- Returns `true` if the chapter is found, `false` otherwise, with a limit of 500 chapters to prevent excessive gas usage.
- **Frontend Usage**: Used in the Chapter Modal to toggle between Subscribe (`↖️`) and Unsubscribe (`↘️`) buttons based on the user’s subscription status.
- **Notes**: The 500-chapter limit may cause issues for users with many subscriptions. The frontend should warn users if this limit is approached.

---

## immateriumChapter.sol Functions

### 1. `hear()`
**ABI**:
```json
{
  "constant": false,
  "inputs": [],
  "name": "hear",
  "outputs": [],
  "payable": false,
  "stateMutability": "nonpayable",
  "type": "function",
  "signature": "0x80b448fe"
}
```
**Behavior**:
- Adds the caller (`msg.sender`) to the `hearers` array as an active hearer with `ownCycle = 1` and `status = true`.
- If `chapterMapper` is set, calls `addChapter` on the `chapterMapper` contract to link the hearer to this chapter.
- **Frontend Usage**: Called in the Chapter Modal when the Subscribe button is clicked, after approving the chapter fee via the LUX token’s `approve` function.
- **Notes**: The frontend must ensure sufficient token allowance and balance before calling `hear`. If the balance is insufficient, a popup prompts the user to acquire tokens (e.g., via the Light Source Modal for LUX).

### 2. `silence()`
**ABI**:
```json
{
  "constant": false,
  "inputs": [],
  "name": "silence",
  "outputs": [],
  "payable": false,
  "stateMutability": "nonpayable",
  "type": "function",
  "signature": "0xfa537f74"
}
```
**Behavior**:
- Marks the caller as an inactive hearer (`status = false`) and calls `removeChapter` on the `chapterMapper` contract if set.
- Reverts if the caller is not an active hearer.
- **Frontend Usage**: Called by the Unsubscribe button in the Chapter Modal or the Cancel button in the User Feed Modal’s subscriptions list.
- **Notes**: Cached keys remain accessible, allowing users to view existing posts after unsubscribing. The frontend should update the UI to reflect the new status.

### 3. `luminate(string dataEntry)`
**ABI**:
```json
{
  "constant": false,
  "inputs": [{ "name": "dataEntry", "type": "string" }],
  "name": "luminate",
  "outputs": [],
  "payable": false,
  "stateMutability": "nonpayable",
  "type": "function",
  "signature": "0xead08026"
}
```
**Behavior**:
- Creates a new `Lumen` struct with the provided `dataEntry`, current `chapterCycle`, and timestamp, storing it in the `lumens` array.
- Only callable by the chapter’s `elect`.
- Increments `lumenHeight`.
- **Frontend Usage**: Called in the Lumen Creation Modal to post new content (encrypted or unencrypted). The modal supports markdown and file links via ImgBB.
- **Notes**: The frontend must encrypt private posts with the `pureCycleKey` before calling `luminate`. Ensure the caller is the elect to avoid transaction failures.

### 4. `addChapterName(string name)`
**ABI**:
```json
{
  "constant": false,
  "inputs": [{ "name": "name", "type": "string" }],
  "name": "addChapterName",
  "outputs": [],
  "payable": false,
  "stateMutability": "nonpayable",
  "type": "function",
  "signature": "0xefa12995"
}
```
**Behavior**:
- Sets the chapter’s `chapterName` and calls `addName` on the `chapterMapper` contract to associate the name with the chapter’s address.
- Only callable by the `elect`.
- **Frontend Usage**: Used in the Chapter Profile Modal to update the chapter name, with a warning if the name exceeds 100 characters (unmapped in `chapterMapper`).
- **Notes**: The frontend should validate name length and uniqueness before calling to prevent reversion.

### 5. `addChapterImage(string image)`
**ABI**:
```json
{
  "constant": false,
  "inputs": [{ "name": "image", "type": "string" }],
  "name": "addChapterImage",
  "outputs": [],
  "payable": false,
  "stateMutability": "nonpayable",
  "type": "function",
  "signature": "0x0691c1bb"
}
```
**Behavior**:
- Sets the chapter’s `chapterImage` to the provided string (typically a URL).
- Only callable by the `elect`.
- **Frontend Usage**: Used in the Chapter Profile Modal to update the chapter image, typically sourced from ImgBB uploads.
- **Notes**: The frontend should validate the image URL format to ensure it’s accessible.

### 6. `nextCycleBill(string key, uint256 cellIndex, string ownKeys)`
**ABI**:
```json
{
  "constant": false,
  "inputs": [
    { "name": "key", "type": "string" },
    { "name": "cellIndex", "type": "uint256" },
    { "name": "ownKeys", "type": "string" }
  ],
  "name": "nextCycleBill",
  "outputs": [],
  "payable": false,
  "stateMutability": "nonpayable",
  "type": "function",
  "signature": "0x32244167"
}
```
**Behavior**:
- Bills hearers in the specified `cellIndex` (group of up to 100 hearers) and updates their encryption keys.
- Increments `pendingCycle` and stores the encrypted `key` in `cycleKey`.
- Charges active hearers with sufficient balance/allowance; marks others inactive.
- Updates `ownKeys` for active hearers, parsed as a comma-separated string.
- Finalizes `chapterCycle` and sets `nextFee` when the highest cell is billed.
- Only callable by the `elect`.
- **Frontend Usage**: Used in the Chapter Profile Modal’s Pending Fees section to process billing and key updates for a cell.
- **Notes**: The frontend must generate a `pureCycleKey`, encrypt it for the `key` parameter, and encrypt it for each hearer in the cell for `ownKeys`. Cache the last billed cell to resume billing.

### 7. `billAndSet(address hearer, string cycleIndexes, string ownKeys)`
**ABI**:
```json
{
  "constant": false,
  "inputs": [
    { "name": "hearer", "type": "address" },
    { "name": "cycleIndexes", "type": "string" },
    { "name": "ownKeys", "type": "string" }
  ],
  "name": "billAndSet",
  "outputs": [],
  "payable": false,
  "stateMutability": "nonpayable",
  "type": "function",
  "signature": "0x793d6bbe"
}
```
**Behavior**:
- Bills a specific `hearer` and updates their keys for specified cycles.
- Parses `cycleIndexes` and `ownKeys` as comma-separated strings, ensuring they match in length and are valid.
- Charges the hearer if their `ownCycle` is behind `chapterCycle` and they have sufficient balance/allowance.
- Updates the hearer’s `ownKey` and `ownCycle` to the highest cycle index provided.
- Only callable by the `elect`.
- **Frontend Usage**: Used in the Chapter Profile Modal’s Laggards section to bill and update keys for hearers behind on cycles.
- **Notes**: The frontend must decrypt `cycleKey` values and re-encrypt them for the hearer’s public key.

### 8. `chapterName()`
**ABI**:
```json
{
  "constant": true,
  "inputs": [],
  "name": "chapterName",
  "outputs": [{ "name": "", "type": "string" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0x06a76993"
}
```
**Behavior**:
- Returns the chapter’s name as a string.
- **Frontend Usage**: Used in the Chapter Modal to display the chapter’s name.
- **Notes**: Returns an empty string if not set, so the frontend should handle this case.

### 9. `chapterImage()`
**ABI**:
```json
{
  "constant": true,
  "inputs": [],
  "name": "chapterImage",
  "outputs": [{ "name": "", "type": "string" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0x17f4e7e1"
}
```
**Behavior**:
- Returns the chapter’s image URL as a string.
- **Frontend Usage**: Used in the Chapter Modal to display the chapter image, clickable by the elect to open the Chapter Profile Modal.
- **Notes**: Ensure the URL is valid for display; fallback to a placeholder if empty.

### 10. `elect()`
**ABI**:
```json
{
  "constant": true,
  "inputs": [],
  "name": "elect",
  "outputs": [{ "name": "", "type": "address" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0x7bd955f3"
}
```
**Behavior**:
- Returns the address of the chapter’s `elect`.
- **Frontend Usage**: Used in the Chapter Modal to check if the connected user is the elect, enabling/disabling buttons like New Post or Profile access.
- **Notes**: Critical for access control in the frontend UI.

### 11. `nextFeeInSeconds()`
**ABI**:
```json
{
  "constant": true,
  "inputs": [],
  "name": "nextFeeInSeconds",
  "outputs": [
    { "name": "", "type": "uint256" },
    { "name": "", "type": "uint256" },
    { "name": "", "type": "uint256" }
  ],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0xa0fb5d94"
}
```
**Behavior**:
- Returns the time until the next billing cycle in seconds, minutes, and hours. Returns (0, 0, 0) if fees are due or not set.
- **Frontend Usage**: Used in the Chapter Modal and Chapter Profile Modal to display the next fee timestamp and calculate pending fees.
- **Notes**: The frontend should parse the timestamp into a user-friendly format (e.g., `yy/mm/dd/hh/mm/ss`).

### 12. `getActiveHearersCount()`
**ABI**:
```json
{
  "constant": true,
  "inputs": [],
  "name": "getActiveHearersCount",
  "outputs": [{ "name": "", "type": "uint256" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0xfbd7c9d8"
}
```
**Behavior**:
- Returns the number of active hearers (with `status = true`) in the chapter.
- **Frontend Usage**: Used in the Chapter Modal to display hearer count and calculate cycle profit (`hearer count * chapterFee`).
- **Notes**: Combine with `chapterFee` to show potential earnings.

### 13. `chapterFee()`
**ABI**:
```json
{
  "constant": true,
  "inputs": [],
  "name": "chapterFee",
  "outputs": [{ "name": "", "type": "uint256" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0x84f0f15a"
}
```
**Behavior**:
- Returns the chapter’s fee amount in wei (token-specific decimals).
- **Frontend Usage**: Used in the Chapter Modal to calculate cycle profit and in the Chapter Creation Modal to set the fee.
- **Notes**: Convert to human-readable format using the token’s decimals.

### 14. `lumenHeight()`
**ABI**:
```json
{
  "constant": true,
  "inputs": [],
  "name": "lumenHeight",
  "outputs": [{ "name": "", "type": "uint256" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0xf4d87851"
}
```
**Behavior**:
- Returns the total number of lumens (posts) in the chapter.
- **Frontend Usage**: Used in the Chapter Post Modal to determine the range of lumens to fetch.
- **Notes**: Subtract 1 for indexing (starts at 0) when querying `getLumen`.

### 15. `getLumen(uint256 index)`
**ABI**:
```json
{
  "constant": true,
  "inputs": [{ "name": "index", "type": "uint256" }],
  "name": "getLumen",
  "outputs": [
    { "name": "", "type": "string" },
    { "name": "", "type": "uint256" },
    { "name": "", "type": "uint256" },
    { "name": "", "type": "uint256" }
  ],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0x2a642480"
}
```
**Behavior**:
- Returns the `dataEntry`, `cycle`, `index`, and `timestamp` of the lumen at the specified `index`.
- **Frontend Usage**: Used in the Chapter Post Modal and User Feed Modal to fetch and display post content, decrypting if necessary.
- **Notes**: Check if `dataEntry` is "0" for unencrypted posts; otherwise, decrypt using `historicalKeys`.

### 16. `historicalKeys(address, uint256)`
**ABI**:
```json
{
  "constant": true,
  "inputs": [
    { "name": "", "type": "address" },
    { "name": "", "type": "uint256" }
  ],
  "name": "historicalKeys",
  "outputs": [{ "name": "", "type": "string" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0xaec25182"
}
```
**Behavior**:
- Returns the `ownKey` for a hearer at a specific cycle, used for decrypting lumens.
- **Frontend Usage**: Used in the Chapter Post Modal to fetch keys for decryption.
- **Notes**: If the key is "0" or the hearer’s `ownCycle` is behind, display an error message.

### 17. `isHearer(address hearer)`
**ABI**:
```json
{
  "constant": true,
  "inputs": [{ "name": "hearer", "type": "address" }],
  "name": "isHearer",
  "outputs": [
    { "name": "", "type": "address" },
    { "name": "", "type": "string" },
    { "name": "", "type": "uint256" },
    { "name": "", "type": "bool" }
  ],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0x88302aac"
}
```
**Behavior**:
- Returns the hearer’s address, `ownKey`, `ownCycle`, and `status`.
- Reverts if the hearer is not found.
- **Frontend Usage**: Used in the Chapter Modal to check subscription status and in the Chapter Post Modal to verify key availability.
- **Notes**: Handle reversion gracefully in the frontend by assuming non-subscribed status.

### 18. `getCellHearers(uint256 cellIndex)`
**ABI**:
```json
{
  "constant": true,
  "inputs": [{ "name": "cellIndex", "type": "uint256" }],
  "name": "getCellHearers",
  "outputs": [{ "name": "", "type": "address[]" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0x56551822"
}
```
**Behavior**:
- Returns an array of hearer addresses in the specified `cellIndex` (up to 100 hearers).
- **Frontend Usage**: Used in the Chapter Profile Modal to fetch hearers for key encryption during billing.
- **Notes**: Ensure `cellIndex` is valid (less than `getCellHeight`) to avoid reversion.

### 19. `getCellHeight()`
**ABI**:
```json
{
  "constant": true,
  "inputs": [],
  "name": "getCellHeight",
  "outputs": [{ "name": "", "type": "uint256" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0x2c5b8b7b"
}
```
**Behavior**:
- Returns the number of cells (groups of 100 hearers, rounded up).
- **Frontend Usage**: Used in the Chapter Profile Modal to determine the last cell for billing.
- **Notes**: Starts counting from 1, but `getCellHearers` uses 0-based indexing.

### 20. `getLaggards()`
**ABI**:
```json
{
  "constant": true,
  "inputs": [],
  "name": "getLaggards",
  "outputs": [{ "name": "", "type": "address[]" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0xdee324c5"
}
```
**Behavior**:
- Returns an array of active hearers whose `ownCycle` is behind `chapterCycle`.
- **Frontend Usage**: Used in the Chapter Profile Modal to display laggard count and enable billing via `billAndSet`.
- **Notes**: Cache addresses locally to avoid repeated queries.

### 21. `cycleKey(uint256)`
**ABI**:
```json
{
  "constant": true,
  "inputs": [{ "name": "", "type": "uint256" }],
  "name": "cycleKey",
  "outputs": [{ "name": "", "type": "string" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0xa4f91194"
}
```
**Behavior**:
- Returns the encrypted cycle key for a given cycle index.
- **Frontend Usage**: Used in the Chapter Profile Modal to decrypt keys for laggard billing.
- **Notes**: Requires decryption with the elect’s private key.

### 22. `chapterCycle()`
**ABI**:
```json
{
  "constant": true,
  "inputs": [],
  "name": "chapterCycle",
  "outputs": [{ "name": "", "type": "uint256" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0x6f617672"
}
```
**Behavior**:
- Returns the current official cycle of the chapter.
- **Frontend Usage**: Used in the Chapter Profile Modal to check billing status.
- **Notes**: Compare with `pendingCycle` to detect ongoing billing.

### 23. `pendingCycle()`
**ABI**:
```json
{
  "constant": true,
  "inputs": [],
  "name": "pendingCycle",
  "outputs": [{ "name": "", "type": "uint256" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0xa155285f"
}
```
**Behavior**:
- Returns the unofficial cycle number during billing, finalized as `chapterCycle` when the highest cell is billed.
- **Frontend Usage**: Used in the Chapter Profile Modal to track billing progress.
- **Notes**: Helps detect if billing is in progress.

### 24. `reElect(address newElect)`
**ABI**:
```json
{
  "constant": false,
  "inputs": [{ "name": "newElect", "type": "address" }],
  "name": "reElect",
  "outputs": [],
  "payable": false,
  "stateMutability": "nonpayable",
  "type": "function",
  "signature": "0xfc7be2b2"
}
```
**Behavior**:
- Changes the chapter’s `elect` to `newElect`.
- Only callable by the current `elect`.
- **Frontend Usage**: Used in the Chapter Profile Modal to update the elect address, with a confirmation popup.
- **Notes**: Validate the new address to prevent setting to `address(0)`.

---

## LightSource.sol Functions

### 1. `claim(address token)`
**ABI**:
```json
{
  "constant": false,
  "inputs": [{ "name": "token", "type": "address" }],
  "name": "claim",
  "outputs": [],
  "payable": false,
  "stateMutability": "nonpayable",
  "type": "function",
  "signature": "0x1e83409a"
}
```
**Behavior**:
- Transfers 0.01 LUX (1e16 wei for 18 decimals) to the caller if they haven’t claimed before and the contract has sufficient balance.
- Uses non-reentrant protection to prevent reentrancy attacks.
- **Frontend Usage**: Called in the Light Source Modal to distribute LUX tokens to users.
- **Notes**: Check the contract’s balance before enabling the button to avoid failed transactions.

---

## luminaryToken.sol Functions

### 1. `claimReward()`
**ABI**:
```json
{
  "constant": false,
  "inputs": [],
  "name": "claimReward",
  "outputs": [],
  "payable": false,
  "stateMutability": "nonpayable",
  "type": "function",
  "signature": "0xb88a802f"
}
```
**Behavior**:
- Allows the caller to claim 25% of their current LUX balance as a reward if eligible (30 days since last claim) and the contract has sufficient balance.
- Updates `rewardEligibility` to the current timestamp.
- **Frontend Usage**: Used in the Chapter Profile Modal’s Rewards section to claim user rewards.
- **Notes**: Check eligibility and contract balance before enabling the button.

### 2. `mintRewards()`
**ABI**:
```json
{
  "constant": false,
  "inputs": [],
  "name": "mintRewards",
  "outputs": [],
  "payable": false,
  "stateMutability": "nonpayable",
  "type": "function",
  "signature": "0x234cb051"
}
```
**Behavior**:
- Mints 25% of the current LUX supply to the contract if `swapCount > swapThreshold` (500).
- Resets `swapCount` to 0.
- **Frontend Usage**: Used in the Chapter Profile Modal when `swapThreshold - swapCount = 0` to trigger minting.
- **Notes**: Monitor `swapCount` to enable the button only when the threshold is met.

### 3. `rewardEligibility(address)`
**ABI**:
```json
{
  "constant": true,
  "inputs": [{ "name": "", "type": "address" }],
  "name": "rewardEligibility",
  "outputs": [{ "name": "", "type": "uint256" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0xfcec6769"
}
```
**Behavior**:
- Returns the timestamp when the address is next eligible to claim rewards.
- **Frontend Usage**: Used in the Chapter Profile Modal to check reward eligibility.
- **Notes**: Compare with current timestamp to determine if the Claim button should be enabled.

### 4. `swapCount()`
**ABI**:
```json
{
  "constant": true,
  "inputs": [],
  "name": "swapCount",
  "outputs": [{ "name": "", "type": "uint256" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0x2eff0d9e"
}
```
**Behavior**:
- Returns the current number of large transfers (above 0.01% of supply) that contribute to reaching `swapThreshold`.
- **Frontend Usage**: Used in the Chapter Profile Modal to calculate `swapThreshold - swapCount`.
- **Notes**: Update the UI dynamically as `swapCount` changes.

### 5. `swapThreshold()`
**ABI**:
```json
{
  "constant": true,
  "inputs": [],
  "name": "swapThreshold",
  "outputs": [{ "name": "", "type": "uint256" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0x0445b667"
}
```
**Behavior**:
- Returns the fixed threshold (500) for triggering `mintRewards`.
- **Frontend Usage**: Used in the Chapter Profile Modal to display the reward minting counter.
- **Notes**: Hardcoded to 500, so no need to query dynamically after initial fetch.

### 6. `approve(address spender, uint256 amount)`
**ABI** (from IERC20):
```json
{
  "constant": false,
  "inputs": [
    { "name": "spender", "type": "address" },
    { "name": "amount", "type": "uint256" }
  ],
  "name": "approve",
  "outputs": [{ "name": "", "type": "bool" }],
  "payable": false,
  "stateMutability": "nonpayable",
  "type": "function",
  "signature": "0x095ea7b3"
}
```
**Behavior**:
- Approves the `spender` (chapter contract) to spend `amount` of LUX tokens on behalf of the caller.
- **Frontend Usage**: Called in the Chapter Modal’s Subscribe button to approve the chapter fee before calling `hear`.
- **Notes**: Ensure the amount matches `cyclesToHear * chapterFee`.

### 7. `balanceOf(address account)`
**ABI** (from IERC20):
```json
{
  "constant": true,
  "inputs": [{ "name": "account", "type": "address" }],
  "name": "balanceOf",
  "outputs": [{ "name": "", "type": "uint256" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0x70a08231"
}
```
**Behavior**:
- Returns the LUX token balance of the specified `account`.
- **Frontend Usage**: Used in the Chapter Profile Modal to calculate rewards and in the Light Source Modal to check the contract’s balance.
- **Notes**: Convert to human-readable format using 18 decimals.

### 8. `symbol()`
**ABI** (from IERC20):
```json
{
  "constant": true,
  "inputs": [],
  "name": "symbol",
  "outputs": [{ "name": "", "type": "string" }],
  "payable": false,
  "stateMutability": "view",
  "type": "function",
  "signature": "0x95d89b41"
}
```
**Behavior**:
- Returns the token’s symbol (e.g., "LUX").
- **Frontend Usage**: Used in the Chapter Modal to display the ticker symbol for fees and profits.
- **Notes**: Cache the symbol to reduce contract calls.

---

## immateriumFactory.sol Functions

### 1. `deployChapter(address elect, uint256 feeInterval, uint256 chapterFee, address chapterToken)`
**ABI**:
```json
{
  "constant": false,
  "inputs": [
    { "name": "elect", "type": "address" },
    { "name": "feeInterval", "type": "uint256" },
    { "name": "chapterFee", "type": "uint256" },
    { "name": "chapterToken", "type": "address" }
  ],
  "name": "deployChapter",
  "outputs": [],
  "payable": false,
  "stateMutability": "nonpayable",
  "type": "function",
  "signature": "0x4e6e8e75"
}
```
**Behavior**:
- Deploys a new chapter via the `chapterLogic` contract, configures it with the provided `elect`, `feeInterval`, `chapterFee`, and `chapterToken`, and sets the `chapterMapper` if available.
- Emits a `ChapterDeployed` event with the new chapter’s address.
- **Frontend Usage**: Called in the Chapter Creation Modal to deploy a new chapter, followed by opening the Chapter Modal for the new address.
- **Notes**: Parse `feeInterval` and `chapterFee` correctly in the frontend, and listen for the `ChapterDeployed` event to get the new address.

---

## Concerns and Recommendations

1. **Typo in Timestamp Format**:
   - The specs use "HH/MM" instead of "HH:MM" for time formatting. **Recommendation**: Correct to "HH:MM" in the Chapter Post Modal for clarity.
2. **Network Handling**:
   - Allowing incorrect networks risks failed transactions. **Recommendation**: display a persistent warning.
3. **Input Validation**:
   - Lack of validation for `Fee Amount` and `Fee Interval`. **Recommendation**: Add checks for positive numbers and valid token decimals.
4. **Encryption Key Specificity**:
   - The `pureCycleKey` character set is undefined. **Recommendation**: Use `[A-Za-z0-9]` for 6 characters and document this in the frontend.
5. **Performance Issues**:
   - Fetching 10 lumens per chapter in the User Feed Modal could be slow. **Recommendation**: Limit to 2 lumens initially with pagination.
6. **ImgBB Integration**:
   - No error handling for ImgBB API failures. **Recommendation**: Implement retry logic and user feedback for failed uploads.
7. **Notification Polling**:
   - Minute-by-minute polling is inefficient. **Recommendation**: Use variable interval of 1 to 10 minutes.

---

## Testnet Addresses
- **Factory**: `0xAbd617983DCE1571D71cCC0F6C167cd72E8b9be7`
- **LUX**: `0x9749156E590d0a8689Bc30F108773D7509D48A84`
- **ChapterMapper**: `0x6E36C9b901fcc6bA468AccA471C805D67e6AAfb8`
- **ChapterLogic**: `0x16631154248F6557aA1278A0B65cB56EEc6b3771`
- **LightSource**: `0x0a8a210aff1171da29d151a0bb6af8ef2360d170`
- **Sample Chapter**: `0x711491cfb400b3b7bfc42cedbb821f637195029e`

---

This document provides the necessary ABIs and explanations to implement the Immaterium frontend while addressing potential issues in the specifications. Use Sonic Scan (`https://testnet.sonicscan.org`) for additional contract details and ensure robust error handling in the frontend implementation.
