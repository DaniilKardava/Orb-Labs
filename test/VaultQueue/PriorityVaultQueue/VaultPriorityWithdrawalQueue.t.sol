// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Handler, VaultPriorityWithdrawalQueue} from "./Handler.sol";
import {Test, console} from "../../../lib/forge-std/src/Test.sol";
import {RandomGenerator} from "../../RandomGenerator.sol";
import {VaultWithdrawalQueue} from "../../../src/VaultWithdrawalQueue.sol";

/**
 * Test the vault withdrawal queue. Many function asserts are written inside the handler.
 */
contract TestVaultPriorityQueue is Test {
    VaultPriorityWithdrawalQueue internal priorityQueue;
    Handler internal handler;
    RandomGenerator internal randomGenerator;
    uint256 internal constant MAX_INITIAL_Q = 10;

    function setUp() public {
        priorityQueue = new VaultPriorityWithdrawalQueue();

        handler = new Handler(priorityQueue);
        randomGenerator = new RandomGenerator();

        targetContract(address(handler));

        // Populate queue with random entries.
        uint256 salt = 123143329;
        for (uint256 i = 0; i < MAX_INITIAL_Q; i++) {
            // Generate random values
            address rAddress = randomGenerator.randomAddress(salt);
            uint256 rAmount = randomGenerator.randomUint(salt);
            uint256 rUid = randomGenerator.randomUint(rAmount);

            handler.enqueue(rAddress, uint160(rAmount), rUid);

            salt = rUid; // Update seed
        }
    }

    /**
     * Check that the queue accurately tracks total pending withdrawals.
     */
    function invariant_sum_deposits() public view {
        assertGe(priorityQueue.sumPendingWithdrawals(), handler.netDeposits());
    }

    /**
     * Test that objects are in order of deposits.
     */
    function invariant_in_order() public view {
        (
            int256 idx,
            VaultWithdrawalQueue.WithdrawalOrder memory prevOrder
        ) = priorityQueue.withdrawals(priorityQueue.headIndex());
        VaultWithdrawalQueue.WithdrawalOrder
            memory newOrder = VaultWithdrawalQueue.WithdrawalOrder(
                address(0),
                0,
                0
            );

        // it takes length - 1 steps to get from start to finish of queue, so begin at 1.
        for (uint256 i = 1; i < priorityQueue.length(); i++) {
            (idx, newOrder) = priorityQueue.withdrawals(idx);
            assertGe(newOrder.assets, prevOrder.assets);
            prevOrder = newOrder;
        }
    }

    /**
     * Test that the length of the queue is the net of enqueue, dequeue, and remove calls.
     */
    function invariant_queue_length() public view {
        uint256 netCalls = handler.enqueueCalls() -
            handler.removeCalls() -
            handler.dequeueCalls();
        assertEq(priorityQueue.length(), netCalls);
    }

    /**
     * Checks that queue can be traversed from head to tail in exactly "length" steps
     */
    function invariant_can_traverse() public view {
        int256 idx = priorityQueue.headIndex();
        // it takes length - 1 steps to get from start to finish of queue, so begin at 1.
        for (uint256 i = 1; i < priorityQueue.length(); i++) {
            (idx, ) = priorityQueue.withdrawals(idx);
        }
        assertEq(idx, priorityQueue.tailIndex());
    }

    /**
     * Assert that tail is always pointing to void. Then elements can be added without concern of overwriting existing data.
     */
    function invariant_tail_points_void() public view {
        (int256 freeIdx, ) = priorityQueue.withdrawals(
            priorityQueue.tailIndex()
        );
        (
            ,
            VaultPriorityWithdrawalQueue.WithdrawalOrder memory order
        ) = priorityQueue.withdrawals(freeIdx);
        assertEq(order.account, address(0));
    }
}
