// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {VaultWithdrawalQueue} from "../../src/VaultWithdrawalQueue.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {StdInvariant} from "../../lib/forge-std/src/StdInvariant.sol";

import {Handler} from "./Handler.sol";
import {RandomGenerator} from "../RandomGenerator.sol";

/**
 * Test the vault withdrawal queue. Many function asserts are written inside the handler.
 */
contract TestVaultQueue is Test {
    VaultWithdrawalQueue internal queue;
    Handler internal handler;
    RandomGenerator internal randomGenerator;
    uint256 internal constant MAX_INITIAL_Q = 10;

    function setUp() public {
        queue = new VaultWithdrawalQueue();
        handler = new Handler(queue);
        randomGenerator = new RandomGenerator();

        targetContract(address(handler));

        // Populate queue with random entries.
        uint256 salt = 123143329;
        for (uint256 i = 0; i < MAX_INITIAL_Q; i++) {
            // Generate random values
            address rAddress = randomGenerator.randomAddress(salt);
            uint256 rAmount = randomGenerator.randomUint(salt);
            uint256 rUid = randomGenerator.randomUint(rAmount);

            handler.enqueue(rAddress, uint160(rAmount), rUid);

            salt = rUid; // Update seed
        }
    }

    /// Test that the length of the queue is the net of enqueue, dequeue, and remove calls.
    function invariant_queue_length() public view {
        uint256 netCalls = handler.enqueueCalls() -
            handler.removeCalls() -
            handler.dequeueCalls();
        assertEq(queue.length(), netCalls);
    }

    /// Checks that queue can be traversed from head to tail in exactly "length" steps
    function invariant_can_traverse() public view {
        int256 idx = queue.headIndex();
        // it takes length - 1 steps to get from start to finish of queue, so begin at 1.
        for (uint256 i = 1; i < queue.length(); i++) {
            (idx, ) = queue.withdrawals(idx);
        }
        assertEq(idx, queue.tailIndex());
    }

    /// Assert that tail is always pointing to void. Then elements can be added without concern of overwriting existing data.
    function invariant_tail_points_void() public view {
        (int256 freeIdx, ) = queue.withdrawals(queue.tailIndex());
        (, VaultWithdrawalQueue.WithdrawalOrder memory order) = queue
            .withdrawals(freeIdx);
        assertEq(order.account, address(0));
    }
}
