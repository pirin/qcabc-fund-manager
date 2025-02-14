// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {MockUSDC} from "../test/mocks/MockUSDC.sol";

abstract contract CodeConstants {
    address public ANVIL_CONTRACT_CREATOR = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    uint256 public constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 public constant BASE_MAINNET_CHAIN_ID = 8453;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
    // ========== ERRORS ==========
    error HelperConfig__InvalidChainId();

    // ========== TYPES ==========
    struct NetworkConfig {
        address depositToken;
        address ownerAdress;
        address shareToken;
    }

    // ========== STATE VARIABLES ==========
    // Local network state variables
    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    // ========== CONSTRUCTOR ==========
    constructor() {
        networkConfigs[BASE_SEPOLIA_CHAIN_ID] = getBaseSepoliaEthConfig();
        networkConfigs[BASE_MAINNET_CHAIN_ID] = getBaseMainnetEthConfig();
        // Note: We skip doing the local config
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function setConfig(uint256 chainId, NetworkConfig memory networkConfig) public {
        networkConfigs[chainId] = networkConfig;
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].depositToken != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getBaseMainnetEthConfig() public view returns (NetworkConfig memory mainnetNetworkConfig) {
        mainnetNetworkConfig = NetworkConfig({
            depositToken: vm.envAddress("BASE_MAINNET_DEPOSIT_TOKEN"),
            shareToken: vm.envAddress("BASE_MAINNET_SHARE_TOKEN"),
            ownerAdress: vm.envAddress("BASE_MAINNET_OWNER_WALLET_ADDRESS")
        });
    }

    function getBaseSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            depositToken: vm.envAddress("BASE_SEPOLIA_DEPOSIT_TOKEN"),
            shareToken: vm.envAddress("BASE_SEPOLIA_SHARE_TOKEN"),
            ownerAdress: vm.envAddress("BASE_SEPOLIA_OWNER_WALLET_ADDRESS")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // Check to see if we set an active network config
        if (localNetworkConfig.depositToken != address(0)) {
            return localNetworkConfig;
        }

        console2.log(unicode"!!! Deployed a mock USDC contract!");

        vm.startBroadcast(ANVIL_CONTRACT_CREATOR);
        MockUSDC usdc = new MockUSDC();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            depositToken: address(usdc),
            ownerAdress: ANVIL_CONTRACT_CREATOR,
            shareToken: vm.envAddress("ANVIL_SHARE_TOKEN")
        });
        vm.deal(localNetworkConfig.ownerAdress, 100 ether);
        return localNetworkConfig;
    }
}
