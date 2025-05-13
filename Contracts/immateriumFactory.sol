// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.1;

/*
 * immateriumFactory.sol
 * version 0.0.6:
 * - Renamed addressOfChapterMapper to chapterMapper in state variables, setAddressOfChapterMapper to setChapterMapper in interface and contract.
 * - Updated deployChapter to use setChapterMapper when setting chapterMapper on deployed chapter.
 */

import "./imports/Ownable.sol";
import "./immateriumChapter.sol";

interface IChapterLogic {
    function deploy(bytes32 salt) external returns (address);
}

interface IImmateriumFactory {
    function setLux(address lux) external;
    function setChapterLogic(address logic) external;
    function setChapterMapper(address mapper) external;
    function deployChapter(address elect, uint256 feeInterval, uint256 chapterFee, address chapterToken) external;
    function getChapterHeight() external view returns (uint256);
    function getChapterAtIndex(uint256 index) external view returns (address);
    function getAllChapters() external view returns (address[] memory);
}

contract immateriumFactory is Ownable {
    address public LUX;
    address public chapterLogic;
    address public chapterMapper;
    mapping(address => bool) public validChapters;
    uint256 public chapterHeight; // Tracks total number of chapters
    address[] public chapterList; // Indexes valid chapters
    uint256 private nonce; // Tracks deployments for unique salt generation

    event ChapterDeployed(address indexed chapter, bytes32 salt);

    // Helper: Deploy chapter via ChapterLogic
    function _deployChapterViaLogic(bytes32 salt) private returns (address) {
        (bool success, bytes memory data) = chapterLogic.call(
            abi.encodeWithSignature("deploy(bytes32)", salt)
        );
        require(success, "Chapter deployment failed");
        address chapter = abi.decode(data, (address));
        require(chapter != address(0), "Invalid chapter address");
        return chapter;
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

    // Helper: Store chapter and update indexing
    function _storeChapter(address chapter) private {
        validChapters[chapter] = true;
        chapterList.push(chapter);
        chapterHeight = chapterHeight + 1;
    }

    function setLux(address lux) external onlyOwner {
        LUX = lux;
    }

    function setChapterLogic(address logic) external onlyOwner {
        chapterLogic = logic;
    }

    function setChapterMapper(address mapper) external onlyOwner {
        chapterMapper = mapper;
    }

    function deployChapter(
        address elect,
        uint256 feeInterval,
        uint256 chapterFee,
        address chapterToken
    ) external {
        require(chapterLogic != address(0), "Logic not set");

        // Generate salt using timestamp, sender, and nonce
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce));
        nonce = nonce + 1; // Increment nonce for next deployment

        address chapter = _deployChapterViaLogic(salt);
        _configureChapter(chapter, elect, feeInterval, chapterFee, chapterToken);
        _storeChapter(chapter);

        if (chapterMapper != address(0)) {
            (bool success, ) = chapter.call(
                abi.encodeWithSignature("setChapterMapper(address)", chapterMapper)
            );
            require(success, "setChapterMapper failed");
        }

        emit ChapterDeployed(chapter, salt);
    }

    // Query: Get total number of chapters
    function getChapterHeight() external view returns (uint256) {
        return chapterHeight;
    }

    // Query: Get chapter address at index
    function getChapterAtIndex(uint256 index) external view returns (address) {
        require(index < chapterHeight, "Index out of bounds");
        return chapterList[index];
    }

    // Query: Get all chapter addresses
    function getAllChapters() external view returns (address[] memory) {
        return chapterList;
    }
}