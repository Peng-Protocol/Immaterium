// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.1;

/*
 * immateriumFactory.sol
 * version 0.0.5:
 * - Added chapterHeight to track total number of deployed chapters.
 * - Added chapterList array for indexing valid chapters.
 * - Added query functions: getChapterHeight, getChapterAtIndex, getAllChapters.
 * - Updated _storeChapter to store chapters in chapterList and increment chapterHeight.
 * - Added IImmateriumFactory interface for type-safe external function declarations.
 * - Fixed typo in deployChapter: 'chapellect' corrected to 'elect'.
 * - Fixed deployChapter to call _configureChapter with all 5 required arguments.
 * - Previous changes (v0.0.4):
 *   - Initial implementation with LUX token, chapterLibrary, and validChapters mapping.
 *   - deployChapter uses external chapterLibrary call with helper functions.
 *   - Ownable imported, deployer set as initial owner.
 *   - Event emitted on chapter deployment.
 *   - Updated _storeChapter to store all deployed chapters in validChapters without LUX check.
 *   - Added addressOfChapterMapper state variable, setAddressOfChapterMapper function, and updated deployChapter to set chapterMapper.
 *   - Removed salt parameter from deployChapter; salt now generated internally using keccak256 with timestamp, sender, and nonce.
 *   - Added nonce state variable for unique salt generation.
 *   - Changed chapterLibrary to ChapterLogic (regular contract) for deploying immateriumChapter (April 30, 2025).
 *   - Renamed chapterLibrary to chapterLogic and setChapterLibrary to setChapterLogic.
 *   - Added IChapterLogic interface for type-safe calls to ChapterLogic.
 */

import "./imports/Ownable.sol";
import "./immateriumChapter.sol";

interface IChapterLogic {
    function deploy(bytes32 salt) external returns (address);
}

interface IImmateriumFactory {
    function setLux(address lux) external;
    function setChapterLogic(address logic) external;
    function setAddressOfChapterMapper(address mapper) external;
    function deployChapter(address elect, uint256 feeInterval, uint256 chapterFee, address chapterToken) external;
    function getChapterHeight() external view returns (uint256);
    function getChapterAtIndex(uint256 index) external view returns (address);
    function getAllChapters() external view returns (address[] memory);
}

contract immateriumFactory is Ownable {
    address public LUX;
    address public chapterLogic;
    address public addressOfChapterMapper;
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

    function setAddressOfChapterMapper(address mapper) external onlyOwner {
        addressOfChapterMapper = mapper;
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

        if (addressOfChapterMapper != address(0)) {
            (bool success, ) = chapter.call(
                abi.encodeWithSignature("setChapterMapper(address)", addressOfChapterMapper)
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