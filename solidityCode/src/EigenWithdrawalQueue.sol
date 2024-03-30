// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract WithdrawalQueue {
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

    Node internal headNode;
    Node internal tailNode;
    uint256 internal length;
    int256 internal headIndex; // For deleting.

    mapping(int256 => Node) internal withdrawals;

    constructor() {}

    /**
     * Add element to the end of queue.
     * @param root Hashed queuedWithdrawal data used to check pending status.
     * @param queuedWithdrawal withdrawal object used to complete withdrawal.
     */
    function enqueue(
        bytes32 memory root,
        QueuedWithdrawal memory queuedWithdrawal
    ) public virtual {
        Node memory newNode = Node(tailNode.next + 1, root, queuedWithdrawal);

        withdrawals[tailNode.next] = newNode;
        tailNode = newNode;

        length++;
    }

    /**
     * Removes the first withdrawal request from the queue.
     */
    function dequeue() public virtual {
        require(getLength() > 0, "Empty queue!");
        headNode = withdrawals[headNode.next];
        delete withdrawals[headIndex];

        headIndex++;
        length--;
    }

    /**
     * Returns front of queue.
     */
    function peek() public returns (Node) {
        return headNode;
    }

    /**
     * Returns queue length.
     */
    function getLength() public returns (uint256) {
        return length;
    }
}
