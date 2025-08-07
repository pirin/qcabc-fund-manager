# QCABC Fund Manager

A Solidity smart contract system implementing an on-chain investment fund manager with advanced portfolio management capabilities. The system enables users to deposit funds, receive share tokens representing ownership, and allows fund managers to invest collected funds off-chain while maintaining transparent on-chain portfolio valuations.

## Overview

The QCABC Fund Manager implements a blockchain-based investment club model where:

- Users deposit ERC20 tokens (typically USDC) and receive proportional share tokens
- Share prices are calculated dynamically based on total fund value (treasury + portfolio)
- Off-chain investments are managed with periodic on-chain value updates
- Comprehensive access controls ensure security and compliance

## Key Features

### 🏦 **Core Fund Operations**

- **Deposits**: Accept ERC20 deposits with dynamic share token minting based on current NAV
- **Redemptions**: Allow users to redeem shares for underlying assets at current share price
- **Portfolio Management**: Track off-chain investment values with on-chain updates
- **Dynamic Pricing**: Real-time share price calculation based on total fund value

### 🔒 **Security & Access Controls**

- **Whitelist Management**: Separate whitelists for depositors and portfolio value updaters
- **Reentrancy Protection**: SafeERC20 and ReentrancyGuard implementation
- **Owner Controls**: Multi-tiered access system with owner privileges
- **Stale Data Protection**: Automatic redemption pausing if portfolio values become outdated (>2 days)

### 💰 **Fee Management**

- **Management Fees**: Configurable deposit fees (0-10% maximum) in basis points
- **Fee Recipients**: Designated addresses for automatic fee collection
- **Transparent Fee Events**: Complete event logging for fee collection

### 🛡️ **Risk Management**

- **Redemption Controls**: Owner can pause/resume redemptions during market volatility
- **Portfolio Staleness Checks**: Prevents redemptions with outdated portfolio valuations
- **Liquidity Management**: Automatic treasury balance verification before redemptions
- **Decimal Precision**: Consistent 6-decimal handling for USDC compatibility

## Architecture

### Smart Contracts

1. **FundManager.sol**

   - Main contract managing all fund operations
   - Handles deposits, redemptions, and portfolio updates
   - Implements comprehensive access controls and safety features

2. **ShareToken.sol**
   - ERC20 token representing fund ownership
   - 6 decimals to match typical stablecoin format
   - Mint/burn functionality restricted to fund manager

### Key Components

#### Share Price Calculation

The fund uses a basic NAV (Net Asset Value) calculation:

```
sharePrice = (totalFundValue * 10^decimals) / totalSharesOutstanding
totalFundValue = treasuryBalance + portfolioValue
```

#### Deposit Process

1. User approves deposit token allowance
2. Management fee is calculated and transferred (if configured)
3. Remaining amount is used to mint shares based on current share price
4. Share price is recalculated to reflect new fund composition

#### Redemption Process

1. Verify user has sufficient share tokens
2. Check portfolio value is not stale (within 2 days)
3. Calculate redemption value based on current share price
4. Burn user's share tokens and transfer deposit tokens
5. Recalculate share price

## Technical Specifications

- **Solidity Version**: ^0.8.26
- **Token Standard**: ERC20 (OpenZeppelin)
- **Decimals**: 6 (matching USDC standard)
- **Share Price Precision**: 18 decimals for accurate calculations
- **Maximum Management Fee**: 10% (1000 basis points)
- **Portfolio Staleness Limit**: 2 days

## Deployment & Configuration

### Environment Setup

Before deploying, you need to create a local `.env` file with the required configuration variables. Copy the provided `.env.example` template and fill in your specific values.

**Required for all networks:**

```bash
cp .env.example .env
# Edit .env with your specific values
```

### Environment Variables

The deployment system requires different environment variables depending on the target network:

#### Local Development (Anvil)

- `ANVIL_RPC_URL`: Local Anvil RPC endpoint
- `DEFAULT_ANVIL_KEY`: Private key for local testing
- `ANVIL_SHARE_TOKEN`: Address of deployed ShareToken (if reusing)

#### Base Sepolia Testnet

