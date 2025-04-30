// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.1;

/*
 * immateriumFactory.sol
 * version 0.0.3:
 * - Initial implementation with LUX token, chapterLibrary, and validChapters mapping.
 * - deployChapter uses external chapterLibrary call with helper functions.
 * - Ownable imported, deployer set as initial owner.
 * - Event emitted on chapter deployment.
 * - Updated _storeChapter to store all deployed chapters in validChapters without LUX check.
 * - Added addressOfChapterMapper state variable, setAddressOfChapterMapper function, and updated deployChapter to set chapterMapper.
 * - Removed salt parameter from deployChapter; salt now generated internally using keccak256 with timestamp, sender, and nonce.
 * - Added nonce state variable for unique salt generation.
 */

import "./imports/Ownable.sol";

contract immateriumFactory is Ownable {
    address public LUX;
    address public chapterLibrary;
    address public addressOfChapterMapper;
    mapping(address => bool) public validChapters;
    uint256 private nonce; // Tracks deployments for unique salt generation

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

    // Helper: Store chapter
    function _storeChapter(address chapter) private {
        validChapters[chapter] = true;
    }

    function setLux(address lux) external onlyOwner {
        LUX = lux;
    }

    function setChapterLibrary(address library_) external onlyOwner {
        chapterLibrary = library_;
    }

    function setAddressOfChapterMapper(address mapper) external onlyOwner {
        addressOfChapterMapper = mapper;
    }

    function deployChapter(
        address elect,
        uint256 feeInterval,
        uint256 chapterFee,
        address chapterToken
    ) external {
        require(chapterLibrary != address(0), "Library not set");

        // Generate salt using timestamp, sender, and nonce
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce));
        nonce = nonce + 1; // Increment nonce for next deployment

        address chapter = _deployChapterViaLibrary(salt);
        _configureChapter(chapter, elect, feeInterval, chapterFee, chapterToken);
        _storeChapter(chapter);

        if (addressOfChapterMapper != address(0)) {
            (bool success, ) = chapter.call(
                abi.encodeWithSignature("setChapterMapper(address)", addressOfChapterMapper)
            );
            require(success, "setChapterMapper failed");
        }

        emit ChapterDeployed(chapter, salt);
    }
}