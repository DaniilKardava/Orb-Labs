// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {EigenWithdrawalQueue, IDelegationManager} from "../../src/EigenWithdrawalQueue.sol";
import {Test} from "../../lib/forge-std/src/Test.sol";

/**
 * Handler for EigenWithdrawalQueue.
 * Additionally, runs fuzz tests for functions during invariant testing.
 */
contract Handler is Test {
    uint256 public dequeueCalls;
    uint256 public enqueueCalls;
    uint256 public netDeposits;

    EigenWithdrawalQueue public queue;

    constructor(EigenWithdrawalQueue queueArg) {
        queue = queueArg;
        enqueueCalls = 0;
        dequeueCalls = 0;
    }

    /**
     * Enqueue an item and assert that the new item is at the tail.
     */
    function enqueue(
        bytes32 root,
        IDelegationManager.Withdrawal memory order
    ) public {
        // Fuzzer will create arbitrary length arrays, but pretend that the array has length 1.
        order.shares[0] = uint256(uint160(order.shares[0])); // Format to prevent overflow.

        queue.enqueue(root, order);
        // Doesnt execute on revert
        enqueueCalls++;

        // Assert new value is at tailIndex
        int256 tailIndex = queue.tailIndex();
        (
            ,
            bytes32 tailRoot,
            IDelegationManager.Withdrawal memory tailOrder
        ) = queue.withdrawals(tailIndex);

        // For simplicity just assert the roots are equal.
        assertEq(tailRoot, root);

        netDeposits += tailOrder.shares[0];
    }

    /**
     * Dequeue an item and assert that the second item is now first.
     */
    function dequeue() public {
        IDelegationManager.Withdrawal memory oldHeadOrder = queue.peek().order;
        int256 nextIndex = queue.peek().next;
        (, bytes32 secondRoot, ) = queue.withdrawals(nextIndex);

        // Remove head element
        queue.dequeue();

        // Doesn't execute on revert
        dequeueCalls++;

        // Check that the second item is now the first.
        (, bytes32 newHeadRoot, ) = queue.withdrawals(queue.headIndex());

        // For simplicity just assert the roots are equal.
        assertEq(secondRoot, newHeadRoot);

        netDeposits -= oldHeadOrder.shares[0];
    }
}
