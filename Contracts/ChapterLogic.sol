// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.1;

/*
 * ChapterLogic.sol
 * version 0.0.2:
 * - Initial implementation with deploy function for immateriumChapter deployment.
 * - Uses CREATE2 for deterministic addresses with bytes32 salt.
 * - Converted from library (chapterLibrary) to regular contract for deployment by immateriumFactory or others (April 30, 2025).
 */

import "./immateriumChapter.sol";

contract ChapterLogic {
    // Deploys a new immateriumChapter contract with deterministic address using CREATE2
    function deploy(bytes32 salt) external returns (address) {
        immateriumChapter newChapter = new immateriumChapter{salt: salt}();
        require(address(newChapter) != address(0), "Deployment failed");
        return address(newChapter);
    }
}