// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.1;

/*
 * chapterMapper.sol
 * version 0.0.7:
 * - Removed queryExactName and DebugQueryExactName; removed 1000 iteration limit in queryPartialName.
 * - Fixed syntax error in _isSubstring; corrected incomplete for loop to 'for (uint256 j = 0; j < queryBytes.length; j++)'.
 * - Removed elect check in addName to fix caller mismatch with addChapterName.
 * - Fixed reserved keyword 'match' in _isSubstring; replaced with 'isMatch'.
 * - Fixed invalid identifier 'duracion' in _isSubstring; replaced with 'bool isMatch = true'.
 * - Added ChapterName struct and chapterNames array to store chapter names and addresses.
 * - Added addName function with valid chapter verification.
 * - Added queryPartialName for name-based queries.
 * - Added _isSubstring helper for partial name matching without external libraries.
 * - Added ChapterNameAdded event for addName.
 * - Updated IChapterMapper interface with new functions.
 * - Optimized _updateHearerChapters to prevent duplicate chapter entries.
 * - Optimized isHearerSubscribed with a smaller iteration bound.
 */

import "./imports/Ownable.sol";

interface IImmateriumFactory {
    function validChapters(address chapter) external view returns (bool);
}

interface IimmateriumChapter {
    function elect() external view returns (address);
}

interface IChapterMapper {
    function addChapter(address hearer, address chapter) external;
    function removeChapter(address hearer, address chapter) external;
    function getHearerChapters(address hearer) external view returns (address[] memory);
    function isHearerSubscribed(address hearer, address chapter) external view returns (bool);
    function addName(string calldata name, address chapter) external;
    function queryPartialName(string calldata query) external view returns (address[] memory, string[] memory);
}

contract chapterMapper is Ownable, IChapterMapper {
    struct ChapterName {
        string name;
        address chapter;
    }

    mapping(address => address[]) public hearerChapters;
    address public immateriumFactory;
    ChapterName[] public chapterNames;
    bool private factorySet;

    event ChapterNameAdded(string name, address indexed chapter);

    // Helper: Update hearerChapters mapping
    function _updateHearerChapters(address hearer, address chapter, bool add) private {
        address[] storage chapters = hearerChapters[hearer];
        require(chapters.length < 1000, "Too many chapters");

        if (add) {
            for (uint256 i = 0; i < chapters.length; i++) {
                if (chapters[i] == chapter) {
                    return;
                }
            }
            chapters.push(chapter);
        } else {
            for (uint256 i = 0; i < chapters.length; i++) {
                if (chapters[i] == chapter) {
                    for (uint256 j = i; j < chapters.length - 1; j++) {
                        chapters[j] = chapters[j + 1];
                    }
                    chapters.pop();
                    return;
                }
            }
        }
    }

    // Helper: Check if query is a substring of target
    function _isSubstring(string memory query, string memory target) private pure returns (bool) {
        bytes memory queryBytes = bytes(query);
        bytes memory targetBytes = bytes(target);
        if (queryBytes.length == 0 || queryBytes.length > targetBytes.length) {
            return false;
        }

        for (uint256 i = 0; i <= targetBytes.length - queryBytes.length; i++) {
            bool isMatch = true;
            for (uint256 j = 0; j < queryBytes.length; j++) {
                if (targetBytes[i + j] != queryBytes[j]) {
                    isMatch = false;
                    break;
                }
            }
            if (isMatch) {
                return true;
            }
        }
        return false;
    }

    function setImmateriumFactory(address factory) external onlyOwner {
        immateriumFactory = factory;
        factorySet = true;
    }

    function addChapter(address hearer, address chapter) external override {
        require(
            msg.sender == hearer ||
            (factorySet && IImmateriumFactory(immateriumFactory).validChapters(msg.sender)),
            "Unauthorized"
        );
        _updateHearerChapters(hearer, chapter, true);
    }

    function removeChapter(address hearer, address chapter) external override {
        require(
            msg.sender == hearer ||
            (factorySet && IImmateriumFactory(immateriumFactory).validChapters(msg.sender)),
            "Unauthorized"
        );
        _updateHearerChapters(hearer, chapter, false);
    }

    function getHearerChapters(address hearer) external view override returns (address[] memory) {
        return hearerChapters[hearer];
    }

    function isHearerSubscribed(address hearer, address chapter) external view override returns (bool) {
        address[] memory chapters = hearerChapters[hearer];
        require(chapters.length <= 500, "Array too large");
        for (uint256 i = 0; i < chapters.length; i++) {
            if (chapters[i] == chapter) {
                return true;
            }
        }
        return false;
    }

    function addName(string calldata name, address chapter) external override {
        require(bytes(name).length > 0, "Empty name");
        require(chapter != address(0), "Invalid chapter");
        require(factorySet && IImmateriumFactory(immateriumFactory).validChapters(msg.sender), "Not a valid chapter");

        for (uint256 i = 0; i < chapterNames.length; i++) {
            require(
                keccak256(abi.encodePacked(chapterNames[i].name)) != keccak256(abi.encodePacked(name)) &&
                chapterNames[i].chapter != chapter,
                "Name or chapter already exists"
            );
        }

        chapterNames.push(ChapterName(name, chapter));
        emit ChapterNameAdded(name, chapter);
    }

    function queryPartialName(string calldata query) external view override returns (address[] memory, string[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < chapterNames.length; i++) {
            if (_isSubstring(query, chapterNames[i].name)) {
                count++;
            }
        }

        address[] memory chapters = new address[](count);
        string[] memory names = new string[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < chapterNames.length; i++) {
            if (_isSubstring(query, chapterNames[i].name)) {
                chapters[j] = chapterNames[i].chapter;
                names[j] = chapterNames[i].name;
                j++;
            }
        }
        return (chapters, names);
    }
}