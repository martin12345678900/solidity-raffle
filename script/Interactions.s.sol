// SPDX-Licence-Identifier: MIT
pragma solidity ^0.8.18;

import { Script, console } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import { LinkToken } from "../test/mocks/LinkToken.sol";
import { DevOpsTools } from "lib/foundry-devops/src/DevOpsTools.sol";
import { Raffle } from "../src/Raffle.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns(uint256) {
        HelperConfig helperConfig = new HelperConfig();
        (, , , , , address vrfCoordinator, , uint256 deployerKey) = helperConfig.activeNetworkConfig(); 

        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(address vrfCoordinator, uint256 deployerKey) public returns (uint256) {
        vm.startBroadcast(deployerKey);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        return subId;
    }

    function run() external returns(uint256) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint256 public constant FUND_AMOUNT = 100 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (, , uint256 subscriptionId, , , address vrfCoordinator, address linkToken, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        fund(subscriptionId, vrfCoordinator, linkToken, deployerKey);
    }
    
    function fund(uint256 _subId, address vrfCoordinator, address linkToken, uint256 deployerKey) public {
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(_subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(_subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {

    function addConsumerUsingConfig(address raffleAddress) public {
        HelperConfig helperConfig = new HelperConfig();
        (, , uint256 subscriptionId, , , address vrfCoordinator, , uint256 deployerKey) = helperConfig.activeNetworkConfig();

        addConsumer(subscriptionId, vrfCoordinator, raffleAddress, deployerKey);
    }
    
    function addConsumer(uint256 _subId, address vrfCoordinator, address raffleAddress, uint256 deployerKey) public {
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(_subId, raffleAddress);
        vm.stopBroadcast();
    }

    function run() external {
        address raffleAddress = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(raffleAddress);
    }
}