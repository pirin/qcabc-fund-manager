// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MockUSDC} from "../test/mocks/MockUSDC.sol";

contract DeployMockUSDC is Script {
    function run() external returns (MockUSDC) {
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.ownerAdress);

        MockUSDC usdc = new MockUSDC();

        vm.stopBroadcast();

        return usdc;
    }
}
