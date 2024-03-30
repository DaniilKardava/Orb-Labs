// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {VaultWithdrawalQueue} from "./VaultWithdrawalQueue.sol";

contract VaultPriorityWithdrawalQueue is VaultWithdrawalQueue {
    constructor() WithdrawalQueue() {}

    /**
     * Organize withdrawal requests by size.
     */
    function enqueue(address account, uint256 amount) public override {
        int256 index = headIndex;
        int256 prevIndex;
        while (amount >= withdrawals[index].order.amount) {
            prevIndex = index;
            index = withdrawals[index].next;
        }

        Node memory newNode = Node(index, WithdrawalOrder(account, amount));
        withdrawals[tailNode.next] = newNode;

        if (index == headIndex) {
            headNode = newNode;
            headIndex = tailNode.next;
        } else {
            withdrawals[prevIndex].next = tailNode.next;
        }

        length++;
    }

    /**
     * Remove the highest priority withdrawal request.
     */
    function dequeue() public override {
        require(getLength() > 0, "Empty queue!");
        int256 tempHeadIndex = headNode.next;

        headNode = withdrawals[headNode.next];
        delete withdrawals[headIndex];

        headIndex = tempHeadIndex;
        length--;
    }

    /**
     * Sum all pending withdrawals.
     */
    function sumPendingWithdrawals()
        public
        returns (uint256 pendingWithdrawals)
    {
        uint256 pendingWithdrawals;
        int256 index = headIndex;
        while (withdrawals[index].order.address != address(0)) {
            pendingWithdrawals += withdrawals[index].order.amount;
            index = withdrawals[index].next;
        }
    }
}
