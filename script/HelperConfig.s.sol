// SPDX-Licence-Identifier: MIT
pragma solidity ^0.8.18;

import { Script, console } from "forge-std/Script.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import { LinkToken } from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        uint256 subscriptionId;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        address vrfCoordinator;
        address linkToken;
        uint256 deployerKey;
    }

    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    uint96 public constant BASE_FEE = 0.25 ether; // 0.25 LINK
    uint96 public constant GAS_PRICE_LINK = 1e9; // 1 gwei LINK
    int256 public constant WEI_PER_UNIT_LINK = 3972790000000000;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        // If we are on Sepolia Chain
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        // If we are on local anvil chain
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns(NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            subscriptionId: 14212738766281821393516296085324241564256850838725717064186013052943478408591, // Update this later
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 2500000, // 2,500,000
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns(NetworkConfig memory) {
        // Means we already have deployed the network config helper contract
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();

        /* Mocks */

        // Mock the Chainlink VRF contract
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(BASE_FEE, GAS_PRICE_LINK, WEI_PER_UNIT_LINK);
        vm.stopBroadcast();

        // Mock ERC20 Link token contract
        LinkToken linkToken = new LinkToken();

        // Return it's address
        return NetworkConfig({ 
            entranceFee: 0.01 ether,
            interval: 30,
            subscriptionId: 0, // Update this later
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 2500000, // 2,500,000
            vrfCoordinator: address(vrfCoordinatorMock),
            linkToken: address(linkToken),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}