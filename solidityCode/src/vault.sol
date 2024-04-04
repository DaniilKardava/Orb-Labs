// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {VaultBase} from "./abstracts/VaultBase.sol";
import {IERC20} from "lib/OpenZepellin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "lib/OpenZepellin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "lib/OpenZepellin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "lib/OpenZepellin/contracts/access/Ownable.sol";
import {IStrategy} from "lib/eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {StrategyManager} from "lib/eigenlayer-contracts/src//contracts/core/StrategyManager.sol";
import {VaultWithdrawalQueue} from "./VaultWithdrawalQueue.sol";
import {VaultPriorityWithdrawalQueue} from "./VaultPriorityWithdrawalQueue.sol";
import {EigenWithdrawalQueue} from "./EigenWithdrawalQueue.sol";

contract Vault is VaultBase {
    constructor(
        IERC20 asset,
        string memory name,
        string memory symbol,
        VaultConfig memory configArg,
        EigenContracts memory eigenContractsArg,
        address vaultOwner
    ) ERC4626(asset) ERC20(name, symbol) Ownable(vaultOwner) {
        vaultConfig = configArg;
        eigenContracts = eigenContractsArg;
        vaultPriorityWithdrawalQueue = new VaultPriorityWithdrawalQueue();
        vaultWithdrawalQueue = new VaultWithdrawalQueue();
        eigenWithdrawalQueue = new EigenWithdrawalQueue();
        nonce = 0;
    }

    function queueVaultWithdrawal(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (bool, uint256) {
        require(assets > 0, "Amount less than 0!");

        if (assets < getReserves()) {
            uint256 shares = super.withdraw(assets, receiver, owner);
            return (true, shares);
        } else {
            uint256 deficit = assets - getReserves();
            uint256 pendingVaultWithdrawals = vaultPriorityWithdrawalQueue
                .sumPendingWithdrawals();
            uint256 pendingEigenWithdrawalsInShares = eigenWithdrawalQueue
                .sumPendingWithdrawalsInShares();
            uint256 pendingEigenWithdrawalInAssets = eigenContracts
                .strategyProxy
                .sharesToUnderlyingView(pendingEigenWithdrawalsInShares);

            if (
                deficit <
                (pendingEigenWithdrawalsInAssets - pendingVaultWithdrawals)
            ) {
                return (false, burnAndEnqueue(assets, receiver, owner));
            } else {
                uint256 assetsAfterWithdrawals = totalAssets() -
                    (deficit + pendingVaultWithdrawals);
                uint256 toWithdraw = deficit +
                    calculateReserveThreshold(assetsAfterWithdrawals);
                uint256 shares = burnAndEnqueue(assets, receiver, owner);
                queueEigenWithdraw(toWithdraw);
                return (false, shares);
            }
        }
    }

    function eigenDeposit() public override {
        if (canEigenDeposit()) {
            uint256 surplus = calculateReserveSurplus();
            uint256 eigenShares = eigenContracts
                .strategyManagerProxy
                .depositIntoStrategy(
                    eigenContracts.strategyProxy,
                    _asset,
                    surplus
                );
        }
    }

    function checkEigenWithdrawal() internal override returns (bool) {
        return
            eigenContracts.strategyManagerProxy.withdrawalRootPending[
                eigenWithdrawalQueue.peek().root
            ];
    }

    function completeVaultWithdrawals() public {
        while (
            (eigenWithdrawalQueue.getLength() > 0) && checkEigenWithdrawal()
        ) {
            completeEigenWithdrawal();
        }

        // Serve as many in regular queue before accomodating remaining users.
        serveRegularQueue();
        servePriorityQueue();
    }

    function calculateDepositThreshold(
        uint256 TVL
    ) internal virtual returns (uint256 depositThreshold) {
        uint256 depositThreshold = DSMath.wmul(
            TVL,
            vaultConfig.depositThreshold
        );
    }

    function calculateReserveThreshold(
        uint256 TVL
    ) internal virtual returns (uint256 reserveThreshold) {
        uint256 reserveThreshold = DSMath.wmul(
            TVL,
            vaultConfig.reserveRequirement
        );
    }

    function calculateReserveSurplus()
        internal
        virtual
        returns (uint256 surplus)
    {
        uint256 surplus = getReserves() -
            calculateReserveThreshold(totalValueLocked);
        if (surplus < 0) {
            surplus = 0;
        }
    }

    function canEigenDeposit() internal virtual returns (bool) {
        return (getReserves() > calculateDepositThreshold(totalAssets()));
    }

    function getEigenAssets() public override returns (uint256 assets) {
        uint256 shares = getEigenShares();
        uint256 assets = eigenContracts.strategyProxy.sharesToUnderlyingView(
            shares
        );
    }

    function getEigenShares() public override returns (uint256 shares) {
        uint256 shares = eigenContracts
            .strategyManagerProxy
            .stakerStrategyShares[address(this)][eigenContracts.strategyProxy];
    }

    function getReserves() public override returns (uint256 reserves) {
        return _asset.balanceOf(address(this));
    }

    function checkAndReturnShares(
        uint256 assets,
        address owner
    ) public returns (uint256 shares) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        uint256 shares = previewWithdraw(assets);

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
    }

    /**
     * Override ERC-4626 implementation. Sum vault balance, Eigen balance, and subtrct user withdrawals.
     */
    function totalAssets() public view override returns (uint256) {
        return
            _asset.balanceOf(address(this)) +
            getEigenAssets() -
            vaultPriorityWithdrawalQueue.sumPendingWithdrawals();
    }

    // ====== Internal Methods ====== //

    function queueEigenWithdraw(uint256 assets) internal override {
        uint256 shares = eigenContracts.strategyProxy.underlyingToSharesView(
            assets
        );

        // Build withdrawal struct the way EigenLayer does.
        WithdrawerAndNonce memory withdrawerAndNonce = WithdrawerAndNonce({
            withdrawer: address(this),
            nonce: eigenContracts.strategyManagerProxy.nonces[address(this)]
        });

        QueuedWithdrawal memory queuedWithdrawal = QueuedWithdrawal({
            strategies: [eigenContracts.strategyProxy],
            shares: [shares],
            depositor: address(this),
            withdrawerAndNoce: withdrawerAndNonce,
            withdrawalStartBlock: uint32(block.number),
            delegatedAddress: eigenContracts
                .strategyManagerProxy
                .delegation
                .delegatedTo(address(this))
        });

        bytes32 root = eigenContracts.strategyManagerProxy.queueWithdrawal(
            [0],
            [eigenContracts.strategyProxy],
            [shares],
            address(this),
            false
        );

        eigenWithdrawalQueue.enqueue(root, queuedWithdrawal);
    }

    function completeEigenWithdrawal() internal override {
        eigenContracts.strategyManagerProxy.completeWithdrawal(
            eigenWithdrawalQueue.peek(),
            [_asset],
            0,
            true
        );
        eigenWithdrawalQueue.dequeue();
    }

    function burnAndEnqueue(
        uint256 assets,
        address receiver,
        address owner
    ) internal returns (uint256 shares) {
        uint256 shares = checkAndReturnShares(assets, owner);

        _burn(owner, shares);

        vaultPriorityWithdrawalQueue.enqueue(receiver, assets, nonce);
        vaultWithdrawalQueue.enqueue(receiver, assets, nonce);
        nonce++;
    }

    function servePriorityQueue() internal override {
        while (
            (vaultPriorityWithdrawalQueue.getLength() > 0) &&
            (getReserves() > vaultPriorityWithdrawalQueue.peek().order.amount)
        ) {
            SafeERC20.safeTransfer(
                _asset,
                vaultPriorityWithdrawalQueue.peek().order.account,
                vaultPriorityWithdrawalQueue.peek().order.amount
            );
            vaultWithdrawalQueue.remove(
                vaultPriorityWithdrawalQueue.peek().order.nonce
            );
            vaultPriorityWithdrawalQueue.dequeue();
        }
    }

    function serveRegularQueue() internal override {
        while (
            (vaultWithdrawalQueue.getLength() > 0) &&
            (getReserves() > vaultWithdrawalQueue.peek().order.amount)
        ) {
            SafeERC20.safeTransfer(
                _asset,
                vaultWithdrawalQueue.peek().order.account,
                vaultWithdrawalQueue.peek().order.amount
            );
            vaultPriorityWithdrawalQueue.remove(
                vaultWithdrawalQueue.peek().order.nonce
            );
            vaultWithdrawalQueue.dequeue();
        }
    }

    // ====== Owner Methods ====== //

    function updateVaultConfig(
        VaultConfig memory vaultConfigArg
    ) public override onlyOwner {
        vaultConfig = vaultConfigArg;
    }
}
