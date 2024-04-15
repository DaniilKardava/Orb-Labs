// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "./abstracts/VaultBase.sol";

contract Vault is VaultBase {
    constructor(
        IERC20Metadata asset,
        string memory name,
        string memory symbol,
        VaultConfig memory vaultConfigArg,
        EigenContracts memory eigenContractsArg,
        address vaultOwner
    )
        VaultBase(
            asset,
            name,
            symbol,
            vaultConfigArg,
            eigenContractsArg,
            vaultOwner
        )
    {}
    function queueVaultWithdrawal(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (bool, uint256) {
        require(assets > 0, "Amount less than 0!");
        require(receiver != address(0), "Address cannot be void!");

        if (assets < getReserves()) {
            uint256 shares = super.withdraw(assets, receiver, owner);
            return (true, shares);
        } else {
            uint256 deficit = assets - getReserves();
            uint256 pendingVaultWithdrawals = vaultPriorityWithdrawalQueue
                .sumPendingWithdrawals();
            uint256 pendingEigenWithdrawalsInShares = eigenWithdrawalQueue
                .sumPendingWithdrawalsInShares();
            uint256 pendingEigenWithdrawalsInAssets = eigenContracts
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
            eigenContracts.strategyManagerProxy.depositIntoStrategy(
                eigenContracts.strategyProxy,
                getAssetContract(),
                surplus
            );
        }
    }

    function checkEigenWithdrawal() public view override returns (bool) {
        return
            eigenContracts.strategyManagerProxy.withdrawalRootPending(
                eigenWithdrawalQueue.peek().root
            );
    }

    function completeVaultWithdrawals() public override {
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
        uint256 totalValueLocked
    ) public view override returns (uint256 depositThreshold) {
        depositThreshold = DSMath.wmul(
            totalValueLocked,
            vaultConfig.depositThreshold
        );
    }

    function calculateReserveThreshold(
        uint256 totalValueLocked
    ) public view override returns (uint256 reserveThreshold) {
        reserveThreshold = DSMath.wmul(
            totalValueLocked,
            vaultConfig.reserveRequirement
        );
    }

    function calculateReserveSurplus()
        public
        view
        override
        returns (uint256 surplus)
    {
        surplus = getReserves() - calculateReserveThreshold(totalAssets());
        if (surplus < 0) {
            surplus = 0;
        }
    }

    function canEigenDeposit() public view override returns (bool) {
        return (getReserves() > calculateDepositThreshold(totalAssets()));
    }

    function getEigenAssets() public view override returns (uint256 assets) {
        uint256 shares = getEigenShares();
        assets = eigenContracts.strategyProxy.sharesToUnderlyingView(shares);
    }

    function getEigenShares() public view override returns (uint256 shares) {
        shares = eigenContracts.strategyManagerProxy.stakerStrategyShares(
            address(this),
            eigenContracts.strategyProxy
        );
    }

    function getReserves() public view override returns (uint256) {
        return getAssetContract().balanceOf(address(this));
    }

    function checkAndReturnShares(
        uint256 assets,
        address owner
    ) public view override returns (uint256 shares) {
        require(
            assets <= maxWithdraw(owner),
            "ERC4626: withdraw more than max"
        );

        shares = previewWithdraw(assets);

        if (msg.sender != owner) {
            uint256 currentAllowance = allowance(owner, msg.sender);
            require(
                currentAllowance >= shares,
                "ERC20: insufficient allowance"
            );
        }
    }

    /**
     * Override ERC-4626 implementation. Sum vault balance, Eigen balance, and subtrct user withdrawals.
     */
    function totalAssets() public view override returns (uint256) {
        return
            getAssetContract().balanceOf(address(this)) +
            getEigenAssets() -
            vaultPriorityWithdrawalQueue.sumPendingWithdrawals();
    }

    // ====== Internal Methods ====== //

    function getAssetContract() internal view override returns (IERC20) {
        return IERC20(asset());
    }

    function queueEigenWithdraw(uint256 assets) internal override {
        uint256 shares = eigenContracts.strategyProxy.underlyingToSharesView(
            assets
        );

        // Declare dynamic arrays
        uint256[] memory strategyIndexes = new uint256[](1);
        strategyIndexes[0] = 0;

        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = eigenContracts.strategyProxy;

        uint256[] memory sharesArray = new uint256[](1);
        sharesArray[0] = shares;

        // Build withdrawal struct the way EigenLayer does.
        IStrategyManager.WithdrawerAndNonce
            memory withdrawerAndNonce = IStrategyManager.WithdrawerAndNonce({
                withdrawer: address(this),
                nonce: uint96(
                    eigenContracts.strategyManagerProxy.numWithdrawalsQueued(
                        address(this)
                    )
                )
            });

        IStrategyManager.QueuedWithdrawal
            memory queuedWithdrawal = IStrategyManager.QueuedWithdrawal({
                strategies: strategies,
                shares: sharesArray,
                depositor: address(this),
                withdrawerAndNonce: withdrawerAndNonce,
                withdrawalStartBlock: uint32(block.number),
                delegatedAddress: eigenContracts
                    .strategyManagerProxy
                    .delegation()
                    .delegatedTo(address(this))
            });

        bytes32 root = eigenContracts.strategyManagerProxy.queueWithdrawal(
            strategyIndexes,
            strategies,
            sharesArray,
            address(this),
            false
        );

        eigenWithdrawalQueue.enqueue(root, queuedWithdrawal);
    }

    function completeEigenWithdrawal() internal override {
        IERC20[] memory tokensArray = new IERC20[](1);
        tokensArray[0] = getAssetContract();

        eigenContracts.strategyManagerProxy.completeQueuedWithdrawal(
            eigenWithdrawalQueue.peek().order,
            tokensArray,
            0,
            true
        );
        eigenWithdrawalQueue.dequeue();
    }

    function burnAndEnqueue(
        uint256 assets,
        address receiver,
        address owner
    ) internal override returns (uint256 shares) {
        require(receiver != address(0), "Address cannot be void!");

        shares = checkAndReturnShares(assets, owner);

        _burn(owner, shares);

        vaultPriorityWithdrawalQueue.enqueue(receiver, assets, nonce);
        vaultWithdrawalQueue.enqueue(receiver, assets, nonce);
        nonce++;
    }

    function servePriorityQueue() internal override {
        while (
            (vaultPriorityWithdrawalQueue.getLength() > 0) &&
            (getReserves() > vaultPriorityWithdrawalQueue.peek().order.assets)
        ) {
            SafeERC20.safeTransfer(
                getAssetContract(),
                vaultPriorityWithdrawalQueue.peek().order.account,
                vaultPriorityWithdrawalQueue.peek().order.assets
            );
            vaultWithdrawalQueue.removeOrder(
                vaultPriorityWithdrawalQueue.peek().order.uid
            );
            vaultPriorityWithdrawalQueue.dequeue();
        }
    }

    function serveRegularQueue() internal override {
        while (
            (vaultWithdrawalQueue.getLength() > 0) &&
            (getReserves() > vaultWithdrawalQueue.peek().order.assets)
        ) {
            SafeERC20.safeTransfer(
                getAssetContract(),
                vaultWithdrawalQueue.peek().order.account,
                vaultWithdrawalQueue.peek().order.assets
            );
            vaultPriorityWithdrawalQueue.removeOrder(
                vaultWithdrawalQueue.peek().order.uid
            );
            vaultWithdrawalQueue.dequeue();
        }
    }
}
