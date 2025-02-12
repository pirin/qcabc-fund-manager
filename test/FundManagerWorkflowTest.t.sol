// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {FundManager} from "../src/FundManager.sol";
import {ShareToken} from "../src/ShareToken.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {FundManagerBase} from "./FundManagerBase.sol";

contract FundManagerWorkflowTest is FundManagerBase {
    function testSimpleWorkflowDepositAndWithdraw() external {
        uint256 sharesMinted = _deposit(INVESTOR_1, USDC_100);
        assertEq(sharesMinted, SHARES_100);
        uint256 proceeds = _redeem(INVESTOR_1, sharesMinted / 2); //redeem half the  shares
        assertEq(proceeds, USDC_50);
    }

    function testComplexWorkflowDepositAndWithdraw() external {
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
}
