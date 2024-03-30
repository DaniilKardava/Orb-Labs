// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract WithdrawalQueue {
    struct WithdrawalOrder {
        address account;
        uint256 amount;
    }

    struct Node {
        int256 next;
        WithdrawalOrder order;
    }

    Node internal headNode;
    Node internal tailNode;
    uint256 internal length;
    int256 internal headIndex; // For deleting.

    mapping(int256 => Node) internal withdrawals;

    constructor() {}

    /**
     * Add element to the end of queue.
     * @param account Address withdrawing.
     * @param amount Amount to withdraw.
     */
    function enqueue(address account, uint256 amount) public virtual {
        Node memory newNode = Node(
            tailNode.next + 1,
            WithdrawalOrder(account, amount)
        );

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
