// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {DeployFundManager} from "../script/DeployFundManager.s.sol";
import {FundManager} from "../src/FundManager.sol";
import {ShareToken} from "../src/ShareToken.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

contract FundManagerTest is Test, CodeConstants {
    FundManager public fundManager;
    ShareToken public shareToken;
    address public fundOwner;
    HelperConfig public helperConfig;

    ERC20 public depositToken;

    address public INVESTOR_1 = makeAddr("investor1");
    address public INVESTOR_2 = makeAddr("investor2");
    address public INVESTOR_3 = makeAddr("investor3");
    address public PORTFOLIO_WALLET = makeAddr("portfolio wallet");

    uint256 public constant INITIAL_INVESTOR_USDC_BALANCE = 1000 * (10 ** 6);
    uint256 public constant USDC_100 = 100 * (10 ** 6);
    uint256 public constant USDC_50 = 50 * (10 ** 6);
    uint256 public constant USDC_10 = 50 * (10 ** 6);

    function setUp() external {
        DeployFundManager deployFundManager = new DeployFundManager();
        (fundManager, shareToken, helperConfig) = deployFundManager.run();

        depositToken = ERC20(helperConfig.getConfig().depositToken);
        fundOwner = helperConfig.getConfig().ownerAdress;

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startPrank(fundOwner);
            console2.log("Dealing funds to investors on Anvil...");
            depositToken.transfer(INVESTOR_1, INITIAL_INVESTOR_USDC_BALANCE);
            depositToken.transfer(INVESTOR_2, INITIAL_INVESTOR_USDC_BALANCE);
            depositToken.transfer(INVESTOR_3, INITIAL_INVESTOR_USDC_BALANCE);
            vm.stopPrank();

            console2.log("Approving fund allowance to investors on Anvil...");

            vm.prank(INVESTOR_1);
            depositToken.approve(
                address(fundManager),
                INITIAL_INVESTOR_USDC_BALANCE
            );

            vm.prank(INVESTOR_2);
            depositToken.approve(
                address(fundManager),
                INITIAL_INVESTOR_USDC_BALANCE
            );

            vm.prank(INVESTOR_3);
            depositToken.approve(
                address(fundManager),
                INITIAL_INVESTOR_USDC_BALANCE
            );
        }
    }

    function testInitialShareTokenTotalSupplyIsZero() external view {
        assertEq(shareToken.totalSupply(), 0);
    }

    function testInitialInvestorBalancesAreCorrect() external view {
        assertEq(
            depositToken.balanceOf(INVESTOR_1),
            INITIAL_INVESTOR_USDC_BALANCE
        );
        assertEq(
            depositToken.balanceOf(INVESTOR_2),
            INITIAL_INVESTOR_USDC_BALANCE
        );
        assertEq(
            depositToken.balanceOf(INVESTOR_3),
            INITIAL_INVESTOR_USDC_BALANCE
        );
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

    function testRevertIfsetPortfolioValueIsCalledOnInactveFund() external {
        vm.prank(fundOwner);
        vm.expectRevert(FundManager.FundManager__FundIsInactive.selector);
        fundManager.setPortfolioValue(1);
    }

    function testSimpleDepositAndWithdraw() external {
        uint256 sharesMinted = _deposit(INVESTOR_1, USDC_100);

        assertEq(fundManager.getTotalDeposited(), USDC_100); // lifetime amount deposited
        assertEq(fundManager.getTreasuryBalance(), USDC_100); //balance in the fund
        assertEq(shareToken.totalSupply(), USDC_100); //total supply of shares

        uint256 investorShares = shareToken.balanceOf(INVESTOR_1);
        assertEq(investorShares, USDC_100); //investor got 100 shares
        assertEq(investorShares, sharesMinted); //we minted the correct amount of shares

        uint256 depositBalanceBeforeRedeem = depositToken.balanceOf(INVESTOR_1); // how much USDC the investor has before redeeming

        uint256 proceeds = _redeem(INVESTOR_1, investorShares / 2); //redeem 50 shares

        assertEq(
            depositToken.balanceOf(INVESTOR_1),
            depositBalanceBeforeRedeem + proceeds
        ); //investor got enough USDC back

        assertEq(fundManager.getTotalDeposited(), USDC_100); // lifetime amount deposited is still the same
        assertEq(fundManager.getTreasuryBalance(), USDC_50); //balance in the fund is now 50

        uint256 newInvestorShares = shareToken.balanceOf(INVESTOR_1);
        assertEq(newInvestorShares, USDC_50); //investor got 50 shares now

        assertEq(shareToken.totalSupply(), USDC_50); //50 shares got burned
    }

    function _deposit(
        address investor,
        uint256 amount
    ) private returns (uint256) {
        vm.prank(investor);
        vm.expectEmit(true, true, false, false);
        emit FundManager.Deposited(investor, amount, 0);
        uint256 sharesMinted = fundManager.depositFunds(amount);
        return sharesMinted;
    }

    function _redeem(
        address investor,
        uint256 shares
    ) private returns (uint256) {
        vm.prank(investor);
        vm.expectEmit(true, true, false, false);
        emit FundManager.Redeemed(investor, shares, 0);
        uint256 proceeds = fundManager.redeemShares(shares);
        return proceeds;
    }

    function updatePortfolioValue(uint256 newValue) private {
        vm.prank(fundOwner);
        fundManager.setPortfolioValue(newValue);
    }
}
