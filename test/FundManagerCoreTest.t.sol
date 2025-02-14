// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {FundManager} from "../src/FundManager.sol";
import {ShareToken} from "../src/ShareToken.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {FundManagerBase} from "./FundManagerBase.sol";

contract FundManagerCoreTest is FundManagerBase {
    // ==================== Test Constructor ====================
    function testConstructorRevertInvalidDepositTokenContract() public {
        vm.expectRevert(FundManager.FundManager__InvalidDepositTokenContract.selector);
        new FundManager(address(0), address(shareToken));
    }

    function testConstructorRevertInvalidShareTokenContract() public {
        vm.expectRevert(FundManager.FundManager__InvalidShareTokenContract.selector);
        new FundManager(address(depositToken), address(0));
    }

    // ==================== Test Initial State ====================
    function testInitialShareTokenTotalSupplyIsZero() external view {
        assertEq(shareToken.totalSupply(), 0);
    }

    function testInitialInvestorBalancesAreCorrect() external view {
        assertEq(depositToken.balanceOf(INVESTOR_1), INITIAL_INVESTOR_USDC_BALANCE);
        assertEq(depositToken.balanceOf(INVESTOR_2), INITIAL_INVESTOR_USDC_BALANCE);
        assertEq(depositToken.balanceOf(INVESTOR_3), INITIAL_INVESTOR_USDC_BALANCE);
    }

    function testInitialPortfolioValueIsZero() external view {
        assertEq(fundManager.portfolioValue(), 0);
    }

    function testInitialSharePriceIsZero() external view {
        assertEq(fundManager.sharePrice(), 1 * 10 ** shareToken.decimals());
    }

    function testInitialLastPortfolioTimestampIsZero() external view {
        assertEq(fundManager.lastPortfolioValueUpdated(), 0);
    }

    function testInitialTreasuryBalanceIsZero() external view {
        assertEq(fundManager.treasuryBalance(), 0);
    }

    // ==================== Update Portfolio Value Tests ====================
    function testRevertIfsetPortfolioValueIsCalledOnInactveFund() external {
        vm.prank(FUND_OWNER);
        vm.expectRevert(FundManager.FundManager__FundIsInactive.selector);
        fundManager.setPortfolioValue(USDC_10);
    }

    function testRevertIfPortfolioValueCallerIsNotWhitelisted() external {
        vm.prank(INVESTOR_6);
        vm.expectRevert(FundManager.FundManager__InvalidCaller.selector);
        fundManager.setPortfolioValue(USDC_10);
    }

    function testUpdatePortfolioValueByOwner() external {
        _deposit(INVESTOR_1, USDC_100);
        _adjustPortfolioValue(USDC_50, FUND_OWNER);
    }

    function testUpdatePortfolioValueByWhitelistedCaller() external {
        _deposit(INVESTOR_1, USDC_100);

        vm.prank(FUND_OWNER);
        vm.expectEmit(true, false, false, false);
        emit FundManager.AddressWhitelisted(INVESTOR_6);
        fundManager.addToWhitelist(INVESTOR_6);

        _adjustPortfolioValue(USDC_50, INVESTOR_6);
    }

    function testRevertUpdatePortfolioValueByUNWhitelistedCaller() external {
        _deposit(INVESTOR_1, USDC_100);

        vm.prank(FUND_OWNER);
        vm.expectEmit(true, false, false, false);
        emit FundManager.AddressWhitelisted(INVESTOR_6);
        fundManager.addToWhitelist(INVESTOR_6);

        _adjustPortfolioValue(USDC_50, INVESTOR_6);

        vm.prank(FUND_OWNER);
        vm.expectEmit(true, false, false, false);
        emit FundManager.AddressRemovedFromWhitelist(INVESTOR_6);
        fundManager.removeFromWhitelist(INVESTOR_6);

        vm.prank(INVESTOR_6);
        vm.expectRevert(FundManager.FundManager__InvalidCaller.selector);
        fundManager.setPortfolioValue(USDC_10);
    }

    function testSetPortfolioValueRevertNonOwner() public {
        vm.prank(INVESTOR_1);
        vm.expectRevert();
        fundManager.setPortfolioValue(USDC_200);
    }

    function testSetPortfolioValueRevertWhenNoShares() public {
        // No deposit => no shares => fund inactive.
        vm.prank(FUND_OWNER);
        vm.expectRevert(abi.encodeWithSelector(FundManager.FundManager__FundIsInactive.selector));
        fundManager.setPortfolioValue(USDC_200);
    }

    // ==================== Deposit Tests ====================
    function testDepositFundsRevertZeroAmount() public {
        vm.prank(INVESTOR_1);
        vm.expectRevert(FundManager.FundManager__InvalidInvestmentAmount.selector);
        fundManager.depositFunds(0);
    }

    // ==================== Redeem Tests ====================
    function testRedeemSharesRevertZeroShares() public {
        vm.prank(INVESTOR_1);
        vm.expectRevert(FundManager.FundManager__InvalidShareAmount.selector);
        fundManager.redeemShares(0);
    }

    function testRedeemSharesRevertInsufficientBalance() public {
        // alice has no shares yet so any call should revert
        vm.prank(INVESTOR_1);
        vm.expectRevert(FundManager.FundManager__InvalidShareAmount.selector);
        fundManager.redeemShares(100);
    }

    function testRedeemSharesInsufficientTreasuryFunds() public {
        uint256 mintedShares = _deposit(INVESTOR_1, USDC_200);
        _invest(USDC_100);

        vm.prank(INVESTOR_1);
        vm.expectRevert(
            abi.encodeWithSelector(FundManager.FundManager__InsufficientTreasuryFunds.selector, 100000000, 200000000)
        );
        fundManager.redeemShares(mintedShares);
    }

    function testPauseRedemptions() public {
        vm.prank(FUND_OWNER);
        fundManager.pauseRedemptions();
        assertEq(fundManager.redemptionsAllowed(), false);
    }

    function testResumeRedemptions() public {
        vm.prank(FUND_OWNER);
        fundManager.pauseRedemptions();
        assertEq(fundManager.redemptionsAllowed(), false);

        vm.prank(FUND_OWNER);
        fundManager.resumeRedemptions();
        assertEq(fundManager.redemptionsAllowed(), true);
    }

    function testRedeemSharesRevertWhenPaused() public {
        uint256 mintedShares = _deposit(INVESTOR_1, USDC_200);

        vm.prank(FUND_OWNER);
        fundManager.pauseRedemptions();

        vm.prank(INVESTOR_1);
        vm.expectRevert(FundManager.FundManager__RedemptionsPaused.selector);
        fundManager.redeemShares(mintedShares);
    }

    function testRedeemSharesAllowedWhenResumed() public {
        uint256 mintedShares = _deposit(INVESTOR_1, USDC_200);

        vm.prank(FUND_OWNER);
        fundManager.pauseRedemptions();

        vm.prank(FUND_OWNER);
        fundManager.resumeRedemptions();

        vm.prank(INVESTOR_1);
        fundManager.redeemShares(mintedShares);
    }

    // ==================== Invest Tests ====================
    function testInvestFundsRevertNonOwner() public {
        vm.prank(INVESTOR_1);
        vm.expectRevert();
        fundManager.investFunds(PORTFOLIO_WALLET, USDC_10);
    }

    function testInvestFundsRevertZeroAmount() public {
        vm.prank(FUND_OWNER);
        vm.expectRevert(FundManager.FundManager__InvalidInvestmentAmount.selector);
        fundManager.investFunds(PORTFOLIO_WALLET, 0);
    }

    function testInvestFundsRevertInvalidRecipient() public {
        vm.prank(FUND_OWNER);
        vm.expectRevert(FundManager.FundManager__InvalidRecipient.selector);
        fundManager.investFunds(address(0), 1e18);
    }

    function testInvestFundsInsufficientTreasury() public {
        _deposit(INVESTOR_1, USDC_200);

        vm.prank(FUND_OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(FundManager.FundManager__InsufficientTreasuryFunds.selector, 200000000, 200000001)
        );
        fundManager.investFunds(PORTFOLIO_WALLET, USDC_200 + 1);
    }

    // ==================== View Functions Tests ====================
    function testViewFunctions() public {
        vm.prank(INVESTOR_1);
        uint256 sharesOwned = fundManager.depositFunds(USDC_100);

        assertEq(fundManager.sharesOwned(INVESTOR_1), sharesOwned);
        assertEq(fundManager.totalShares(), sharesOwned);

        uint256 preUpdateTimestamp = fundManager.lastPortfolioValueUpdated();
        assertEq(preUpdateTimestamp, 0);

        vm.prank(FUND_OWNER);
        fundManager.setPortfolioValue(USDC_50);

        assertEq(fundManager.portfolioValue(), USDC_50);
        assertEq(fundManager.totalFundValue(), USDC_100 + USDC_50);
        assertEq(fundManager.sharePrice(), 1500000); //100 deposited + 50 increase in value = 150 total value / 100 shares = 1.5 USDC/share

        assertGt(fundManager.lastPortfolioValueUpdated(), preUpdateTimestamp);

        assertEq(fundManager.treasuryBalance(), USDC_100);
        assertEq(fundManager.depositToken(), address(depositToken));
        assertEq(fundManager.shareToken(), address(shareToken));
    }
}
