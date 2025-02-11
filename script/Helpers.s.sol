// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";

abstract contract CodeConstants {
    address public ANVIL_CONTRACT_CREATOR = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    address public constant BASE_SEPOLIA_CONTRACT_CREATOR = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; //Change for each network

    uint256 public constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract Helpers is Script {
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
