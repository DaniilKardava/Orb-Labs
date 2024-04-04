// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

contract VaultWithdrawalQueue {
    struct WithdrawalOrder {
        address account;
        uint256 assets;
        uint256 nonce;
    }

    struct Node {
        int256 next;
        WithdrawalOrder order;
    }

    uint256 internal length;
    int256 internal headIndex;
    int256 internal tailIndex;

    mapping(int256 => Node) internal withdrawals;

    constructor() {}

    /**
     * Add element to the end of queue.
     * @param account Address withdrawing.
     * @param assets Amount of assets to withdraw.
     */
    function enqueue(
        address account,
        uint256 assets,
        uint256 nonce
    ) public virtual {
        Node memory newNode = Node(
            withdrawals[tailIndex].next + 1,
            WithdrawalOrder(account, assets, nonce)
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

        delete withdrawals[headIndex];
        headIndex++;
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
     */
    function removeOrder(uint256 nonce) public {
        int256 prevIndex;
        int256 index = headIndex;
        while (
            (withdrawals[index].order.account != address(0)) &&
            (withdrawals[index].order.nonce != nonce)
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
        }
    }
}
