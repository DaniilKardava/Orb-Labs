// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {IStrategy} from "../lib/eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";

contract EigenWithdrawalQueue {
    /// COPIED FROM EIGENLAYER
    struct WithdrawerAndNonce {
        address withdrawer;
        uint96 nonce;
    }

    /**
     * COPIED FROM EIGENLAYER
     * Struct type used to specify an existing queued withdrawal. Rather than storing the entire struct, only a hash is stored.
     * In functions that operate on existing queued withdrawals -- e.g. `startQueuedWithdrawalWaitingPeriod` or `completeQueuedWithdrawal`,
     * the data is resubmitted and the hash of the submitted data is computed by `calculateWithdrawalRoot` and checked against the
     * stored hash in order to confirm the integrity of the submitted data.
     */
    struct QueuedWithdrawal {
        IStrategy[] strategies;
        uint256[] shares;
        address depositor;
        WithdrawerAndNonce withdrawerAndNonce;
        uint32 withdrawalStartBlock;
        address delegatedAddress;
    }

    struct Node {
        int256 next;
        bytes32 root;
        QueuedWithdrawal order;
    }

    uint256 internal length;
    int256 internal headIndex;
    int256 internal tailIndex;

    mapping(int256 => Node) internal withdrawals;

    constructor() {}

    /**
     * Add element to the end of queue.
     * @param root Hashed queuedWithdrawal data used to check pending status.
     * @param queuedWithdrawal withdrawal object used to complete withdrawal.
     */
    function enqueue(
        bytes32 root,
        QueuedWithdrawal memory queuedWithdrawal
    ) public virtual {
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
    function dequeue() public virtual {
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
    function getLength() public returns (uint256) {
        return length;
    }

    /**
     * Returns the total amount being withdrawan from EigenLayer in EigenLayer shares.
     */
    function sumPendingWithdrawalsInShares()
        public
        returns (uint256 pendingWithdrawals)
    {
        int256 index = headIndex;
        while (withdrawals[index].order.depositor != address(0)) {
            pendingWithdrawals += withdrawals[index].order.shares[0];
            index = withdrawals[index].next;
        }
    }
}
