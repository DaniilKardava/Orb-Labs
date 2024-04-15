// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {EigenWithdrawalQueue, IDelegationManager, IStrategy} from "../../src/EigenWithdrawalQueue.sol";
import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {StdInvariant} from "../../lib/forge-std/src/StdInvariant.sol";

import {Handler} from "./Handler.sol";
import {RandomGenerator} from "../RandomGenerator.sol";

/**
 * Test the vault withdrawal queue. Many function asserts are written inside the handler.
 */
contract TestEigenQueue is Test {
    EigenWithdrawalQueue internal queue;
    Handler internal handler;
    RandomGenerator internal randomGenerator;
    uint256 internal constant MAX_INITIAL_Q = 10;

    function setUp() public {
        queue = new EigenWithdrawalQueue();
        handler = new Handler(queue);
        randomGenerator = new RandomGenerator();

        targetContract(address(handler));

        // Populate queue with random entries.
        uint256 salt = 123143329;
        for (uint256 i = 0; i < MAX_INITIAL_Q; i++) {
            // Build random withdrawal struct.
            bytes32 rBytes = bytes32(randomGenerator.randomUint(salt));

            IStrategy[] memory strategies = new IStrategy[](1);
            strategies[0] = IStrategy(randomGenerator.randomAddress(salt));

            uint256[] memory sharesArray = new uint256[](1);
            sharesArray[0] = uint256(uint160(randomGenerator.randomUint(salt))); // Limit size for summation

            IDelegationManager.Withdrawal memory order = IDelegationManager
                .Withdrawal({
                    staker: randomGenerator.randomAddress(salt),
                    delegatedTo: randomGenerator.randomAddress(salt + 1),
                    withdrawer: randomGenerator.randomAddress(salt),
                    nonce: randomGenerator.randomUint(salt),
                    startBlock: uint32(randomGenerator.randomUint(salt)),
                    strategies: strategies,
                    shares: sharesArray
                });

            handler.enqueue(rBytes, order);

            salt = randomGenerator.randomUint(salt); // Update seed
        }
    }

    /**
     * Check that the queue accurately tracks total pending withdrawals.
     */
    function invariant_sum_deposits() public view {
        assertGe(queue.sumPendingWithdrawalsInShares(), handler.netDeposits());
    }

    /**
     *Test that the length of the queue is the net of enqueue, dequeue.
     */
    function invariant_queue_length() public view {
        uint256 netCalls = handler.enqueueCalls() - handler.dequeueCalls();
        assertEq(queue.length(), netCalls);
    }

    /**
     * Checks that queue can be traversed from head to tail in exactly "length" steps
     */
    function invariant_can_traverse() public view {
        int256 idx = queue.headIndex();
        // it takes length - 1 steps to get from start to finish of queue, so begin at 1.
        for (uint256 i = 1; i < queue.length(); i++) {
            (idx, , ) = queue.withdrawals(idx);
        }
        assertEq(idx, queue.tailIndex());
    }

    /**
     * Assert that tail is always pointing to void. Then elements can be added without concern of overwriting existing data.
     */
    function invariant_tail_points_void() public view {
        (int256 freeIdx, , ) = queue.withdrawals(queue.tailIndex());
        (, bytes32 root, ) = queue.withdrawals(freeIdx);
        assertEq(root, bytes32(0));
    }
}
