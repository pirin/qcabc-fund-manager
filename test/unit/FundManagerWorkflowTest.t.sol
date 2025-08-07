// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {FundManager} from "../../src/FundManager.sol";
import {ShareToken} from "../../src/ShareToken.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {FundManagerBase} from "./FundManagerBase.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract FundManagerWorkflowTest is FundManagerBase {
    function testSimpleWorkflowDepositAndWithdraw() external {
        uint256 sharesMinted = _deposit(INVESTOR_1, USDC_100);
        assertEq(sharesMinted, SHARES_100);
        uint256 proceeds = _redeem(INVESTOR_1, sharesMinted / 2); //redeem half the  shares
        assertEq(proceeds, USDC_50);
    }

    function testComplexWorkflowDepositAndWithdraw() external {
        _printFundInfo();

        //deposit 100 USDC
        uint256 sharesMinted1 = _deposit(INVESTOR_1, USDC_100);
        assertEq(sharesMinted1, SHARES_100);

        //deposit 50 USDC
        uint256 sharesMinted2 = _deposit(INVESTOR_2, USDC_50);
        assertEq(sharesMinted2, SHARES_50);

        //check balances
        assertEq(fundManager.treasuryBalance(), USDC_50 + USDC_100);
        assertEq(shareToken.totalSupply(), sharesMinted1 + sharesMinted2);
        assertEq(fundManager.sharePrice(), 1 * 10 ** shareToken.decimals());
        assertEq(fundManager.totalFundValue(), USDC_50 + USDC_100);

        //_printFundInfo();

        //do some investments
        _invest(USDC_150); //portfolio value is automatically adjusted for

        //fund increased in value by 50 USDC
        _adjustPortfolioValue(fundManager.portfolioValue() + USDC_50, FUND_OWNER); //potfolio is now worth 50 USDC above the cost basis

        uint256 sharesMinted3 = _deposit(INVESTOR_3, USDC_100);
        assertEq(sharesMinted3, 75000018);

        uint256 sharesMinted4 = _deposit(INVESTOR_4, USDC_100);
        assertEq(sharesMinted4, 75000018);

        //fund decreased in value by 150 USDC
        _adjustPortfolioValue(fundManager.portfolioValue() - USDC_150, FUND_OWNER); //potfolio is now worth 50 USDC below the cost basis

        uint256 sharesMinted5 = _deposit(INVESTOR_5, USDC_100);
        assertEq(sharesMinted5, 120000048);

        uint256 redemption1 = _redeem(INVESTOR_1, sharesMinted1); //share price is 0.83
        assertEq(redemption1, 83333300); //gets 83.33 USDC back

        //fund increased in value by 50 USDC
        _adjustPortfolioValue(fundManager.portfolioValue() + USDC_200, FUND_OWNER); //potfolio is now worth 200 USDC above the cost basis

        uint256 redemption2 = _redeem(INVESTOR_2, sharesMinted2); //share price is 1.46
        assertEq(redemption2, 72916650); //user gets 72.91 USDC back

        _printFundInfo();
    }

    // ==================== Management Fee Tests ====================
    function testManagementFeeCalculation() external {
        address feeRecipient = makeAddr("feeRecipient");

        // Set management fee to 0.1% (10 basis point)
        vm.prank(FUND_OWNER);
        fundManager.setManagementFee(100); // in basis points 1% = 100 basis points
        assertEq(fundManager.managementFee(), 100);

        // Set management fee recipient
        vm.prank(FUND_OWNER);
        fundManager.setManagementFeeRecipient(feeRecipient);

        uint256 initialRecipientBalance = depositToken.balanceOf(feeRecipient);
        uint256 initialTreasuryBalance = fundManager.treasuryBalance();

        // Test deposit 1: 300 USDC
        vm.prank(INVESTOR_1);
        vm.expectEmit(true, true, false, false);
        emit FundManager.ManagementFeeCollected(INVESTOR_1, 3 * 1e6, 300 * 1e6);
        uint256 shares1 = fundManager.depositFunds(300 * 1e6);

        assertEq(shares1, 297 * 1e6); // 297 USDC worth of shares

        // Verify fee was transferred to recipient
        assertEq(depositToken.balanceOf(feeRecipient), initialRecipientBalance + 3 * 1e6);

        // Verify treasury received deposit minus fee
        assertEq(fundManager.treasuryBalance(), initialTreasuryBalance + 300 * 1e6 - 3 * 1e6);

        console.log("After deposit 1 (300 USDC):");
        console.log("  Share price: ", TestHelpers.toString6(fundManager.sharePrice()), "USDC per share");
        console.log("  Operations Wallet: ", TestHelpers.toString6(depositToken.balanceOf(feeRecipient)), "USDC");
        console.log("  Investment Treasury: ", TestHelpers.toString6(fundManager.treasuryBalance()), "USDC");

        // Test deposit 2: 400 USDC
        vm.prank(INVESTOR_2);
        vm.expectEmit(true, true, false, false);
        emit FundManager.ManagementFeeCollected(INVESTOR_2, 4 * 1e6, 400 * 1e6);
        uint256 shares2 = fundManager.depositFunds(400 * 1e6);

        assertEq(shares2, 396 * 1e6);

        console.log("After deposit 2 (400 USDC):");
        console.log("  Share price: ", TestHelpers.toString6(fundManager.sharePrice()), "USDC per share");
        console.log("  Operations Wallet: ", TestHelpers.toString6(depositToken.balanceOf(feeRecipient)), "USDC");
        console.log("  Investment Treasury: ", TestHelpers.toString6(fundManager.treasuryBalance()), "USDC");

        // Test deposit 3: 500 USDC
        vm.prank(INVESTOR_3);
        vm.expectEmit(true, true, false, false);
        emit FundManager.ManagementFeeCollected(INVESTOR_3, 5 * 1e6, 500 * 1e6);
        uint256 shares3 = fundManager.depositFunds(500 * 1e6);

        assertEq(shares3, 495 * 1e6);
        assertEq(fundManager.treasuryBalance(), 1188 * 1e6); // 1188 USDC total

        console.log("After deposit 3 (500 USDC):");
        console.log("  Share price: ", TestHelpers.toString6(fundManager.sharePrice()), "USDC per share");
        console.log("  Operations Wallet: ", TestHelpers.toString6(depositToken.balanceOf(feeRecipient)), "USDC");
        console.log("  Investment Treasury: ", TestHelpers.toString6(fundManager.treasuryBalance()), "USDC");
        console.log("=== Final Results ===");
        console.log("Total Deposited: 1,200 USDC");
        console.log("Treasury Balance: ", TestHelpers.toString6(fundManager.treasuryBalance()), "USDC");
        console.log("  Operations Wallet: ", TestHelpers.toString6(depositToken.balanceOf(feeRecipient)), "USDC");
        console.log("Total Shares: ", TestHelpers.toString6(fundManager.totalShares()), "shares");
        console.log("Final Share Price: ", TestHelpers.toString6(fundManager.sharePrice()), "USDC per share");
    }
}
