**(Very simple) White Paper: Blockchain-Based Investment Club**

This document outlines a simplified on-chain club model, describing how deposits, portfolio valuation, and share calculations are managed, as well as highlighting potential limitations and improvements.

---

## 1. Introduction

An investment club pools member contributions to invest in external opportunities. This on-chain approach uses a smart contract to automate deposit handling, share distribution, and periodic portfolio valuation. Using an on-chain cap table with a clear share pricing formula, offers a transparent, straightforward approach to running an investment club. However, improvements in governance, valuation updates, multi-asset support, and liquidity handling can enhance fairness, security, and resilience in more sophisticated or high-volume scenarios.

---

## 2. Key Components

1. **Deposit Token**  
   - A single ERC20-like token is designated at contract creation.  
   - All deposits must be made in this deposit token to keep accounting straightforward.

2. **Share Token**  
   - An ERC20-like share token is used to represent ownership in the club.  
   - Members receive share tokens in proportion to their deposits.

3. **Off-Chain Investment**  
   - The contract owner sends collected deposit tokens to an external investment address for portfolio management.  
   - Investment returns or updates are managed off-chain, and the latest valuation is periodically reported back to the contract.

---

## 3. Workflow Overview

1. **Depositing Funds**  
   - Members deposit funds using a specified "deposit token". This is usialy a Stablecoin like USDC or USDT but could be any ERC20 token.  
   - The contract tracks the total deposit balance and credits new share tokens to the depositor.

2. **Portfolio Updates**  
   - The contract owner periodically updates the contract with the current total value of the investment (e.g., in USD or the deposit token’s value).  
   - A timestamp is recorded for reference.

3. **Share Price Calculation**  
   - Defined as:  
     \[
       \text{Share Price} = \frac{\text{Current Portfolio Value}}{\text{Total Deposited Tokens}}
     \]  
   - This value is used for issuing new shares on deposits and for redeeming shares on withdrawals.

4. **Issuing Shares**  
   - When a user deposits, the number of shares they receive is:  
     \[
       \text{Shares Issued} = \text{Deposit Amount} \times \text{Share Price}
     \]  
   - The contract mints new share tokens accordingly.

5. **Withdrawal**  
   - Users request a withdrawal by specifying how many shares they wish to redeem.  
   - The contract calculates the redemption value based on the current share price and attempts to pay out that amount in deposit tokens.  
   - Upon successful payment, the redeemed shares are burned.

---

## 4. Potential Drawbacks and Improvements

1. **Centralized Control**  
   - Only the owner can move funds for investment.  
   - **Improvement**: Use a multi-signature or DAO-based mechanism for greater security and transparency.

2. **Manual Valuation Updates**  
   - Relies on the owner or another trusted party to submit accurate portfolio values.  
   - **Improvement**: Integrate an oracle or automated pricing solution to reduce manual intervention and trust requirements.

3. **Limited Asset Support**  
   - Only one deposit token is accepted.  
   - **Improvement**: Extend to support multiple deposit tokens or stablecoins for greater flexibility.

4. **Liquidity Constraints**  
   - Withdrawals rely on the contract’s token holdings. If there are insufficient tokens on-hand, redemptions can be delayed.  
   - **Improvement**: Implement a withdrawal queue or partial redemption system to handle shortfalls gracefully.

5. **Simplistic Share Price Calculation**  
   - If portfolio values change often, time gaps between updates can create inaccurate share pricing.  
   - **Improvement**: More frequent or continuous updates would produce a fairer net asset valuation (NAV).





