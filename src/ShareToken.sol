// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error ShareToken__NotFundManager();

/**
 * @title ShareToken
 * @dev An ERC20 token representing shares in the fund. It has 6 decimals.
 * The fund manager (settable by the owner) is allowed to mint and burn tokens.
 */
contract ShareToken is ERC20, Ownable {
    /// @notice The address allowed to mint and burn share tokens (i.e. the FundManager)
    address private s_fundManager;

    /// @dev Only the fund manager can call functions with this modifier.

    modifier onlyFundManager() {
        if (msg.sender != s_fundManager) {
            revert ShareToken__NotFundManager();
        }
        _;
    }

    /**
     * @dev Constructor.
     * @param name_ Token name.
     * @param symbol_ Token symbol.
     *
     * The Ownable constructor is called with the deployer’s address as the initial owner.
     */
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) Ownable(msg.sender) {}

    /**
     * @notice Set the fund manager address.
     * @param _fundManager The FundManager contract address.
     */
    function setFundManager(address _fundManager) external onlyOwner {
        require(_fundManager != address(0), "ShareToken: Zero address");
        s_fundManager = _fundManager;
    }

    /**
     * @notice Mint share tokens.
     * @param to The recipient address.
     * @param amount Amount to mint (in smallest units, 6 decimals).
     */
    function mint(address to, uint256 amount) external onlyFundManager {
        _mint(to, amount);
    }

    /**
     * @notice Burn share tokens from an account.
     * @param account The account whose tokens are burned.
     * @param amount Amount to burn.
     */
    function burnFrom(address account, uint256 amount) external onlyFundManager {
        _burn(account, amount);
    }

    /**
     * @notice Override decimals to return 6.
     */
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
