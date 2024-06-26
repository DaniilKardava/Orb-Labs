// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Test} from "../../../lib/forge-std/src/Test.sol";
import {VaultPriorityWithdrawalQueue, VaultWithdrawalQueue} from "../../../src/VaultPriorityWithdrawalQueue.sol";

/**
 * Handler for VaultPriorityWithdrawalQueue.
 * Additionally, runs fuzz tests for functions during invariant testing.
 */
contract Handler is Test {
    uint256 public dequeueCalls;
    uint256 public removeCalls;
    uint256 public enqueueCalls;
    uint256 public netDeposits;

    VaultPriorityWithdrawalQueue public queue;

    uint256[] public removable; // Tracks removable orders.

    constructor(VaultPriorityWithdrawalQueue queueArg) {
        queue = queueArg;
        enqueueCalls = 0;
        dequeueCalls = 0;
        removeCalls = 0;
    }

    /**
     * Enqueue order. Tag it as 'removable'.
     */
    function enqueue(
        address account,
        uint160 assetsCapped,
        uint256 uid
    ) public {
        // Limit deposit size and then recast for compatability.
        uint256 assets = uint256(assetsCapped);

        queue.enqueue(account, assets, uid);

        // Doesn't execute on revert
        enqueueCalls++;
        removable.push(uid);
        netDeposits += assets;
    }

    /**
     * Dequeue order. Untag it as 'removable'.
     * Assert that the second order is now first.
     */
    function dequeue() public {
        VaultWithdrawalQueue.WithdrawalOrder memory oldHeadOrder = queue
            .peek()
            .order;
        int256 nextIndex = queue.peek().next;
        (, VaultWithdrawalQueue.WithdrawalOrder memory secondOrder) = queue
            .withdrawals(nextIndex);

        // Remove head element
        queue.dequeue();

        // Doesn't execute on revert
        dequeueCalls++;

        // Remove order from list of removables.
        uint256 uidRemoved = oldHeadOrder.uid;
        popElement(uidRemoved);

        // Check that the second item is now the first.
        (, VaultWithdrawalQueue.WithdrawalOrder memory newHeadOrder) = queue
            .withdrawals(queue.headIndex());
        assertEq(secondOrder.account, newHeadOrder.account);
        assertEq(secondOrder.assets, newHeadOrder.assets);
        assertEq(secondOrder.uid, newHeadOrder.uid);

        netDeposits -= oldHeadOrder.assets;
    }

    /**
     * Remove an order by id.
     * Assert that the order is not in queue anymore.
     */
    function removeOrder(uint256 uid) public {
        require(removable.length > 0, "Queue is empty!");
        uint256 idx = uid % removable.length;
        uid = removable[idx];
        popIdx(idx);

        VaultWithdrawalQueue.WithdrawalOrder memory removedOrder = queue
            .removeOrder(uid);

        if (removedOrder.account != address(0)) {
            removeCalls++;
            netDeposits -= removedOrder.assets;
        }

        // For simplicity in testing assume uid is unique. (Clash is unlikely here, though uid is guaranteed to be unique in application)
        assertEq(queue.removeOrder(uid).account, address(0));
    }

    // ====== Internal Helper Methods ====== //

    // Remove element at index but preserve structure.
    function popIdx(uint256 idx) internal {
        removable[idx] = removable[removable.length - 1];
        delete removable[removable.length - 1];
    }

    // Search for index of element and remove.
    function popElement(uint256 uid) internal {
        uint256 idx = 0;
        for (uint256 i = 0; i < removable.length; i++) {
            if (removable[i] == uid) {
                idx = i;
                break;
            }
        }
        popIdx(idx);
    }
}
