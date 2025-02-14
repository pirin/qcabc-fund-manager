// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {FundManager} from "../src/FundManager.sol";
import {ShareToken} from "../src/ShareToken.sol";

contract DeployFundManager is Script {
    function run() external returns (FundManager, ShareToken, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.ownerAdress);

        //Create a new ShareToken
        ShareToken share;
        if (config.shareToken == address(0)) {
            share = new ShareToken("QCABC FF2 Share", "QCABC-FF2");
            console.log("!!! Deployed a new ShareToken contract!");
        } else {
            share = ShareToken(config.shareToken);
            console.log("!!! Using existing ShareToken contract: ", config.shareToken);
        }

        //Create a new FundManager
        FundManager manager = new FundManager(config.depositToken, address(share));

        //Set the fund manager in the share token
        share.setFundManager(address(manager));

        vm.stopBroadcast();

        // We already have a broadcast in here
        return (manager, share, helperConfig);
    }
}
