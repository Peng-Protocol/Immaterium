// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.1;

/*
 * chapterMapper.sol
 * version 0.0.1:
 * - Initial implementation of chapterMapper with hearerChapters mapping and helper function for updates.
 * - Added immateriumFactory state variable, setImmateriumFactory function, and restricted addChapter/removeChapter to hearer or valid chapters.
 * - Added getHearerChapters view function to return all chapters a hearer is subscribed to.
 * - Added isHearerSubscribed view function to check if a hearer is subscribed to a specific chapter.
 * - Optimized _updateHearerChapters to prevent duplicate chapter entries during add.
 * - Optimized isHearerSubscribed with a smaller iteration bound for gas efficiency.
 */

import "./imports/Ownable.sol";

interface IImmateriumFactory {
    function validChapters(address chapter) external view returns (bool);
}

interface IChapterMapper {
    function addChapter(address hearer, address chapter) external;
    function removeChapter(address hearer, address chapter) external;
    function getHearerChapters(address hearer) external view returns (address[] memory);
    function isHearerSubscribed(address hearer, address chapter) external view returns (bool);
}

contract chapterMapper is Ownable, IChapterMapper {
    mapping(address => address[]) public hearerChapters;
    address public immateriumFactory;
    bool private factorySet;

    // Helper: Update hearerChapters mapping
    function _updateHearerChapters(address hearer, address chapter, bool add) private {
        address[] storage chapters = hearerChapters[hearer];
        require(chapters.length < 1000, "Too many chapters");

        if (add) {
            // Check for duplicates
            for (uint256 i = 0; i < chapters.length; i++) {
                if (chapters[i] == chapter) {
                    return; // Chapter already exists
                }
            }
            chapters.push(chapter);
        } else {
            // Find and remove chapter
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
}