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
        require(length > 0, "Empty queue!");

        // Full reset of queue state.
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
     * Removes a specific element from the queue.
     * @return order The order that was removed. Or null order.
     */
    function removeOrder(uint256 uid) public returns (WithdrawalOrder memory) {
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
            WithdrawalOrder memory order = withdrawals[index].order;
            if (index == headIndex) {
                dequeue();
            } else if (index == tailIndex) {
                withdrawals[prevIndex].next = withdrawals[tailIndex].next; // Pass the void index.
                delete withdrawals[tailIndex];
                tailIndex = prevIndex;
                length--;
            } else {
                withdrawals[prevIndex].next = withdrawals[index].next;
                delete withdrawals[index];
                length--;
            }

            return order;
        }

        return WithdrawalOrder(address(0), 0, 0);
    }
}
