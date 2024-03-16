// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {tokenVault} from "src/vault.sol";
import {IERC20} from "OpenZepellin/token/ERC20/IERC20.sol";

contract vaultTest is Test {
    ERC20 vault_token = ERC20(address(0)); // Cast fake address to ERC20 type

    tokenVault vault = new tokenVault(vault_token, "IOU", "IOU"); // Create new vault

    function test_print() public view {
        console.log(string.concat("Vault shares name: ", vault.name()));
    }
}
