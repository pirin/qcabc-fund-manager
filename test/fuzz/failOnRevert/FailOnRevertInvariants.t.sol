// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

// // Invariants:
// // protocol must never be insolvent / undercollateralized
// // users cant create stablecoins with a bad health factor
// // a user should only be able to be liquidated if they have a bad health factor

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {FundManager} from "../../../src/FundManager.sol";
import {ShareToken} from "../../../src/ShareToken.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {DeployFundManager} from "../../../script/DeployFundManager.s.sol";
import {MockUSDC} from "../../mocks/MockUSDC.sol";
import {ContinueOnRevertHandler} from "./FailOnRevertHandler.t.sol";
import {console} from "forge-std/console.sol";
import "../../unit/TestHelpers.sol";

contract ContinueOnRevertInvariants is StdInvariant, Test {
    FundManager public fundManager;
    ShareToken public shareToken;
    MockUSDC public depositToken;
    HelperConfig public helperConfig;
    address FUND_OWNER;

    ContinueOnRevertHandler public handler;

    function setUp() external {
        DeployFundManager deployer = new DeployFundManager();
        (fundManager, shareToken, helperConfig) = deployer.run();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        FUND_OWNER = config.ownerAdress;

        depositToken = MockUSDC(config.depositToken);

        handler = new ContinueOnRevertHandler(fundManager, shareToken, depositToken, FUND_OWNER);
        targetContract(address(handler));
    }

    /// forge-config: default.invariant.fail-on-revert = true
    function invariant_protocolMustHaveValidSharePrice() public view {
        uint256 totalSupply = fundManager.totalFundValue();
        uint256 outstandingShares = fundManager.totalShares();
        uint256 sharePrice = fundManager.sharePrice();

        console.log(
            "==== Total Supply: %s, Shares: %s, Share Price %s",
            totalSupply,
            outstandingShares,
            TestHelpers.toString6(sharePrice)
        );

        assert(sharePrice > 0);
    }

    /// forge-config: default.invariant.fail-on-revert = true
    function invariant_callSummary() public view {
        handler.callSummary();
    }
}
