// SPDX-Licence-Identifier: MIT
pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";
import "forge-std/console.sol";
import { DeployRaffle } from "../../script/DeployRaffle.s.sol";
import { Raffle } from "../../src/Raffle.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";

import { Vm } from "forge-std/Vm.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    /** Events */
    event EnteredRaffle(
        address indexed player
    );

    event PickedWinner(
        address indexed winner
    );

    Raffle s_raffle;

    address PLAYER = makeAddr("Martin");
    uint256 constant STARTING_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    uint256 subscriptionId;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    address vrfCoordinator;

    function setUp() external {
        // s_fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployRaffle deployer = new DeployRaffle();
        (Raffle raffle, HelperConfig helperConfig) = deployer.run();
        s_raffle = raffle;
        (
            entranceFee,
            interval, 
            subscriptionId, 
            gasLane, 
            callbackGasLimit, 
            vrfCoordinator,
            ,
        ) = helperConfig.activeNetworkConfig(); 
        vm.deal(PLAYER, STARTING_BALANCE);
    }

    modifier enterRaffle() {  
        vm.prank(PLAYER);
        s_raffle.enterRaffle{ value: entranceFee }();
        _;
    }

    function testRaffleIsInitializedInOpenState() public view {
        assert(s_raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testEnterRaffleWithNotEnoughEthSent() public {
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        vm.prank(PLAYER);
        s_raffle.enterRaffle();
    }

    function testEnterRaffleSuccessfully() public {
        vm.prank(PLAYER);
        s_raffle.enterRaffle{ value: entranceFee }();
        assert(s_raffle.getPlayer(0) == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(s_raffle));

        emit EnteredRaffle(PLAYER);

        s_raffle.enterRaffle{ value: entranceFee }();
    }
    
    function testCantEnterWhenRaffleIsCalculating() public {
        vm.warp(block.timestamp + interval + 1);
        vm.prank(PLAYER);
        s_raffle.enterRaffle{ value: entranceFee }();

        s_raffle.performUpkeep("0x0");

        vm.expectRevert(Raffle.Raffle__NotOpened.selector);
        vm.prank(PLAYER);
        s_raffle.enterRaffle{ value: entranceFee }();
    }

    function testCheckUpKeepHasNotBalance() public {
        vm.warp(block.timestamp + interval + 1);
        (bool upkeepNeeded, ) = s_raffle.checkUpkeep("0x0");
        
        assert(upkeepNeeded == false);
    }

    function testCheckUpKeepRaffleNotOpened() public {
        vm.warp(block.timestamp + interval + 1);
        vm.prank(PLAYER);
        s_raffle.enterRaffle{ value: entranceFee }();

        s_raffle.performUpkeep("0x0");

        (bool upkeepNeeded, ) = s_raffle.checkUpkeep("0x0");

        assert(upkeepNeeded == false);
    }

    function testCheckUpKeepTimeNotPassed() public {
        // Make block current timestamp equal to => block.timestamp + interval + 10
        vm.warp(block.timestamp);
        vm.roll(block.number + 1);

        vm.prank(PLAYER);
        s_raffle.enterRaffle{ value: entranceFee }();

        (bool upkeepNeeded, ) = s_raffle.checkUpkeep("0x0");

        assert(upkeepNeeded == false);
    }

    function testCheckUpKeepWhenEverythingIsGood() public {
        vm.warp(block.timestamp + interval + 1);
        vm.prank(PLAYER);
        s_raffle.enterRaffle{ value: entranceFee }();

        (bool upkeepNeeded, ) = s_raffle.checkUpkeep("0x0");

        assert(upkeepNeeded == true);
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        s_raffle.enterRaffle{ value: entranceFee }();
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 raffleBalance = 0;
        uint256 playersCount = 0;
        uint256 raffleState = 0;

        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, raffleBalance, playersCount, raffleState));
        s_raffle.performUpkeep("0x0");
    }

    // When running this test foundry will create multiple tests with randomly regenerated requestIds
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(s_raffle));
    }

    function testFulfillRandomWordsWorksProperly() public raffleEntered skipFork {
        uint160 people = 6;

        // 5 players + 1 initial PLAYER
        for (uint160 i = 1; i < people; i++) {
            address randomPlayer = address(i);
            vm.prank(randomPlayer);
            vm.deal(randomPlayer, STARTING_BALANCE);
            s_raffle.enterRaffle{ value: entranceFee }();
        }

        uint256 initialTimestamp = s_raffle.getLastTimestamp();
        uint256 raffleBalance = address(s_raffle).balance;

        vm.warp(block.timestamp + interval + 1);

        vm.recordLogs();
        s_raffle.performUpkeep("0x0");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32[] memory topics = entries[1].topics;
        uint256 requestId = uint256(topics[1]);

        vm.recordLogs();
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestId, address(s_raffle));
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bool eventFound = false;
        address winner;

        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("PickedWinner(address)")) {
                winner = address(uint160(uint256(logs[i].topics[1])));
                eventFound = true;
                break;
            }
        }
        
        uint256 updatedTimestamp = s_raffle.getLastTimestamp();

        assert(eventFound == true);
        assert(s_raffle.getRecentWinner() != address(0));
        assert(s_raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(s_raffle.getPlayersCount() == 0);
        assert(s_raffle.getRecentWinner().balance == raffleBalance + STARTING_BALANCE - entranceFee);
        assert(updatedTimestamp > initialTimestamp);
    }
}
