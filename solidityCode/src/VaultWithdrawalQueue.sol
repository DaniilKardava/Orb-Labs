// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

contract VaultWithdrawalQueue {
    struct WithdrawalOrder {
        address account;
        uint256 assets;
        uint256 uid;
    }

    struct Node {
        int256 next;
        WithdrawalOrder order;
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
     * @param account Address withdrawing.
     * @param assets Amount of assets to withdraw.
     * @param uid Unique order identifier
     */
    function enqueue(
        address account,
        uint256 assets,
        uint256 uid
    ) public virtual {
        require(account != address(0), "Cannot send to void!");

        Node memory newNode = Node(
            withdrawals[tailIndex].next + 1,
            WithdrawalOrder(account, assets, uid)
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
    function getLength() public view returns (uint256) {
        return length;
    }

    /**
     * Removes a specific element from the queue.
     * @return bool Whether item was in queue.
     */
    function removeOrder(uint256 uid) public returns (bool) {
        int256 prevIndex;
        int256 index = headIndex;
        while (
            (withdrawals[index].order.account != address(0)) &&
            (withdrawals[index].order.uid != uid)
        ) {
            prevIndex = index;
            index = withdrawals[index].next;
        }

        if (withdrawals[index].order.account != address(0)) {
            if (index == headIndex) {
                int256 tempHeadIndex = headIndex;
                headIndex = withdrawals[headIndex].next;
                delete withdrawals[tempHeadIndex];
            } else if (index == tailIndex) {
                delete withdrawals[tailIndex];
                tailIndex = prevIndex;
            } else {
                withdrawals[prevIndex].next = withdrawals[index].next;
                delete withdrawals[index];
            }
            length--;

            return true;
        }

        return false;
    }
}
