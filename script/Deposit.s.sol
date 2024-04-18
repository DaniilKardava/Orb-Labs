// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Script, console} from "forge-std/Script.sol";
import "../src/Vault.sol";

/**
 * Test deposit to vault.
 */
contract DepositScript is Script {
    address public myA;
    address public vaultA;

    function setUp() public {
        vaultA = 0xC438a1b3089bf5f0FE8242f0833296cb1cD25773;
        myA = 0x3B3C3f31DAe1FD6d056f67fB2D0ea2FD3217AD67;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address stEth = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;
        IERC20 stEthToken = IERC20(stEth);

        vm.startBroadcast(deployerPrivateKey);

        // Approve send
        stEthToken.approve(vaultA, 3 * 10 ** 17);

        // Send
        Vault vault = Vault(vaultA);
        vault.deposit(3 * 10 ** 17, myA);

        vm.stopBroadcast();
    }
}
