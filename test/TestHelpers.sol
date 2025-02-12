// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library TestHelpers {
    //convert uint256 to a decimal string

    function toString6(uint256 value) public pure returns (string memory) {
        return uintToStringWithDecimals(value, 6);
    }

    function toString18(uint256 value) public pure returns (string memory) {
        return uintToStringWithDecimals(value, 18);
    }

    function uintToStringWithDecimals(uint256 value, uint16 decimals) internal pure returns (string memory) {
        uint256 integerPart = value / 10 ** decimals;
        uint256 fractionalPart = value % 10 ** decimals;
        return string(abi.encodePacked(uintToString(integerPart), ".", fractionalPartToString(fractionalPart)));
    }

    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function fractionalPartToString(uint256 value) internal pure returns (string memory) {
        bytes memory buffer = new bytes(6);
        for (uint256 i = 0; i < 6; i++) {
            buffer[5 - i] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
