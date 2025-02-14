// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ShareToken} from "../src/ShareToken.sol";

contract DeployShareToken is Script {
    function run() external returns (ShareToken) {
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.ownerAdress);

        ShareToken share = new ShareToken("QCABC FF2 Share", "QCABC-FF2");

        vm.stopBroadcast();

        return share;
    }
}
