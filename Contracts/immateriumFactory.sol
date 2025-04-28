// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.1;

/*
 * immateriumFactory.sol
 * version 0.0.1 :
 * - Initial implementation with LUX token, chapterLibrary, and validChapters mapping.
 * - deployChapter uses external chapterLibrary call with helper functions.
 * - Ownable imported, deployer set as initial owner.
 * - Event emitted on chapter deployment.
 */



import "./imports/Ownable.sol";

contract immateriumFactory is Ownable {
    address public LUX;
    address public chapterLibrary;
    mapping(address => bool) public validChapters;

    event ChapterDeployed(address indexed chapter, bytes32 salt);

    // Helper: Deploy chapter via chapterLibrary
    function _deployChapterViaLibrary(bytes32 salt) private returns (address) {
        (bool success, bytes memory data) = chapterLibrary.call(
            abi.encodeWithSignature("deploy(bytes32)", salt)
        );
        require(success, "Chapter deployment failed");
        return abi.decode(data, (address));
    }

    // Helper: Configure chapter settings
    function _configureChapter(
        address chapter,
        address elect,
        uint256 feeInterval,
        uint256 chapterFee,
        address chapterToken
    ) private {
        (bool success, ) = chapter.call(
            abi.encodeWithSignature("setElect(address)", elect)
        );
        require(success, "setElect failed");

        (success, ) = chapter.call(
            abi.encodeWithSignature("setFeeInterval(uint256)", feeInterval)
        );
        require(success, "setFeeInterval failed");

        (success, ) = chapter.call(
            abi.encodeWithSignature("setChapterFee(uint256)", chapterFee)
        );
        require(success, "setChapterFee failed");

        (success, ) = chapter.call(
            abi.encodeWithSignature("setChapterToken(address)", chapterToken)
        );
        require(success, "setChapterToken failed");
    }

    // Helper: Validate and store chapter
    function _storeChapter(address chapter, address chapterToken) private {
        if (LUX != address(0) && chapterToken == LUX) {
            validChapters[chapter] = true;
        }
    }

    function setLux(address lux) external onlyOwner {
        LUX = lux;
    }

    function setChapterLibrary(address library_) external onlyOwner {
        chapterLibrary = library_;
    }

    function deployChapter(
        bytes32 salt,
        address elect,
        uint256 feeInterval,
        uint256 chapterFee,
        address chapterToken
    ) external {
        require(chapterLibrary != address(0), "Library not set");

        address chapter = _deployChapterViaLibrary(salt);
        _configureChapter(chapter, elect, feeInterval, chapterFee, chapterToken);
        _storeChapter(chapter, chapterToken);

        emit ChapterDeployed(chapter, salt);
    }
}