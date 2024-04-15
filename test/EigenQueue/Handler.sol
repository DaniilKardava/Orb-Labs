// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {EigenWithdrawalQueue, IDelegationManager} from "../../src/EigenWithdrawalQueue.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";

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
     * Enqueue order, increment calls to enqueue, and append removable id.
     */
    function enqueue(
        bytes32 root,
        IDelegationManager.Withdrawal memory order
    ) public {
        // Fuzzer will create arbitrary length arrays, but only considering first elements as in practice.
        order.shares[0] = uint256(uint160(order.shares[0])); // Format to prevent overflow.

        queue.enqueue(root, order);
        // doesnt execute on revert
        enqueueCalls++;

        // Assert new value is at tailIndex
        int256 tailIndex = queue.tailIndex();
        (
            ,
            bytes32 tailRoot,
            IDelegationManager.Withdrawal memory tailOrder
        ) = queue.withdrawals(tailIndex);

        // For simplicity just assert the roots
        assertEq(tailRoot, root);

        netDeposits += tailOrder.shares[0];
    }

    /**
     * Dequeue order, increment calls to dequeue, and remove id of item from removable list.
     * Same implementation for priority and regular queue.
     */
    function dequeue() public {
        IDelegationManager.Withdrawal memory oldHeadOrder = queue.peek().order;
        int256 nextIndex = queue.peek().next;
        (, bytes32 secondRoot, ) = queue.withdrawals(nextIndex);

        // Remove head element
        queue.dequeue();

        // doesnt execute on revert
        dequeueCalls++;

        // Check that the second item is now the first.
        (, bytes32 newHeadRoot, ) = queue.withdrawals(queue.headIndex());

        // For simplicity just assert the roots.
        assertEq(secondRoot, newHeadRoot);

        netDeposits -= oldHeadOrder.shares[0];
    }
}
