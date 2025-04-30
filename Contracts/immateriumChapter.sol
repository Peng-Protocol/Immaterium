// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.1;

/*
 * immateriumChapter.sol
 * version 0.0.6:
 * - Added require(chapterMapper != address(0)) in addChapterName to ensure mapper is set.
 * - Replaced chapterImage mapping with single string chapterImage for simpler querying.
 * - Removed verifyInst state variable for cleanup.
 * - Replaced chapterName mapping with single string chapterName for simpler querying.
 * - Updated addChapterName to set chapterName and call chapterMapper.addName.
 * - Added timestamp to Lumen struct and updated luminate to store timestamp via _getCurrentTimestamp.
 * - Updated getLumen to return timestamp and adjusted IimmateriumChapter interface.
 * - Added lumenHeight state variable to track total lumens, updated in luminate via _incrementLumenHeight.
 * - Fixed TypeError: Index range access not supported for bytes memory in _parseOwnKeys (lines 124, 130).
 * - Fixed TypeError: Explicit type conversion from bytes slice to string in _parseOwnKeys (lines 124, 130).
 * - Fixed TypeError: Wrong argument count for Hearer struct in _chargeHearer (line 164).
 * - Ensured explicit casting, no inline assembly, and compatibility with Solidity ^0.8.1.
 */

import "./imports/IERC20.sol";

interface IChapterMapper {
    function addChapter(address hearer, address chapter) external;
    function removeChapter(address hearer, address chapter) external;
    function getHearerChapters(address hearer) external view returns (address[] memory);
    function isHearerSubscribed(address hearer, address chapter) external view returns (bool);
    function addName(string calldata name, address chapter) external;
    function queryPartialName(string calldata query) external view returns (address[] memory, string[] memory);
    function queryExactName(string calldata name) external view returns (address, string memory);
}

interface IimmateriumChapter {
    function billFee(string calldata indexes, string calldata ownKeys) external;
    function hear() external;
    function silence() external;
    function luminate(string calldata dataEntry) external;
    function reElect(address newElect) external;
    function changeFee(string calldata indexes, string calldata ownKeys, uint256 newFee) external;
    function setElect(address elect) external;
    function setFeeInterval(uint256 interval) external;
    function setChapterFee(uint256 fee) external;
    function setChapterToken(address token) external;
    function setCycleKey(string calldata key) external;
    function setChapterMapper(address mapper) external;
    function addChapterImage(string calldata image) external;
    function addChapterName(string calldata name) external;
    function searchHearers() external view returns (address[] memory, uint256[] memory);
    function isHearer(address hearer) external view returns (address, string memory, uint256, bool);
    function getLumen(uint256 index) external view returns (string memory, uint256, uint256, uint256);
    function getActiveHearersCount() external view returns (uint256);
}

