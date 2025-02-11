// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    uint8 private constant DECIMALS = 6;
    uint256 constant INITIAL_SUPPLY = 1000000 * 10 ** DECIMALS; // 1,000,000 USDC

    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, INITIAL_SUPPLY); //deal 1,000,000 USDC to the deployer
    }

    function mint(address to, uint256 value) public {
        _mint(to, value);
    }

    // Override decimals to use 6 decimals like USDC
    function decimals() public view virtual override returns (uint8) {
        return DECIMALS;
    }
}
