// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.1;

/*
 * immateriumChapter.sol
 * version 0.1.13:
 * - Added getCellHearers view function to return hearer addresses in a cell by index order.
 * - Modified nextCycleBill to use pendingCycle for cycle tracking, only updating chapterCycle and nextFee when the highest cell is billed.
 * - Added hearer eligibility check in nextCycleBill to skip hearers with ownCycle >= chapterCycle, emitting BillingFailed for ineligible hearers.
 * - Previous changes:
 *   - Added getLaggards view function to return addresses of active hearers with ownCycle < chapterCycle.
 *   - Modified nextCycleBill to mark unbilled hearers as inactive and call _cleanInactiveHearers after billing and key updates.
 *   - Modified searchHearers to remove 1k iteration limit, iterating entire hearers array.
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
    function hear() external;
    function silence() external;
    function luminate(string calldata dataEntry) external;
    function reElect(address newElect) external;
    function changeFee(uint256 newFee) external;
    function setElect(address elect) external;
    function setFeeInterval(uint256 interval) external;
    function setChapterFee(uint256 fee) external;
    function setChapterToken(address token) external;
    function setChapterMapper(address mapper) external;
    function addChapterImage(string calldata image) external;
    function addChapterName(string calldata name) external;
    function billAndSet(address hearer, string calldata cycleIndexes, string calldata ownKeys) external;
    function nextCycleBill(string calldata key, uint256 cellIndex, string calldata ownKeys) external;
    function searchHearers() external view returns (address[] memory, uint256[] memory);
    function isHearer(address hearer) external view returns (address, string memory, uint256, bool);
    function getLumen(uint256 index) external view returns (string memory, uint256, uint256, uint256);
    function getActiveHearersCount() external view returns (uint256);
    function nextFeeInSeconds() external view returns (uint256, uint256, uint256);
    function getCellHeight() external view returns (uint256);
    function getCellHearerCount(uint256 cellIndex) external view returns (uint256);
    function getLaggards() external view returns (address[] memory);
    function getCellHearers(uint256 cellIndex) external view returns (address[] memory);
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
    uint256 public pendingCycle; // Tracks unofficial cycle until highest cell is billed
    uint256 public chapterFee;
    uint256 public nextFee;
    address public chapterToken;
    address public chapterMapper;
    uint256 public lastCycleVolume;
    uint256 public totalVolume;
    string public chapterName;
    string public chapterImage;
    uint256 public lumenHeight;

    Hearer[] public hearers;
    Lumen[] public lumens;
    string[] public cycleKey;
    mapping(string => Hearer) public oldKeys;
    mapping(address => mapping(uint256 => string)) public historicalKeys;

    bool private electSet;
    bool private feeIntervalSet;
    bool private chapterFeeSet;
    bool private chapterTokenSet;
    bool private chapterMapperSet;

    event BillingFailed(address hearer, string reason);
    event KeyUpdated(address hearer, string newKey);
    event KeyUpdateFailed(address hearer, string reason);

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

    // Helper: Charge fee
    function _chargeHearer(uint256 index) private returns (bool) {
        Hearer storage hearer = hearers[index];
        if (!hearer.status) {
            emit BillingFailed(hearer.hearerAddress, "Inactive hearer");
            return false;
        }
        if (hearer.ownCycle >= chapterCycle) {
            emit BillingFailed(hearer.hearerAddress, "Hearer cycle not behind chapter cycle");
            return false;
        }
        if (IERC20(chapterToken).allowance(hearer.hearerAddress, address(this)) < chapterFee) {
            emit BillingFailed(hearer.hearerAddress, "Insufficient allowance");
            hearer.status = false;
            return false;
        }
        if (IERC20(chapterToken).balanceOf(hearer.hearerAddress) < chapterFee) {
            emit BillingFailed(hearer.hearerAddress, "Insufficient balance");
            hearer.status = false;
            return false;
        }
        try IERC20(chapterToken).transferFrom(hearer.hearerAddress, elect, chapterFee) returns (bool success) {
            if (success) {
                lastCycleVolume += chapterFee;
                totalVolume += chapterFee;
                return true;
            } else {
                emit BillingFailed(hearer.hearerAddress, "Transfer failed");
                hearer.status = false;
                return false;
            }
        } catch {
            emit BillingFailed(hearer.hearerAddress, "Transfer failed");
            hearer.status = false;
            return false;
        }
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

    function hear() external override {
        hearers.push(Hearer(msg.sender, "", 1, true));
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

    function changeFee(uint256 newFee) external override electOnly {
        require(nextFee == 0 || nextFee <= block.timestamp, "Fees not due");
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

    function nextCycleBill(string calldata key, uint256 cellIndex, string calldata ownKeys) external override electOnly {
        if (nextFee != 0 && nextFee > block.timestamp) {
            emit KeyUpdateFailed(address(0), "Fees not due");
            return;
        }

        uint256 cellHeight = (hearers.length + 99) / 100;
        if (hearers.length == 0 && cellIndex != 0) {
            emit KeyUpdateFailed(address(0), "Invalid cell index");
            return;
        }
        if (hearers.length > 0 && cellIndex >= cellHeight) {
            emit KeyUpdateFailed(address(0), "Invalid cell index");
            return;
        }

        pendingCycle++; // Increment pending cycle
        cycleKey.push(key);

        if (hearers.length > 0) {
            lastCycleVolume = 0;
            uint256 startIndex = cellIndex * 100;
            uint256 endIndex = startIndex + 100 > hearers.length ? hearers.length : startIndex + 100;

            // Bill hearers in the cell and mark unbilled as inactive
            for (uint256 i = startIndex; i < endIndex; i++) {
                if (hearers[i].status) {
                    _chargeHearer(i); // Marks hearer inactive if billing fails or cycle ineligible
                }
            }

            // Update keys for active hearers in the cell
            string[] memory parsedKeys = _parseOwnKeys(ownKeys);
            uint256 activeCount = 0;

            for (uint256 i = startIndex; i < endIndex; i++) {
                if (hearers[i].status) {
                    activeCount++;
                }
            }

            if (parsedKeys.length != activeCount) {
                emit KeyUpdateFailed(address(0), "Mismatched ownKeys count");
            } else {
                uint256 keyIndex = 0;
                for (uint256 i = startIndex; i < endIndex && keyIndex < parsedKeys.length; i++) {
                    if (hearers[i].status) {
                        Hearer storage hearer = hearers[i];
                        oldKeys[hearer.ownKey] = Hearer(hearer.hearerAddress, hearer.ownKey, hearer.ownCycle, false);
                        historicalKeys[hearer.hearerAddress][hearer.ownCycle] = hearer.ownKey;
                        hearer.ownKey = parsedKeys[keyIndex];
                        hearer.ownCycle = pendingCycle; // Use pendingCycle for hearer updates
                        emit KeyUpdated(hearer.hearerAddress, hearer.ownKey);
                        keyIndex++;
                    }
                }
            }

            _cleanInactiveHearers();

            // Finalize cycle and fee only for the highest cell
            if (cellIndex == cellHeight - 1) {
                chapterCycle = pendingCycle;
                nextFee = block.timestamp + feeInterval;
            }
        }
    }

    function billAndSet(address hearer, string calldata cycleIndexes, string calldata ownKeys) external override electOnly {
        uint256 hearerIndex = type(uint256).max;
        for (uint256 i = 0; i < hearers.length; i++) {
            if (hearers[i].hearerAddress == hearer && hearers[i].status) {
                hearerIndex = i;
                break;
            }
        }
        if (hearerIndex == type(uint256).max) {
            emit BillingFailed(hearer, "Not an active hearer");
            return;
        }

        Hearer storage h = hearers[hearerIndex];
        if (h.ownCycle >= chapterCycle) {
            emit BillingFailed(hearer, "Hearer cycle not behind chapter cycle");
            return;
        }

        // Validate and update keys before billing
        uint256[] memory parsedIndexes = _parseIndexes(cycleIndexes);
        string[] memory parsedKeys = _parseOwnKeys(ownKeys);
        if (parsedIndexes.length != parsedKeys.length) {
            emit KeyUpdateFailed(hearer, "Mismatched indexes and keys");
            return;
        }

        // Validate cycle indexes and find max
        uint256 maxCycleIndex = 0;
        for (uint256 i = 0; i < parsedIndexes.length; i++) {
            if (parsedIndexes[i] < 1) {
                emit KeyUpdateFailed(hearer, "Cycle index must be at least 1");
                return;
            }
            if (parsedIndexes[i] > chapterCycle) {
                emit KeyUpdateFailed(hearer, "Cycle index exceeds chapter cycle");
                return;
            }
            if (parsedIndexes[i] > maxCycleIndex) {
                maxCycleIndex = parsedIndexes[i];
            }
        }

        // Update keys
        oldKeys[h.ownKey] = Hearer(h.hearerAddress, h.ownKey, h.ownCycle, false);
        historicalKeys[h.hearerAddress][h.ownCycle] = h.ownKey;

        string memory maxCycleKey = "";
        for (uint256 i = 0; i < parsedIndexes.length; i++) {
            historicalKeys[hearer][parsedIndexes[i]] = parsedKeys[i];
            oldKeys[parsedKeys[i]] = Hearer(hearer, parsedKeys[i], parsedIndexes[i], false);
            if (parsedIndexes[i] == maxCycleIndex) {
                maxCycleKey = parsedKeys[i];
            }
        }

        // Bill hearer only after successful key updates
        if (!_chargeHearer(hearerIndex)) {
            return; // Error emitted in _chargeHearer
        }

        h.ownCycle = maxCycleIndex;
        if (bytes(maxCycleKey).length > 0) {
            h.ownKey = maxCycleKey;
        }
        emit KeyUpdated(hearer, h.ownKey);
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
        for (uint256 i = 0; i < hearers.length; i++) {
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
        for (uint256 i = 0; i < hearers.length && j < count; i++) {
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

    function nextFeeInSeconds() external view override returns (uint256, uint256, uint256) {
        if (nextFee <= block.timestamp || nextFee == 0) {
            return (0, 0, 0);
        }
        uint256 secondsLeft = nextFee - block.timestamp;
        uint256 minutesLeft = secondsLeft / 60;
        uint256 hoursLeft = secondsLeft / 3600;
        return (secondsLeft, minutesLeft, hoursLeft);
    }

    function getCellHeight() external view override returns (uint256) {
        return (hearers.length + 99) / 100;
    }

    function getCellHearerCount(uint256 cellIndex) external view override returns (uint256) {
        uint256 cellHeight = (hearers.length + 99) / 100;
        if (cellIndex >= cellHeight) {
            return 0;
        }
        uint256 startIndex = cellIndex * 100;
        uint256 endIndex = startIndex + 100 > hearers.length ? hearers.length : startIndex + 100;
        return endIndex - startIndex;
    }

    function getLaggards() external view override returns (address[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < hearers.length; i++) {
            if (hearers[i].status && hearers[i].ownCycle < chapterCycle) {
                count++;
            }
        }

        address[] memory lagging = new address[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < hearers.length && j < count; i++) {
            if (hearers[i].status && hearers[i].ownCycle < chapterCycle) {
                lagging[j] = hearers[i].hearerAddress;
                j++;
            }
        }
        return lagging;
    }

    function getCellHearers(uint256 cellIndex) external view override returns (address[] memory) {
        uint256 cellHeight = (hearers.length + 99) / 100;
        if (cellIndex >= cellHeight) {
            revert("Invalid cell index");
        }
        uint256 startIndex = cellIndex * 100;
        uint256 endIndex = startIndex + 100 > hearers.length ? hearers.length : startIndex + 100;
        uint256 count = endIndex - startIndex;

        address[] memory cellHearers = new address[](count);
        for (uint256 i = startIndex; i < endIndex; i++) {
            cellHearers[i - startIndex] = hearers[i].hearerAddress;
        }
        return cellHearers;
    }
}