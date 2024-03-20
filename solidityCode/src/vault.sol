// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "OpenZepellin/token/ERC20/IERC20.sol";
import {ERC20} from "OpenZepellin/token/ERC20/ERC20.sol";
import {ERC4626} from "OpenZepellin/token/ERC20/extensions/ERC4626.sol";

contract tokenVault is ERC4626 {
    /// @notice Deposit too small. Called with "amount".
    /// @param amount Amount deposited
    error InsufficientDeposit(uint256 amount);

    // Depositors and their assets (original currency)
    mapping(address => uint256) public depositors;

    constructor(
        IERC20 asset, // Vault token
        string memory name, // IOU token name
        string memory symbol // IOU token symbol
    ) ERC4626(asset) ERC20(name, symbol) {}

    /// @param assets Amount of underlying to deposit
    /// @param receiver Receive address for IOU tokens
    function deposit(
        uint256 assets,
        address receiver
    ) public override returns (uint256) {
        // Check for reasonable deposit
        if (assets <= 0) {
            revert InsufficientDeposit(assets);
        }

        uint256 IOU_shares = super.deposit(assets, receiver); // OZ deposit method. Returns IOU shares received.

        depositors[receiver] = assets; // Deposit credit is granted to the receiver of the IOU.

        return IOU_shares;
    }

    function 
}
