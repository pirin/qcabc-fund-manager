// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {DeployFundManager} from "../script/DeployFundManager.s.sol";
import {FundManager} from "../src/FundManager.sol";
import {ShareToken} from "../src/ShareToken.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Helpers} from "../../script/Helpers.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

contract FundManagerTest is Test, CodeConstants {
    FundManager public fundManager;
    ShareToken public shareToken;
    address public FUND_OWNER;
    HelperConfig public helperConfig;
    Helpers public helpers;

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
        helpers = new Helpers();

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

    // ==================== Investment Workflow Tests ====================
    function testSimpleDepositAndWithdraw() external {
        uint256 sharesMinted = _deposit(INVESTOR_1, USDC_100);
        assertEq(sharesMinted, SHARES_100);
        uint256 proceeds = _redeem(INVESTOR_1, sharesMinted / 2); //redeem half the  shares
        assertEq(proceeds, USDC_50);
    }

    function testComplexDepositAndWithdraw() external {
        //deposit 100 USDC
        uint256 sharesMinted1 = _deposit(INVESTOR_1, USDC_100);
        assertEq(sharesMinted1, SHARES_100);

        //deposit 50 USDC
        uint256 sharesMinted2 = _deposit(INVESTOR_2, USDC_50);
        assertEq(sharesMinted2, SHARES_50);

        //check balances
        assertEq(fundManager.getTreasuryBalance(), USDC_50 + USDC_100);
        assertEq(shareToken.totalSupply(), sharesMinted1 + sharesMinted2);
        assertEq(fundManager.getSharePrice(), 1 * 10 ** shareToken.decimals());
        assertEq(fundManager.getFundValue(), USDC_50 + USDC_100);

        //_printFundInfo();

        //do some investments
        _invest(USDC_150); //portfolio value is automatically adjusted for

        //fund increased in value by 50 USDC
        _adjustPortfolioValue(USDC_200); //potfolio is now worth 200 USDC (more than the cost basis)

        uint256 sharesMinted3 = _deposit(INVESTOR_3, USDC_100);
        assertEq(sharesMinted3, 75000018);

        uint256 sharesMinted4 = _deposit(INVESTOR_4, USDC_100);
        assertEq(sharesMinted4, 75000018);

        //fund decreased in value by 150 USDC
        _adjustPortfolioValue(USDC_50); //potfolio is now worth 50 USDC (less than the cost basis)

        uint256 sharesMinted5 = _deposit(INVESTOR_5, USDC_100);
        assertEq(sharesMinted5, 120000048);

        _printFundInfo();
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

    // ==================== helper functions ====================
    function _dealAndApprove(address investor, uint256 amount) private {
        vm.prank(FUND_OWNER);
        depositToken.transfer(investor, amount);

        vm.prank(investor);
        depositToken.approve(address(fundManager), amount);
    }

    function _deposit(address investor, uint256 amount) private returns (uint256) {
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
            "=====> Investor Deposited ", amount / 1000000, " USDC. Shares minted: ", helpers.toString6(sharesMinted)
        );

        return sharesMinted;
    }

    function _redeem(address investor, uint256 shares) private returns (uint256) {
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

        return proceeds;
    }

    function _adjustPortfolioValue(uint256 newPortfolioValue) private returns (uint256) {
        console.log("\n===== Adjusting portfolio value to: ", helpers.toString6(newPortfolioValue), " USDC");

        vm.prank(FUND_OWNER);
        vm.expectEmit(true, false, false, false);
        emit FundManager.PortfolioUpdated(newPortfolioValue, 0, 0);
        uint256 actualPortfolioValue = fundManager.setPortfolioValue(newPortfolioValue);

        assertEq(newPortfolioValue, fundManager.getPortfolioValue());

        return actualPortfolioValue;
    }

    function _invest(uint256 amount) private {
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

        console.log("\n===== Fund Invested ", helpers.toString6(amount), " USDC");
    }

    function _printFundInfo() private view {
        console.log("Fund Info:");
        console.log("   Total Fund Value:  ", helpers.toString6(fundManager.getFundValue()), " USDC");
        console.log("   Treasury Balance:  ", helpers.toString6(fundManager.getTreasuryBalance()), "USDC");
        console.log("   Portfolio Value:   ", helpers.toString6(fundManager.getPortfolioValue()), " USDC");
        console.log("   Share Price:       ", helpers.toString6(fundManager.getSharePrice()), " USDC");
        console.log("   Share Total Supply:", helpers.toString6(shareToken.totalSupply()), " Shares");

        //print incvestor balance and shares owned on the same line
        console.log("\nCap Table:");
        console.log(
            "   Investor 1: - Balance:",
            helpers.toString6(depositToken.balanceOf(INVESTOR_1)),
            "USDC, Shares: ",
            helpers.toString6(shareToken.balanceOf(INVESTOR_1))
        );
        console.log(
            "   Investor 2: - Balance:",
            helpers.toString6(depositToken.balanceOf(INVESTOR_2)),
            "USDC, Shares: ",
            helpers.toString6(shareToken.balanceOf(INVESTOR_2))
        );
        console.log(
            "   Investor 3: - Balance:",
            helpers.toString6(depositToken.balanceOf(INVESTOR_3)),
            "USDC, Shares: ",
            helpers.toString6(shareToken.balanceOf(INVESTOR_3))
        );
        console.log(
            "   Investor 4: - Balance:",
            helpers.toString6(depositToken.balanceOf(INVESTOR_4)),
            "USDC, Shares: ",
            helpers.toString6(shareToken.balanceOf(INVESTOR_4))
        );
        console.log(
            "   Investor 5: - Balance:",
            helpers.toString6(depositToken.balanceOf(INVESTOR_5)),
            "USDC, Shares: ",
            helpers.toString6(shareToken.balanceOf(INVESTOR_5))
        );
        console.log(
            "   Investor 6: - Balance:",
            helpers.toString6(depositToken.balanceOf(INVESTOR_6)),
            "USDC, Shares: ",
            helpers.toString6(shareToken.balanceOf(INVESTOR_6))
        );
    }
}
