// SPDX-Licence-Identifier: MIT
pragma solidity ^0.8.18;

import { Script, console } from "forge-std/Script.sol";
import { Raffle } from "../src/Raffle.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { CreateSubscription, FundSubscription, AddConsumer } from "./Interactions.s.sol";

contract DeployRaffle is Script {

    function run() external returns(Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entranceFee,
            uint256 interval, 
            uint256 subscriptionId, 
            bytes32 gasLane, 
            uint32 callbackGasLimit, 
            address vrfCoordinator,
            address linkToken,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig(); 

        // SubscriptId = 0 will be only on local anvil chain
        if (subscriptionId == 0) {
            // If we don't have a valid subscrptionId - create a new one
            CreateSubscription createSubscription = new CreateSubscription();
            uint256 subId = createSubscription.createSubscription(vrfCoordinator, deployerKey);
            subscriptionId = subId;

            // Fund it
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fund(subscriptionId, vrfCoordinator, linkToken, deployerKey);
        }

        
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            subscriptionId,
            gasLane,
            interval,
            callbackGasLimit,
            entranceFee,
            vrfCoordinator
        );
        vm.stopBroadcast();
        
        // Add consumer
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(subscriptionId, vrfCoordinator, address(raffle), deployerKey);

        
        return (raffle, helperConfig);
    }
}