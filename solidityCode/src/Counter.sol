// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC4626} from "OpenZepellin/contracts/token/extensions/ERC4626.sol";
// import {ERC4626} from "solmate/tokens/ERC4626.sol";

contract tokenVault is ERC4626 {
    /// @notice Deposit too small. Called with "amount".
    /// @param amount Amount deposited
    error InsufficientDeposit(uint256 amount);

    /*
    constructor(
        ERC20 _asset, // Vault asset
        string memory _name, // IOU name
        string memory _symbol // IOU symbol
    ) ERC4626(_asset) ERC20(_name, _symbol) {}

    /// @notice deposits user funds in exchange for IOU. Reverts if 'amount' <= 0.
    /// @param amount Quantity of real asset deposited
    function _deposit(uint256 amount) external {
        if (amount <= 0) {
            revert InsufficientDeposit(amount);
        }

        deposit(amount, msg.sender); // Call parent deposit method to request deposit confirmation and mint IOU

        // Mint automatically updates IOU ownership. Viewable using
    }

    */
}
