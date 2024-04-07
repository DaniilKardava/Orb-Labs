// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {IStrategy, IStrategyManager} from "../lib/eigenlayer-contracts/src/contracts/core/StrategyManager.sol";

contract EigenWithdrawalQueue {
    struct Node {
        int256 next;
        bytes32 root;
        IStrategyManager.QueuedWithdrawal order;
    }

    uint256 internal length;
    int256 internal headIndex;
    int256 internal tailIndex;

    mapping(int256 => Node) internal withdrawals;

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
        IStrategyManager.QueuedWithdrawal memory queuedWithdrawal
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
        require(getLength() > 0, "Empty queue!");

        int256 tempHeadIndex = withdrawals[headIndex].next;

        delete withdrawals[headIndex];

        headIndex = tempHeadIndex;
        length--;
    }

    /**
     * Returns front of queue.
     */
    function peek() public view returns (Node memory) {
        return withdrawals[headIndex];
    }

    /**
     * Returns queue length.
     */
    function getLength() public view returns (uint256) {
        return length;
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
        while (withdrawals[index].order.depositor != address(0)) {
            pendingWithdrawals += withdrawals[index].order.shares[0];
            index = withdrawals[index].next;
        }
    }
}
