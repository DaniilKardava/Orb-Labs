// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {IStrategy, IDelegationManager} from "../lib/eigenlayer-contracts/src/contracts/core/StrategyManager.sol";

contract EigenWithdrawalQueue {
    struct Node {
        int256 next;
        bytes32 root;
        IDelegationManager.Withdrawal order;
    }

    uint256 public length;
    int256 public headIndex;
    int256 public tailIndex;

    mapping(int256 => Node) public withdrawals;

    constructor() {
        length = 0;
        headIndex = 0;
        tailIndex = 0;
    }

    /**
     * Add element to the end of queue.
     * @param root Hashed queuedWithdrawal data used to check pending status.
     * @param queuedWithdrawal withdrawal object used to complete withdrawal.
     */
    function enqueue(
        bytes32 root,
        IDelegationManager.Withdrawal memory queuedWithdrawal
    ) public {
        Node memory newNode = Node(
            withdrawals[tailIndex].next + 1,
            root,
            queuedWithdrawal
        );

        int256 freeIndex = withdrawals[tailIndex].next;
        withdrawals[freeIndex] = newNode;
        tailIndex = freeIndex;

        length++;
    }

    /**
     * Removes the first withdrawal request from the queue.
     */
    function dequeue() public {
        require(length > 0, "Empty queue!");

        if (length == 1) {
            delete withdrawals[headIndex];
            length--;
            tailIndex = 0;
            headIndex = 0;
        } else {
            int256 tempHeadIndex = withdrawals[headIndex].next;
            delete withdrawals[headIndex];
            headIndex = tempHeadIndex;
            length--;
        }
    }

    /**
     * Returns front of queue.
     */
    function peek() public view returns (Node memory) {
        return withdrawals[headIndex];
    }

    /**
     * Returns the total amount being withdrawan from EigenLayer in EigenLayer shares.
     */
    function sumPendingWithdrawalsInShares()
        public
        view
        returns (uint256 pendingWithdrawals)
    {
        int256 index = headIndex;
        while (withdrawals[index].order.withdrawer != address(0)) {
            pendingWithdrawals += withdrawals[index].order.shares[0];
            index = withdrawals[index].next;
        }
    }
}