- `BASE_SEPOLIA_RPC_URL`: Base Sepolia RPC endpoint
- `BASE_SEPOLIA_OWNER_WALLET_NAME`: Cast wallet name for testnet deployment
- `BASE_SEPOLIA_DEPOSIT_TOKEN`: USDC contract address on testnet
- `BASE_SEPOLIA_SHARE_TOKEN`: ShareToken address (if pre-deployed)
- `BASE_SEPOLIA_OWNER_WALLET_ADDRESS`: Owner wallet address
- `BASESCAN_API_KEY`: BaseScan API key for contract verification

#### Base Mainnet

- `BASE_MAINNET_RPC_URL`: Base mainnet RPC endpoint
- `BASE_MAINNET_OWNER_WALLET_NAME`: Cast wallet name for mainnet
- `BASE_MAINNET_DEPOSIT_TOKEN`: USDC contract address
- `BASE_MAINNET_SHARE_TOKEN`: ShareToken address (if pre-deployed)
- `BASE_MAINNET_OWNER_WALLET_ADDRESS`: Owner wallet address
- `BASE_MAINNET_API_KEY`: BaseScan API key for contract verification

### Constructor Parameters

- `_depositToken`: Address of accepted ERC20 deposit token (e.g., USDC)
- `_shareToken`: Address of the ShareToken contract

### Initial Setup Required

1. **Environment Configuration**: Set up `.env` file with network-specific variables
2. **Wallet Setup**: Configure Cast wallet for non-local deployments
3. **Deploy ShareToken contract**: `make deployShareToken`
4. **Deploy FundManager**: `make deployFundManager`
5. **Configure whitelists**: Add authorized depositors and portfolio updaters (optional)
6. **Set management fees**: Configure fee percentage and recipient (optional)

## Usage Examples

### For Fund Participants

```solidity
// Deposit 1000 USDC
USDC.approve(fundManager, 1000e6);
uint256 sharesReceived = fundManager.depositFunds(1000e6);

// Check current share price and holdings
uint256 currentPrice = fundManager.sharePrice();
uint256 myShares = fundManager.sharesOwned(msg.sender);

// Redeem 500 shares
uint256 usdcReceived = fundManager.redeemShares(500e6);
```

### For Fund Managers

```solidity
// Update portfolio value (requires whitelist or owner)
fundManager.setPortfolioValue(50000e6); // $50,000 portfolio value

// Invest treasury funds off-chain
fundManager.investFunds(investmentAddress, 10000e6);

// Manage redemptions during volatile periods
fundManager.pauseRedemptions();
// ... later ...
fundManager.resumeRedemptions();
```

## Security Considerations

### Access Control Matrix

| Function             | Owner              | Whitelisted Updater | Any User            |
| -------------------- | ------------------ | ------------------- | ------------------- |
| depositFunds         | ✓ (if whitelisted) | ✓ (if whitelisted)  | ✓ (if no whitelist) |
| redeemShares         | ✓                  | ✓                   | ✓                   |
| setPortfolioValue    | ✓                  | ✓                   | ✗                   |
| investFunds          | ✓                  | ✗                   | ✗                   |
| Whitelist Management | ✓                  | ✗                   | ✗                   |
| Fee Configuration    | ✓                  | ✗                   | ✗                   |

### Risk Mitigation

- **Centralization Risk**: Multi-signature wallets recommended for owner functions
- **Oracle Risk**: Manual portfolio updates require trusted updaters
- **Liquidity Risk**: Treasury balance checks prevent over-redemptions
- **Stale Data Risk**: Automatic pausing prevents redemptions with outdated valuations

## Events & Monitoring

The contract emits comprehensive events for all major operations:

- `Deposited`: New deposits with share minting details
- `Redeemed`: Share redemptions with payout amounts
- `PortfolioUpdated`: Portfolio value changes with new share prices
- `ManagementFeeCollected`: Fee collection details
- `RedemptionsPaused/Resumed`: Redemption status changes

## Development & Testing

Built with Foundry framework:

```bash
# Build contracts
make build

# Run tests
make test

# Deploy locally
make deploy

# Deploy to testnet
make deploy ARGS="--network sepolia"
```

## Future Enhancements

- **Multi-Asset Support**: Accept multiple deposit token types
- **Automated Oracles**: Integration with price feeds for real-time portfolio updates
- **Governance Module**: DAO-based decision making for fund operations
- **Advanced Fee Structures**: Performance fees and carry calculations
- **Liquidity Pools**: Integration with DEX protocols for enhanced liquidity

## License

MIT License - see LICENSE file for details.
