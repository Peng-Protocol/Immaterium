// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.1;

/*
 * chapterLibrary.sol
 * version : 0.0.1
 * - Initial implementation with deploy function for immateriumChapter deployment.
 * - Uses CREATE2 for deterministic addresses with bytes32 salt.
 */



import "./imports/immateriumChapter.sol";

library chapterLibrary {
    // Deploys a new immateriumChapter contract with deterministic address using CREATE2
    function deploy(bytes32 salt) external returns (address) {
        immateriumChapter newChapter = new immateriumChapter{salt: salt}();
        return address(newChapter);
    }
}