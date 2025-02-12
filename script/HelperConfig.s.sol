// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {MockUSDC} from "../test/mocks/MockUSDC.sol";

abstract contract CodeConstants {
    address public ANVIL_CONTRACT_CREATOR = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    address public constant BASE_SEPOLIA_CONTRACT_CREATOR = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; //Change for each network

    uint256 public constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
    // ========== ERRORS ==========
    error HelperConfig__InvalidChainId();

    // ========== TYPES ==========
    struct NetworkConfig {
        address depositToken;
        address ownerAdress;
    }

    // ========== STATE VARIABLES ==========
    // Local network state variables
    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    // ========== CONSTRUCTOR ==========
    constructor() {
        networkConfigs[BASE_SEPOLIA_CHAIN_ID] = getBaseSepoliaEthConfig();
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getMainnetEthConfig();
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

    function getMainnetEthConfig() public pure returns (NetworkConfig memory mainnetNetworkConfig) {
        mainnetNetworkConfig = NetworkConfig({
            depositToken: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC
            ownerAdress: BASE_SEPOLIA_CONTRACT_CREATOR
        });
    }

    function getBaseSepoliaEthConfig() public pure returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            depositToken: 0xE4aB69C077896252FAFBD49EFD26B5D171A32410, // USDC
            ownerAdress: BASE_SEPOLIA_CONTRACT_CREATOR
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

        localNetworkConfig = NetworkConfig({depositToken: address(usdc), ownerAdress: ANVIL_CONTRACT_CREATOR});
        vm.deal(localNetworkConfig.ownerAdress, 100 ether);
        return localNetworkConfig;
    }
}