contract immateriumChapter is IimmateriumChapter {
    struct Hearer {
        address hearerAddress;
        string ownKey;
        uint256 ownCycle;
        bool status;
    }

    struct Lumen {
        string dataEntry;
        uint256 cycle;
        uint256 index;
        uint256 timestamp;
    }

    address public elect;
    uint256 public feeInterval;
    uint256 public chapterCycle;
    uint256 public chapterFee;
    uint256 public nextFee;
    address public chapterToken;
    address public chapterMapper;
    uint256 public lastCycleVolume;
    string public chapterName;
    string public chapterImage;
    uint256 public lumenHeight;

    Hearer[] public hearers;
    Lumen[] public lumens;
    string[] public cycleKey;
    mapping(string => Hearer) public oldKeys;

    bool private electSet;
    bool private feeIntervalSet;
    bool private chapterFeeSet;
    bool private chapterTokenSet;
    bool private chapterMapperSet;

    modifier electOnly() {
        require(msg.sender == elect, "electOnly");
        _;
    }

    // Helper: Parse comma-separated string to uint256 array
    function _parseIndexes(string memory indexes) private pure returns (uint256[] memory) {
        bytes memory indexBytes = bytes(indexes);
        uint256[] memory result = new uint256[](100);
        uint256 count = 0;
        uint256 temp = 0;

        for (uint256 i = 0; i < indexBytes.length && count < 100; i++) {
            if (indexBytes[i] == ",") {
                result[count] = temp;
                count++;
                temp = 0;
            } else {
                temp = temp * 10 + (uint8(indexBytes[i]) - 48);
            }
        }
        if (temp > 0 && count < 100) {
            result[count] = temp;
            count++;
        }

        uint256[] memory trimmed = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            trimmed[i] = result[i];
        }
        return trimmed;
    }

    // Helper: Extract substring from bytes
    function _substring(bytes memory data, uint256 start, uint256 end) private pure returns (string memory) {
        require(start <= end && end <= data.length, "Invalid substring range");
        uint256 len = end - start;
        bytes memory result = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = data[start + i];
        }
        return string(result);
    }

    // Helper: Parse comma-separated ownKeys string
    function _parseOwnKeys(string memory ownKeys) private pure returns (string[] memory) {
        bytes memory keyBytes = bytes(ownKeys);
        string[] memory result = new string[](100);
        uint256 count = 0;
        uint256 start = 0;

        for (uint256 i = 0; i < keyBytes.length && count < 100; i++) {
            if (keyBytes[i] == ",") {
                result[count] = _substring(keyBytes, start, i);
                count++;
                start = i + 1;
            }
        }
        if (start < keyBytes.length && count < 100) {
            result[count] = _substring(keyBytes, start, keyBytes.length);
            count++;
        }

        string[] memory trimmed = new string[](count);
        for (uint256 i = 0; i < count; i++) {
            trimmed[i] = result[i];
        }
        return trimmed;
    }

    // Helper: Charge fee and update hearer
    function _chargeHearer(uint256 index, string memory ownKey) private returns (bool) {
        Hearer storage hearer = hearers[index];
        if (
            hearer.status &&
            hearer.ownCycle < chapterCycle &&
            IERC20(chapterToken).allowance(hearer.hearerAddress, address(this)) >= chapterFee &&
            IERC20(chapterToken).balanceOf(hearer.hearerAddress) >= chapterFee
        ) {
            bool success = IERC20(chapterToken).transferFrom(hearer.hearerAddress, elect, chapterFee);
            if (success) {
                lastCycleVolume += chapterFee;
                oldKeys[hearer.ownKey] = Hearer(hearer.hearerAddress, hearer.ownKey, hearer.ownCycle, false);
                hearer.ownKey = ownKey;
                hearer.ownCycle = chapterCycle;
                return true;
            }
        }
        return false;
    }

    // Helper: Shift hearer entries to close gaps
    function _shiftHearers(uint256 startIndex) private {

        for (uint256 i = startIndex; i < hearers.length - 1; i++) {
            hearers[i] = hearers[i + 1];
        }
        hearers.pop();
    }

    // Helper: Clean inactive hearers
    function _cleanInactiveHearers() private {
        uint256 i = 0;
        while (i < hearers.length) {
            if (!hearers[i].status) {
                _shiftHearers(i);
            } else {
                i++;
            }
        }
    }

    // Helper: Get current timestamp
    function _getCurrentTimestamp() private view returns (uint256) {
        return block.timestamp;
    }

    // Helper: Increment lumenHeight
    function _incrementLumenHeight() private {
        lumenHeight = lumenHeight + 1;
    }

    function billFee(string calldata indexes, string calldata ownKeys) external override electOnly {
        require(nextFee == 0, "Fees not due");
        uint256[] memory parsedIndexes = _parseIndexes(indexes);
        string[] memory parsedKeys = _parseOwnKeys(ownKeys);
        require(parsedIndexes.length == parsedKeys.length, "Mismatched inputs");

        lastCycleVolume = 0;
        for (uint256 i = 0; i < parsedIndexes.length && i < 100; i++) {
            uint256 index = parsedIndexes[i];
            if (index < hearers.length) {
                _chargeHearer(index, parsedKeys[i]);
            }
        }

        _cleanInactiveHearers();
        nextFee = block.timestamp + feeInterval;
    }

    function hear() external override {
        require(IERC20(chapterToken).transferFrom(msg.sender, elect, chapterFee), "Fee transfer failed");
        hearers.push(Hearer(msg.sender, "", chapterCycle, true));
        if (chapterMapper != address(0)) {
            IChapterMapper(chapterMapper).addChapter(msg.sender, address(this));
        }
    }

    function silence() external override {
        for (uint256 i = 0; i < hearers.length; i++) {
            if (hearers[i].hearerAddress == msg.sender && hearers[i].status) {
                hearers[i].status = false;
                if (chapterMapper != address(0)) {
                    IChapterMapper(chapterMapper).removeChapter(msg.sender, address(this));
                }
                return;
            }
        }
        revert("Not a hearer");
    }

    function luminate(string calldata dataEntry) external override electOnly {
        lumens.push(Lumen(dataEntry, chapterCycle, lumens.length, _getCurrentTimestamp()));
        _incrementLumenHeight();
    }

    function reElect(address newElect) external override electOnly {
        elect = newElect;
    }

    function changeFee(string calldata indexes, string calldata ownKeys, uint256 newFee) external override electOnly {
        require(nextFee == 0, "Fees not due");
        chapterFee = newFee;
    }

    function setElect(address elect_) external override {
        require(!electSet, "Elect already set");
        elect = elect_;
        electSet = true;
    }

    function setFeeInterval(uint256 interval) external override {
        require(!feeIntervalSet, "Fee interval already set");
        feeInterval = interval;
        feeIntervalSet = true;
    }

    function setChapterFee(uint256 fee) external override {
        require(!chapterFeeSet, "Chapter fee already set");
        chapterFee = fee;
        chapterFeeSet = true;
    }

    function setChapterToken(address token) external override {
        require(!chapterTokenSet, "Chapter token already set");
        chapterToken = token;
        chapterTokenSet = true;
    }

    function setChapterMapper(address mapper) external override {
        require(!chapterMapperSet, "Chapter mapper already set");
        chapterMapper = mapper;
        chapterMapperSet = true;
    }

    function setCycleKey(string calldata key) external override electOnly {
        cycleKey.push(key);
        chapterCycle++;
    }

    function addChapterImage(string calldata image) external override electOnly {
        chapterImage = image;
    }

    function addChapterName(string calldata name) external override electOnly {
        require(chapterMapper != address(0), "ChapterMapper not set");
        chapterName = name;
        IChapterMapper(chapterMapper).addName(name, address(this));
    }

    function searchHearers() external view override returns (address[] memory, uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < hearers.length && i < 1000; i++) {
            if (
                hearers[i].status &&
                hearers[i].ownCycle < chapterCycle &&
                IERC20(chapterToken).allowance(hearers[i].hearerAddress, address(this)) >= chapterFee &&
                IERC20(chapterToken).balanceOf(hearers[i].hearerAddress) >= chapterFee
            ) {
                count++;
            }
        }

        address[] memory eligible = new address[](count);
        uint256[] memory cycles = new uint256[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < hearers.length && i < 1000 && j < count; i++) {
            if (
                hearers[i].status &&
                hearers[i].ownCycle < chapterCycle &&
                IERC20(chapterToken).allowance(hearers[i].hearerAddress, address(this)) >= chapterFee &&
                IERC20(chapterToken).balanceOf(hearers[i].hearerAddress) >= chapterFee
            ) {
                eligible[j] = hearers[i].hearerAddress;
                cycles[j] = hearers[i].ownCycle;
                j++;
            }
        }
        return (eligible, cycles);
    }

    function isHearer(address hearer) external view override returns (address, string memory, uint256, bool) {
        for (uint256 i = 0; i < hearers.length; i++) {
            if (hearers[i].hearerAddress == hearer) {
                return (
                    hearers[i].hearerAddress,
                    hearers[i].ownKey,
                    hearers[i].ownCycle,
                    hearers[i].status
                );
            }
        }
        revert("Not a hearer");
    }

    function getLumen(uint256 index) external view override returns (string memory, uint256, uint256, uint256) {
        require(index < lumens.length, "Invalid index");
        Lumen memory lumen = lumens[index];
        return (lumen.dataEntry, lumen.cycle, lumen.index, lumen.timestamp);
    }

    function getActiveHearersCount() external view override returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < hearers.length; i++) {
            if (hearers[i].status) {
                count++;
            }
        }
        return count;
    }
}