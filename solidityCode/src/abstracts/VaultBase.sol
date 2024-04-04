// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {IERC20} from "lib/OpenZepellin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "lib/OpenZepellin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "lib/OpenZepellin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "lib/OpenZepellin/contracts/access/Ownable.sol";
import {IStrategy} from "lib/eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {StrategyManager} from "lib/eigenlayer-contracts/src//contracts/core/StrategyManager.sol";
import {VaultWithdrawalQueue} from "../VaultWithdrawalQueue.sol";
import {VaultPriorityWithdrawalQueue} from "../VaultPriorityWithdrawalQueue.sol";
import {EigenWithdrawalQueue} from "../EigenWithdrawalQueue.sol";

/**
 * Abstract Vault contract for token and EigenLayer strategy.
 * All value quantities are stored in Wad units.
 */
abstract contract VaultBase is ERC4626, Ownable {
    /// COPIED FROM EIGENLAYER
    struct WithdrawerAndNonce {
        address withdrawer;
        uint96 nonce;
    }

    /**
     * COPIED FROM EIGENLAYER
     * Struct type used to specify an existing queued withdrawal. Rather than storing the entire struct, only a hash is stored.
     * In functions that operate on existing queued withdrawals -- e.g. `startQueuedWithdrawalWaitingPeriod` or `completeQueuedWithdrawal`,
     * the data is resubmitted and the hash of the submitted data is computed by `calculateWithdrawalRoot` and checked against the
     * stored hash in order to confirm the integrity of the submitted data.
     */
    struct QueuedWithdrawal {
        IStrategy[] strategies;
        uint256[] shares;
        address depositor;
        WithdrawerAndNonce withdrawerAndNonce;
        uint32 withdrawalStartBlock;
        address delegatedAddress;
    }

    /**
     * Contains EigenLayer proxy contracts for the strategy manager and the particular strategy.
     */
    struct EigenContracts {
        StrategyManager strategyManagerProxy;
        IStrategy strategyProxy;
    }

    /**
     * Reserve requirement is a decimal percentage of vault value for immediate withdrawal.
     * Deposit threshold is a decimal percentage of vault value to trigger next deposit to EigenLayer.
     */
    struct VaultConfig {
        uint256 reserveRequirement;
        address depositThreshold;
    }

    VaultConfig public vaultConfig;
    EigenContracts public immutable eigenContracts;
    VaultPriorityWithdrawalQueue internal vaultPriorityWithdrawalQueue;
    VaultWithdrawalQueue internal vaultWithdrawalQueue;
    EigenWithdrawalQueue internal eigenWithdrawalQueue;
    uint256 public nonce;

    /**
     * Create a Vault with a depositable token in exchange for a Vault managed IOU.
     * Assign vaultOwner.
     * @param asset Vault token.
     * @param name IOU token name.
     * @param symbol IOU token symbol.
     * @param vaultConfigArg Vault strategy configuration.
     * @param eigenContractsArg EigenLayer proxy contracts.
     * @param vaultOwner Vault owner.
     */
    constructor(
        IERC20 asset,
        string memory name,
        string memory symbol,
        VaultConfig memory configArg,
        EigenContracts memory eigenContractsArg,
        address vaultOwner
    ) ERC4626(asset) ERC20(name, symbol) Ownable(vaultOwner);

    // ====== Public Methods ====== //

    /**
     * Attempt to withdraw from Vault.
     * @param assets Amount of underlying to withdraw.
     * @param receiver Account to withdraw to.
     * @param owner Account to burn shares from.
     * @return completed Whether withdrawal was completed immediately.
     * @return shares Amount of shares burned.
     */
    function queueVaultWithdrawal(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual returns (bool completed, uint256 shares);

    /**
     * Deposit surplus reserves into EigenLayer. Refund caller gas.
     * @param assets Amount of assets to deposit to EigenLayer.
     */
    function eigenDeposit(uint256 assets) public virtual;

    /**
     * Checks the status of the first EigenLayer withdrawal in queue.
     */
    function checkEigenWithdrawal() public view virtual returns (bool);

    /**
     * Complete as many vault withdrawal requests as possible. Refund caller gas.
     */
    function completeVaultWithdrawals() public virtual;

    /**
     * Calculates excess reserves required to trigger deposit to EigenLayer based on Vault configuration.
     * @param TVL Hypothetical total value locked.
     * @return depositThreshold Amount needed to trigger deposit.
     */
    function calculateDepositThreshold(
        uint256 TVL
    ) public view virtual returns (uint256 depositThreshold);

    /**
     * Calculates target reserves based on Vault configuration.
     * @param TVL Hypothetical total value locked.
     * @return reserveThreshold Target reserves to serve withdrawals.
     */
    function calculateReserveThreshold(
        uint256 TVL
    ) public view virtual returns (uint256 reserveThreshold);

    /**
     * Calculates surplus in Vault reserves.
     */
    function calculateReserveSurplus()
        public
        view
        virtual
        returns (uint256 surplus);

    /**
     * Returns if reserves are greater than EigenLayer deposit threshold.
     */
    function canEigenDeposit() public view virtual returns (bool);

    /**
     * Get the Vault's shares in EigenLayer strategy.
     */
    function getEigenShares() public view virtual returns (uint256 shares);

    /**
     * Get the Vault's assets in EigenLayer strategy.
     */
    function getEigenAssets() public view virtual returns (uint256 assets);

    /**
     * Get amount of uninvested assets.
     */
    function getReserves() public view virtual returns (uint256 reserves);

    /**
     * Check that user can withdraw the assets and return how much it will cost them in shares.
     * @param assets Amount of assets to withdraw.
     * @param owner Address providing the shares.
     * @return shares Amount of shares that would be burned.
     */
    function checkAndReturnShares(
        uint256 assets,
        address owner
    ) public view virtual returns (uint256 shares);

    // ====== Internal Methods ====== //

    /**
     * Initiate withdrawal from EigenLayer.
     * @param assets Amount of assets to withdraw.
     */
    function queueEigenWithdraw(uint256 assets) internal virtual;

    /**
     * Completes EigenLayer withdrawal.
     */
    function completeEigenWithdrawal() internal virtual;

    /**
     * Burn a user's shares and add to withdrawal queue.
     * @param assets Amount of assets to withdraw.
     * @param receiver Receiving address.
     * @param owner Owner of shares, most often the msg.caller and receiver.
     * @return shares Shares burned.
     */
    function burnAndEnqueue(
        uint256 assets,
        address receiver,
        address owner
    ) internal virtual returns (uint256 shares);

    /**
     * Fulfills withdrawal requests in priority queue.
     */
    function servePriorityQueue() internal virtual;

    /**
     * Fulfills withdrawal requests in regular queue.
     */
    function serveRegularQueue() internal virtual;

    // ====== Owner Methods ====== //

    /**
     * Updates Vault configuration. Only callable by owner.
     * @param vaultConfigArg New Vault configuration.
     */
    function updateVaultConfig(
        VaultConfig memory vaultConfigArg
    ) public virtual onlyOwner;

    // ====== Masked Methods ====== //

    /**
     * Mask ERC4626 withdrawal method.
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256) {
        revert("Please use queueWithdrawal()!");
    }
}
