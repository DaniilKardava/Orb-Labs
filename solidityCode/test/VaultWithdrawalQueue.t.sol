// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {VaultWithdrawalQueue} from "../src/VaultWithdrawalQueue.sol";

contract Handler {
    uint256 public dequeueCalls;
    uint256 public removeCalls;
    uint256 public enqueueCalls;

    VaultWithdrawalQueue public queue;

    uint256[] public removable; // Tracks removable orders.

    constructor(VaultWithdrawalQueue queueArg) {
        queue = queueArg;
        enqueueCalls = 0;
        dequeueCalls = 0;
        removeCalls = 0;
    }

    /// Enqueue order, increment calls to enqueue, and append removable id.
    function enqueue(address account, uint256 assets, uint256 uid) public {
        queue.enqueue(account, assets, uid);
        // doesnt execute on revert
        enqueueCalls++;
        removable.push(uid);
    }

    /// Dequeue order, increment calls to dequeue, and remove id of item from removable list.
    function dequeue() public {
        uint256 uidRemoved = queue.peek().order.uid; // which uid im removing
        queue.dequeue();
        // doesnt execute on revert
        dequeueCalls++;
        popElement(uidRemoved);
    }

    /// Remove an element from queue by id. Increment removeCalls. Remove element from removable list.
    function removeOrder(uint256 uid) public {
        uint256 idx = uid % removable.length;
        uid = removable[idx];
        popIdx(idx);

        if (queue.removeOrder(uid)) {
            removeCalls++;
        }
    }

    // Remove element at index but preserve structure.
    function popIdx(uint256 idx) private {
        removable[idx] = removable[removable.length - 1];
        delete removable[removable.length - 1];
    }

    // Search for index of element and remove.
    function popElement(uint256 uid) private {
        uint256 idx = 0;
        for (uint256 i = 0; i < removable.length; i++) {
            if (removable[i] == uid) {
                idx = i;
                break;
            }
        }
        popIdx(idx);
    }
}

import {Test, console, stdStorage, StdStorage} from "../lib/forge-std/src/Test.sol";
import {StdInvariant} from "../lib/forge-std/src/StdInvariant.sol";

contract TestVaultQ is Test {
    using stdStorage for StdStorage;

    VaultWithdrawalQueue private queue;
    Handler private handler;
    uint256 private constant MAX_INITIAL_Q = 10;

    function setUp() public {
        queue = new VaultWithdrawalQueue();
        handler = new Handler(queue);

        targetContract(address(handler));
        // rng hash
    }

    /// Test that the length of the queue is the net of enqueue, dequeue, and remove calls.
    function invariant_q_length() public view {
        uint256 netCalls = handler.enqueueCalls() -
            handler.removeCalls() -
            handler.dequeueCalls();
        assertEq(queue.getLength(), netCalls);
    }

    /// Test that the tail index is the sum of all enqueue calls.
    function invariant_tail_index() public {
        int256 tailIndex = stdstore
            .target(address(queue))
            .sig("tailIndex")
            .read_int(); // Read private variable
        //make public
        assertEq(int256(handler.enqueueCalls()), tailIndex);
    }
}
