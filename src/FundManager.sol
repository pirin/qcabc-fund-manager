/*
Create a solidity smart contract that will be used to manage the cap table of an investment fund. 
Here is the logic that the contract need to expose:

1. Contract will provide a way for users to deposit funds into the contract using "depositFunds" method.
    Deposits are done only in the form of a "deposit token", whose address will be specified during contract creation.
2. Contract will track the total number of "deposit tokens" sent to it. 
3. User deposits balance can be sent to external address for investment. Only the contract owner can send
    the balance for investment.
4. Contract will provide a method called setPortfolioValue to receive and store the current value of the
    investment portfolio. Contract will also need to store a timestamp of when the 'setPortfolioValue' method
    was last called. As part of this method, the contract will also calculate and store the share price. 
    The share price is calculated by dividing the value of the investment portfolio by the total amount
    deposited in the fund.
5. When user deposit funds, they will receive a certain number of share tokens. The address of the share
    token will be provided during contract creation.
6. The amount of share tokens received is calculated by multiplying the deposited amount by the current share price.
7. Users can request a withdraw from the fund by calling "redeemShares" method and providing a number
    of shares to redeem. 
8. "redeemShares" method will calculate the current value of the shares by multiplying the shares to redeem
    by the current share price. Next it will check if it has a sufficient balance of the "deposit tokens" and if it does, it will send the current value of shares amount to the user and burn the share tokens it received.  
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// OpenZeppelin libraries.
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// An interface for the share token (our custom ERC20 with mint/burn functions).
interface IShareToken {
    function mint(address to, uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);

    function burnFrom(address account, uint256 amount) external;

    function totalSupply() external view returns (uint256);

    function decimals() external view returns (uint8);
}

/**
 * @title FundManager
 * @dev This contract manages user deposits (in a specified ERC20 deposit token),
 *      mints share tokens to record user “ownership” of the fund,
 *      and allows the owner to update the portfolio value and send funds for investment.
 *
 * The share token uses 6 decimals while we assume the deposit token uses 18 decimals.
 *
 * The “NAV” (here called sharePrice) is stored as a fixed–point number with 18 decimals.
 * It is computed (in setPortfolioValue) as:
 *
 *     sharePrice = (portfolioValue * 10^(shareDecimals)) / total share tokens outstanding.
 *
 * On deposit, a user’s share tokens are minted as:
 *
 *     sharesToMint = (depositAmount * 10^(shareDecimals)) / sharePrice.
 *
 * On redemption, the user receives:
 *
 *     depositValue = (shareAmount * sharePrice) / (10^(shareDecimals)).
 */
