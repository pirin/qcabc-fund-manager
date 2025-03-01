// Commented out for now until revert on fail == false per function customization is implemented

// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Test} from "forge-std/Test.sol";
import {FundManager} from "../../../src/FundManager.sol";
import {ShareToken} from "../../../src/ShareToken.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {DeployFundManager} from "../../../script/DeployFundManager.s.sol";
import {MockUSDC} from "../../mocks/MockUSDC.sol";
import {console} from "forge-std/console.sol";
import "../../unit/TestHelpers.sol";

contract ContinueOnRevertHandler is Test {
    // Deployed contracts to interact with
    FundManager public fundManager;
    ShareToken public shareToken;
    MockUSDC public usdc;
    address public FUND_OWNER;

    address[] investors;

    // Ghost Variables
    uint96 public constant MIN_DEPOSIT_SIZE = 1 * (10 ** 6);
    uint96 public constant MAX_DEPOSIT_SIZE = 100000 * (10 ** 6);
    uint96 public constant MAX_FUND_VALUE = 10000000 * (10 ** 6);

    constructor(FundManager _manager, ShareToken _token, MockUSDC _depositToken, address fundOwner) {
        fundManager = _manager;
        shareToken = _token;
        usdc = _depositToken;

        FUND_OWNER = fundOwner;

        _createInvestor("INVESTOR_1");
        _createInvestor("INVESTOR_2");
        _createInvestor("INVESTOR_3");
    }

    function depositFunds(uint256 investorSeed, uint256 depositAmount) public {
        depositAmount = bound(depositAmount, MIN_DEPOSIT_SIZE, MAX_DEPOSIT_SIZE);
        address investor = _getInvestorFromSeed(investorSeed);

        uint256 investorBalance = usdc.balanceOf(investor);
        uint256 investorAllowance = usdc.allowance(investor, address(fundManager));

        console.log(
            ">>> Depositing funds... Amount: %s:, Balance: %s, Allowance: %s, ",
            TestHelpers.toString6(depositAmount),
            TestHelpers.toString6(investorBalance),
            TestHelpers.toString6(investorAllowance)
        );

        console.log("   Total Find Value before deposit: %s USDC", TestHelpers.toString6(fundManager.totalFundValue()));
        console.log("   Share Price before deposit: %s", TestHelpers.toString6(fundManager.sharePrice()));

        //top up their funds as needed
        if (investorBalance < depositAmount) {
            console.log(
                "   Toping up investor funds... with %s", TestHelpers.toString6(depositAmount - investorBalance)
            );
            usdc.mint(investor, depositAmount - investorBalance);
        }

        if (investorAllowance < depositAmount) {
            console.log("   Adjusting investor allowance... to %s", TestHelpers.toString6(depositAmount));
            vm.prank(investor);
            usdc.approve(address(fundManager), depositAmount);
        }

        vm.prank(investor);
        uint256 sharesReceived = fundManager.depositFunds(depositAmount);

        console.log("   Investor got: %s shares", TestHelpers.toString6(sharesReceived));

        console.log("   Total Find Value after deposit: %s USDC", TestHelpers.toString6(fundManager.totalFundValue()));
        console.log("   Share Price after deposit: %s", TestHelpers.toString6(fundManager.sharePrice()));
    }

    function redeemShares(uint256 investorSeed, uint256 amountShares) public {
        address investor = _getInvestorFromSeed(investorSeed);

        //Redeem up to the shares they have
        amountShares = bound(amountShares, 0, shareToken.balanceOf(investor));

        //Need at least some shares to redeem
        if (amountShares == 0) {
            return;
        }

        uint256 treasuryBalance = usdc.balanceOf(address(fundManager));
        uint256 sharePrice = fundManager.sharePrice();
        uint256 redeemValue = amountShares * sharePrice / (10 ** shareToken.decimals());

        console.log(
            "<<< Redeeming %s shares... Needed: %s, Availalble: %s",
            TestHelpers.toString6(amountShares),
            TestHelpers.toString6(redeemValue),
            TestHelpers.toString6(treasuryBalance)
        );

        console.log("   Total Find Value before redeem: %s USDC", TestHelpers.toString6(fundManager.totalFundValue()));
        console.log("   Share Price before redeem: %s", TestHelpers.toString6(fundManager.sharePrice()));

        //top up the treasury as needed
        if (redeemValue > treasuryBalance) {
            console.log("   Toping up treasury funds... with %s", TestHelpers.toString6(redeemValue - treasuryBalance));
            usdc.mint(address(fundManager), redeemValue - treasuryBalance);
        }

        vm.prank(investor);
        fundManager.redeemShares(amountShares);

        console.log("   Treasury Balance After redeem: %s", TestHelpers.toString6(usdc.balanceOf(address(fundManager))));
        console.log("   Total Find Value after redeem: %s USDC", TestHelpers.toString6(fundManager.totalFundValue()));
        console.log("   Share Price after redeem: %s", TestHelpers.toString6(fundManager.sharePrice()));
    }

    function updateFundValue(uint128 newValue) public {
        //Can't update value if there are no shares
        if (shareToken.totalSupply() == 0) {
            return;
        }

        uint256 intNewValue = bound(newValue, 0, MAX_FUND_VALUE);
        vm.prank(FUND_OWNER);
        fundManager.setPortfolioValue(intNewValue);

        console.log("----------------- Portfolio Value Updated to: %s", TestHelpers.toString6(intNewValue));
    }

    /// Helper Functions
    function _getInvestorFromSeed(uint256 collateralSeed) private view returns (address) {
        return investors[collateralSeed % investors.length];
    }

    function callSummary() external view {
        console.log("Fund Value: ", fundManager.totalFundValue());
        console.log("Share Price", fundManager.sharePrice());
        console.log("Number of Shares", fundManager.totalShares());
    }

    function _createInvestor(string memory name) private {
        address investor = makeAddr(name);
        investors.push(investor);
        usdc.mint(investor, 100 * (10 ** 6));
        vm.prank(investor);
        usdc.approve(address(fundManager), 100 * (10 ** 6));
    }
}
