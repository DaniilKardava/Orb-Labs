// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {VaultWithdrawalQueue} from "./VaultWithdrawalQueue.sol";
import {console} from "../lib/forge-std/src/Test.sol";

/**
 * Link based priority queue with pointers to mapping indices. Tailnode.next always points to open index.
 */
contract VaultPriorityWithdrawalQueue is VaultWithdrawalQueue {
    constructor() VaultWithdrawalQueue() {}

    /**
     * Override VaultWithdrawalQueue to maintain ascending order by withdrawal amount.
     */
    function enqueue(
        address account,
        uint256 assets,
        uint256 uid
    ) public override {
        require(account != address(0), "Cannot send to void!");

        int256 index = headIndex;
        int256 prevIndex;

        while (
            (withdrawals[index].order.account != address(0)) &&
            (assets >= withdrawals[index].order.assets)
        ) {
            prevIndex = index;
            index = withdrawals[index].next;
        }

        if (withdrawals[index].order.account == address(0)) {
            // End of Queue
            Node memory newNode = Node(
                withdrawals[tailIndex].next + 1, // Keep pointing to void.
                WithdrawalOrder(account, assets, uid)
            );
            int256 freeIndex = withdrawals[tailIndex].next;
            withdrawals[freeIndex] = newNode;
            tailIndex = freeIndex;
        } else {
            Node memory newNode = Node(
                index,
                WithdrawalOrder(account, assets, uid)
            );
            int256 freeIndex = withdrawals[tailIndex].next;
            withdrawals[freeIndex] = newNode;

            withdrawals[tailIndex].next += 1; // Keep pointing to void.

            if (index == headIndex) {
                headIndex = freeIndex;
            } else {
                withdrawals[prevIndex].next = freeIndex;
            }
        }
        length++;
    }

    /**
     * Sum all pending withdrawals.
     */
    function sumPendingWithdrawals()
        public
        view
        returns (uint256 pendingWithdrawals)
    {
        int256 index = headIndex;
        while (withdrawals[index].order.account != address(0)) {
            pendingWithdrawals += withdrawals[index].order.assets;
            index = withdrawals[index].next;
        }
    }
}
