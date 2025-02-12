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

    function testInitialTotalDepositedIsZero() external view {
        assertEq(fundManager.getTotalDeposited(), 0);
    }

    function testInitialPortfolioValueIsZero() external view {
        assertEq(fundManager.getPortfolioValue(), 0);
    }

    function testInitialSharePriceIsZero() external view {
        assertEq(fundManager.getSharePrice(), 1 * 10 ** shareToken.decimals());
    }

    function testInitialLastPortfolioTimestampIsZero() external view {
        assertEq(fundManager.getLastPortfolioTimestamp(), 0);
    }

    function testInitialTreasuryBalanceIsZero() external view {
        assertEq(fundManager.getTreasuryBalance(), 0);
    }

    // ==================== Update Portfolio Value Tests ====================
    function testRevertIfsetPortfolioValueIsCalledOnInactveFund() external {
        vm.prank(FUND_OWNER);
        vm.expectRevert(FundManager.FundManager__FundIsInactive.selector);
        fundManager.setPortfolioValue(1);
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
        fundManager.depositFunds(USDC_100);

        uint256 preUpdateTimestamp = fundManager.getLastPortfolioTimestamp();
        assertEq(preUpdateTimestamp, 0);

        vm.prank(FUND_OWNER);
        fundManager.setPortfolioValue(USDC_50);

        assertEq(fundManager.getTotalDeposited(), USDC_100);
        assertEq(fundManager.getPortfolioValue(), USDC_50);
        assertEq(fundManager.getFundValue(), USDC_100 + USDC_50);
        assertEq(fundManager.getSharePrice(), 1500000); //100 deposited + 50 increase in value = 150 total value / 100 shares = 1.5 USDC/share

        assertGt(fundManager.getLastPortfolioTimestamp(), preUpdateTimestamp);

        assertEq(fundManager.getTreasuryBalance(), USDC_100);
        assertEq(fundManager.getDepositToken(), address(depositToken));
        assertEq(fundManager.getShareToken(), address(shareToken));
    }
}