contract FundManager is Ownable {
    using SafeERC20 for IERC20;

    /// @notice The ERC20 token accepted as deposits.
    IERC20 private s_depositToken;

    /// @notice The share token representing a user’s stake.
    IShareToken private s_shareToken;

    /// @notice Total cumulative deposit tokens received (in deposit token smallest units).
    uint256 private s_totalDeposited;

    /// @notice The current portfolio value (in deposit token smallest units).
    uint256 private s_portfolioValue;

    /// @notice The current “share price” expressed in deposit tokens per share (fixed–point, 18 decimals).
    uint256 private s_sharePrice;

    /// @notice The timestamp when setPortfolioValue was last called.
    uint256 private s_lastPortfolioTimestamp;

    /// @dev Cached share token decimals (should be 6).
    uint8 private immutable i_shareDecimals;
    uint256 private immutable i_initialSharePrice;

    // ========== ERRORS ==========

    error FundManager__InsufficientTreasuryFunds(
        uint256 available,
        uint256 required
    );
    error FundManager__InvalidShareAmount();
    error FundManager__InvalidInvestmentAmount();
    error FundManager__InvalidRecipient();
    error FundManager__InvalidShareTokenContract();
    error FundManager__InvalidDepositTokenContract();
    error FundManager__FundIsInactive();

    // ========== EVENTS ==========

    event Deposited(
        address indexed user,
        uint256 indexed depositAmount,
        uint256 indexed shareTokensMinted
    );
    event Invested(address indexed to, uint256 indexed amount);
    event PortfolioUpdated(
        uint256 indexed newPortfolioValue,
        uint256 indexed newSharePrice,
        uint256 indexed timestamp
    );
    event Redeemed(
        address indexed user,
        uint256 indexed shareTokensRedeemed,
        uint256 indexed depositAmount
    );

    // ========== CONSTRUCTOR ==========

    /**
     * @notice Constructor.
     * @param _depositToken The address of the ERC20 token to be accepted as deposits.
     * @param _shareToken The address of the share token contract.
     *
     * The Ownable constructor is called with the deployer’s address as the initial owner.
     */
    constructor(
        address _depositToken,
        address _shareToken
    ) Ownable(msg.sender) {
        if (_depositToken == address(0)) {
            revert FundManager__InvalidDepositTokenContract();
        }
        if (_shareToken == address(0)) {
            revert FundManager__InvalidShareTokenContract();
        }

        s_depositToken = IERC20(_depositToken);
        s_shareToken = IShareToken(_shareToken);
        i_shareDecimals = s_shareToken.decimals();

        i_initialSharePrice = 1 * 10 ** i_shareDecimals;
        s_sharePrice = i_initialSharePrice;
    }

    // ========== USER FUNCTIONS ==========

    /**
     * @notice Deposit deposit tokens into the fund.
     * The user must have approved the FundManager to spend their deposit tokens.
     * In exchange the user receives share tokens based on the current share price.
     *
     * @param amount The amount of deposit tokens to deposit.
     */
    function depositFunds(uint256 amount) external returns (uint256) {
        if (amount == 0) {
            revert FundManager__InvalidInvestmentAmount();
        }

        // Transfer deposit tokens from the user.
        s_depositToken.safeTransferFrom(msg.sender, address(this), amount);
        s_totalDeposited += amount;

        // Use the current sharePrice (if no shares exist yet, sharePrice is the default 1e18).
        uint256 currentSharePrice = s_sharePrice;

        // Calculate share tokens to mint:
        // sharesToMint = (amount * 10^(shareDecimals)) / currentSharePrice.
        uint256 sharesToMint = (amount * (10 ** i_shareDecimals)) /
            currentSharePrice;

        // Mint share tokens to the user.
        s_shareToken.mint(msg.sender, sharesToMint);

        emit Deposited(msg.sender, amount, sharesToMint);

        return sharesToMint;
    }

    /**
     * @notice Redeem share tokens for deposit tokens.
     * The current deposit token value is computed using the current share price.
     *
     * @param shareAmount The amount of share tokens to redeem.
     */
    function redeemShares(uint256 shareAmount) external returns (uint256) {
        if (shareAmount == 0) {
            revert FundManager__InvalidShareAmount();
        }

        // Check that the user has enough share tokens to redeem.
        uint256 userShareBalance = s_shareToken.balanceOf(msg.sender);

        if (userShareBalance < shareAmount) {
            revert FundManager__InvalidShareAmount();
        }

        // Calculate the deposit token value:
        // depositValue = (shareAmount * sharePrice) / (10^(shareDecimals)).
        uint256 depositValue = (shareAmount * s_sharePrice) /
            (10 ** i_shareDecimals);

        // Check that the contract has enough deposit tokens.
        uint256 available = s_depositToken.balanceOf(address(this));
        if (available < depositValue) {
            revert FundManager__InsufficientTreasuryFunds(
                available,
                depositValue
            );
        }

        // Burn the share tokens from the user.
        s_shareToken.burnFrom(msg.sender, shareAmount);

        // Transfer the deposit tokens to the user.
        s_depositToken.safeTransfer(msg.sender, depositValue);

        emit Redeemed(msg.sender, shareAmount, depositValue);

        return depositValue;
    }

    // ========== OWNER FUNCTIONS ==========

    /**
     * @notice Transfer deposit tokens (i.e. invested funds) to an external address.
     * Only the owner may call this function.
     *
     * @param to The recipient address.
     * @param amount The amount of deposit tokens to transfer.
     */
    function investFunds(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) {
            revert FundManager__InvalidRecipient();
        }

        if (amount == 0) {
            revert FundManager__InvalidInvestmentAmount();
        }

        uint256 available = s_depositToken.balanceOf(address(this));
        if (available < amount) {
            revert FundManager__InsufficientTreasuryFunds(available, amount);
        }

        s_depositToken.safeTransfer(to, amount);

        emit Invested(to, amount);
    }

    /**
     * @notice Update the portfolio’s current value.
     * Supplied value must be converted to the format of the Deposit Token.
     * (e.g. with i_shareDecimals decimals)
     * This function records the new portfolio value and timestamp, and recalculates the share price.
     * The new share price (NAV per share) is computed as:
     *
     *     sharePrice = (portfolioValue * 10^(shareDecimals)) / (total share tokens outstanding)
     *
     * If no share tokens exist yet, the share price remains at the default value of 1e18.
     *
     * @param newPortfolioValue The current portfolio value (in deposit token smallest units).
     */
    function setPortfolioValue(uint256 newPortfolioValue) external onlyOwner {
        //Don't do anything if we have noi shares
        uint256 totalShares = s_shareToken.totalSupply();
        if (totalShares == 0) {
            revert FundManager__FundIsInactive();
        }

        s_portfolioValue = newPortfolioValue;
        s_lastPortfolioTimestamp = block.timestamp;

        if (totalShares > 0) {
            s_sharePrice =
                (s_portfolioValue * (10 ** i_shareDecimals)) /
                totalShares;
        } else {
            s_sharePrice = i_initialSharePrice;
        }

        emit PortfolioUpdated(
            newPortfolioValue,
            s_sharePrice,
            s_lastPortfolioTimestamp
        );
    }

    // ========== VIEWS ==========
    /**
     * @notice Get the total amount of deposit tokens received by the fund.
     * @return The total amount of deposit tokens.
     */
    function getTotalDeposited() external view returns (uint256) {
        return s_totalDeposited;
    }

    /**
     * @notice Get the current portfolio value.
     * @return The current portfolio value.
     */
    function getPortfolioValue() external view returns (uint256) {
        return s_portfolioValue;
    }

    /**
     * @notice Get the current share price.
     * @return The current share price.
     */
    function getSharePrice() external view returns (uint256) {
        return s_sharePrice;
    }

    /**
     * @notice Get the timestamp of the last portfolio value update.
     * @return The timestamp of the last portfolio value update.
     */
    function getLastPortfolioTimestamp() external view returns (uint256) {
        return s_lastPortfolioTimestamp;
    }

    /**
     * @notice Get the current balance of deposit tokens held by the fund.
     * @return The current balance of deposit tokens.
     */
    function getTreasuryBalance() external view returns (uint256) {
        return s_depositToken.balanceOf(address(this));
    }

    /**
     * @notice Get the address of the deposit token.
     * @return The address of the deposit token.
     */
    function getDepositToken() external view returns (address) {
        return address(s_depositToken);
    }

    /**
     * @notice Get the address of the share token.
     * @return The address of the share token.
     */
    function getShareToken() external view returns (address) {
        return address(s_shareToken);
    }
}
