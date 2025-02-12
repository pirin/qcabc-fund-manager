// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./TestHelpers.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

import {FundManager} from "../src/FundManager.sol";
import {ShareToken} from "../src/ShareToken.sol";

import {DeployFundManager} from "../script/DeployFundManager.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {CodeConstants} from "../script/HelperConfig.s.sol";

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

contract FundManagerBase is Test, CodeConstants {
    FundManager public fundManager;
    ShareToken public shareToken;
    address public FUND_OWNER;
    HelperConfig public helperConfig;

    ERC20 public depositToken;

    address public INVESTOR_1 = makeAddr("investor1");
    address public INVESTOR_2 = makeAddr("investor2");
    address public INVESTOR_3 = makeAddr("investor3");
    address public INVESTOR_4 = makeAddr("investor4");
    address public INVESTOR_5 = makeAddr("investor5");
    address public INVESTOR_6 = makeAddr("investor6");

    address public PORTFOLIO_WALLET = makeAddr("portfolio wallet");

    uint256 public constant INITIAL_INVESTOR_USDC_BALANCE = 1000 * (10 ** 6);
    uint256 public constant USDC_200 = 200 * (10 ** 6);
    uint256 public constant USDC_150 = 150 * (10 ** 6);
    uint256 public constant USDC_100 = 100 * (10 ** 6);
    uint256 public constant USDC_50 = 50 * (10 ** 6);
    uint256 public constant USDC_10 = 10 * (10 ** 6);
    uint256 public constant USDC_1 = 1 * (10 ** 6);

    uint256 public constant SHARES_100 = 100 * (10 ** 6);
    uint256 public constant SHARES_50 = 50 * (10 ** 6);
    uint256 public constant SHARES_10 = 50 * (10 ** 6);

    function setUp() external {
        DeployFundManager deployFundManager = new DeployFundManager();
        (fundManager, shareToken, helperConfig) = deployFundManager.run();

        depositToken = ERC20(helperConfig.getConfig().depositToken);
        FUND_OWNER = helperConfig.getConfig().ownerAdress;

        if (block.chainid == LOCAL_CHAIN_ID) {
            console.log("Dealing funds to Investors...");

            _dealAndApprove(INVESTOR_1, INITIAL_INVESTOR_USDC_BALANCE);
            _dealAndApprove(INVESTOR_2, INITIAL_INVESTOR_USDC_BALANCE);
            _dealAndApprove(INVESTOR_3, INITIAL_INVESTOR_USDC_BALANCE);
            _dealAndApprove(INVESTOR_4, INITIAL_INVESTOR_USDC_BALANCE);
            _dealAndApprove(INVESTOR_5, INITIAL_INVESTOR_USDC_BALANCE);
            _dealAndApprove(INVESTOR_6, INITIAL_INVESTOR_USDC_BALANCE);
        }
    }

    // ==================== helper functions ====================
    function _dealAndApprove(address investor, uint256 amount) internal {
        vm.prank(FUND_OWNER);
        depositToken.transfer(investor, amount);

        vm.prank(investor);
        depositToken.approve(address(fundManager), amount);
    }

    function _deposit(address investor, uint256 amount) internal returns (uint256) {
        uint256 pdDepositUSDC = depositToken.balanceOf(investor);
        uint256 pdTotalDeposited = fundManager.getTotalDeposited();
        uint256 pdTreasuryUSDC = fundManager.getTreasuryBalance();
        uint256 pdInvestorShares = shareToken.balanceOf(investor);
        uint256 pdShareSupply = shareToken.totalSupply();

        vm.prank(investor);
        vm.expectEmit(true, true, false, false);
        emit FundManager.Deposited(investor, amount, 0);
        uint256 sharesMinted = fundManager.depositFunds(amount);

        uint256 adDepositUSDC = depositToken.balanceOf(investor);
        uint256 adTotalDeposited = fundManager.getTotalDeposited();
        uint256 adTreasuryUSDC = fundManager.getTreasuryBalance();
        uint256 adInvestorShares = shareToken.balanceOf(investor);
        uint256 adShareSupply = shareToken.totalSupply();

        assertEq(adDepositUSDC, pdDepositUSDC - amount); //investor has less USDC now
        assertEq(adTotalDeposited, pdTotalDeposited + amount); // fund lifetime deposit has increased by the right amount
        assertEq(adTreasuryUSDC, pdTreasuryUSDC + amount); //balance in the fund has increased by the right amount
        assertEq(adInvestorShares, pdInvestorShares + sharesMinted); //investor got the right amount of shares
        assertEq(adShareSupply, pdShareSupply + sharesMinted); //total supply of shares was incread by minted amount

        console.log(
            "\n>>>>> Investor Deposited ",
            amount / 1000000,
            " USDC. Shares minted: ",
            TestHelpers.toString6(sharesMinted)
        );

        return sharesMinted;
    }

    function _redeem(address investor, uint256 shares) internal returns (uint256) {
        uint256 pdDepositUSDC = depositToken.balanceOf(investor);
        uint256 pdTotalDeposited = fundManager.getTotalDeposited();
        uint256 pdTreasuryUSDC = fundManager.getTreasuryBalance();
        uint256 pdInvestorShares = shareToken.balanceOf(investor);
        uint256 pdShareSupply = shareToken.totalSupply();

        vm.prank(investor);
        vm.expectEmit(true, true, false, false);
        emit FundManager.Redeemed(investor, shares, 0);
        uint256 proceeds = fundManager.redeemShares(shares);

        uint256 adDepositUSDC = depositToken.balanceOf(investor);
        uint256 adTotalDeposited = fundManager.getTotalDeposited();
        uint256 adTreasuryUSDC = fundManager.getTreasuryBalance();
        uint256 adInvestorShares = shareToken.balanceOf(investor);
        uint256 adShareSupply = shareToken.totalSupply();

        assertEq(adDepositUSDC, pdDepositUSDC + proceeds); //investor has more USDC now
        assertEq(adTotalDeposited, pdTotalDeposited); // fund lifetime deposit has not changed
        assertEq(adTreasuryUSDC, pdTreasuryUSDC - proceeds); //balance in the fund has decreased by the right amount
        assertEq(adInvestorShares, pdInvestorShares - shares); //investor got less shares
        assertEq(adShareSupply, pdShareSupply - shares); //total supply of shares was decreased by burned shares

        console.log(
            "\n<<<<< Investor Redeemed ", shares / 1000000, " Shares. USDC received: ", TestHelpers.toString6(proceeds)
        );

        return proceeds;
    }

    function _adjustPortfolioValue(uint256 newPortfolioValue, address caller) internal returns (uint256) {
        console.log("\n^^^^^ Adjusting portfolio value to: ", TestHelpers.toString6(newPortfolioValue), " USDC");

        vm.prank(caller);
        vm.expectEmit(true, false, false, false);
        emit FundManager.PortfolioUpdated(newPortfolioValue, 0, 0);
        uint256 actualPortfolioValue = fundManager.setPortfolioValue(newPortfolioValue);

        assertEq(newPortfolioValue, fundManager.getPortfolioValue());

        return actualPortfolioValue;
    }

    function _invest(uint256 amount) internal {
        uint256 pdTreasuryUSDC = fundManager.getTreasuryBalance();
        uint256 pdPortfolioWalletBalanceUSDC = depositToken.balanceOf(PORTFOLIO_WALLET);

        vm.prank(FUND_OWNER);
        vm.expectEmit(true, true, false, false);
        emit FundManager.Invested(PORTFOLIO_WALLET, amount);
        fundManager.investFunds(PORTFOLIO_WALLET, amount);

        //as treasury funds are decreased, portfolio value is increased by the same amount
        //such that the total fund value remains the same
        uint256 currentPortfolioValue = fundManager.getPortfolioValue();
        vm.prank(FUND_OWNER);
        fundManager.setPortfolioValue(currentPortfolioValue + amount);

        uint256 adTreasuryUSDC = fundManager.getTreasuryBalance();
        uint256 adPortfolioWalletBalanceUSDC = depositToken.balanceOf(PORTFOLIO_WALLET);

        assertEq(adTreasuryUSDC, pdTreasuryUSDC - amount); //balance in the fund has decreased by the right amount
        assertEq(adPortfolioWalletBalanceUSDC, pdPortfolioWalletBalanceUSDC + amount); //balance in the fund has decreased by the right amount

        console.log("\n----> Fund Invested ", TestHelpers.toString6(amount), " USDC");
    }

    function _printFundInfo() internal view {
        console.log("\nFund Info:");
        console.log("   Total Fund Value:  ", TestHelpers.toString6(fundManager.getFundValue()), " USDC");
        console.log("   Treasury Balance:  ", TestHelpers.toString6(fundManager.getTreasuryBalance()), "USDC");
        console.log("   Portfolio Value:   ", TestHelpers.toString6(fundManager.getPortfolioValue()), " USDC");
        console.log("   Share Price:       ", TestHelpers.toString6(fundManager.getSharePrice()), " USDC");
        console.log("   Share Total Supply:", TestHelpers.toString6(shareToken.totalSupply()), " Shares");

        //print incvestor balance and shares owned on the same line
        console.log("\nCap Table:");
        console.log(
            "   Investor 1: - Balance:",
            TestHelpers.toString6(depositToken.balanceOf(INVESTOR_1)),
            "USDC, Shares: ",
            TestHelpers.toString6(shareToken.balanceOf(INVESTOR_1))
        );
        console.log(
            "   Investor 2: - Balance:",
            TestHelpers.toString6(depositToken.balanceOf(INVESTOR_2)),
            "USDC, Shares: ",
            TestHelpers.toString6(shareToken.balanceOf(INVESTOR_2))
        );
        console.log(
            "   Investor 3: - Balance:",
            TestHelpers.toString6(depositToken.balanceOf(INVESTOR_3)),
            "USDC, Shares: ",
            TestHelpers.toString6(shareToken.balanceOf(INVESTOR_3))
        );
        console.log(
            "   Investor 4: - Balance:",
            TestHelpers.toString6(depositToken.balanceOf(INVESTOR_4)),
            "USDC, Shares: ",
            TestHelpers.toString6(shareToken.balanceOf(INVESTOR_4))
        );
        console.log(
            "   Investor 5: - Balance:",
            TestHelpers.toString6(depositToken.balanceOf(INVESTOR_5)),
            "USDC, Shares: ",
            TestHelpers.toString6(shareToken.balanceOf(INVESTOR_5))
        );
        console.log(
            "   Investor 6: - Balance:",
            TestHelpers.toString6(depositToken.balanceOf(INVESTOR_6)),
            "USDC, Shares: ",
            TestHelpers.toString6(shareToken.balanceOf(INVESTOR_6))
        );
    }
}
