// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {VaultBase} from "./abstracts/VaultBase.sol";
import {IERC20} from "OpenZepellin/token/ERC20/IERC20.sol";
import {ERC20} from "OpenZepellin/token/ERC20/ERC20.sol";
import {ERC4626} from "OpenZepellin/token/ERC20/extensions/ERC4626.sol";
import {DSMath} from "ds-math/math.sol";
import {IStrategy} from "eigenlayer-contracts/contracts/interfaces/IStrategy.sol";
import {StrategyManager} from "eigenlayer-contracts/contracts/core/StrategyManager.sol";
import {VaultWithdrawalQueue} from "./VaultWithdrawalQueue.sol";
import {VaultPriorityWithdrawalQueue} from "./VaultPriorityWithdrawalQueue.sol";
import {EigenWithdrawalQueue} from "./EigenWithdrawalQueue.sol";

// make methods view
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
    }

    /**
     * Override ERC4626 deposit.
     */
    function deposit(
        uint256 assets, 
        address receiver
    ) public override returns (uint256) {
        require(amount > 0, "Amount less than 0!");
        uint256 shares = super.deposit(assets, receiver);

        servePriorityQueue();

        if (triggerEigenDeposit()) {
            uint256 surplus = calculateReserveSurplus();
            eigenDeposit(surplus);
        }

        return shares;
    }
    
    function queueWithdrawal(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (bool, uint256) {
        require(amount > 0, "Amount less than 0!");

        if (assets < getReserves()) {

            uint256 shares = super.withdraw(assets, receiver, owner);
            return (true, shares);

        } else {
            
            // In progress
            uint256 deficit = assets - getReserves();
            uint256 assetsAfterWithdrawal = totalAssets() - assets;
            uint256 totalRequired = deficit + calculateReserveThreshold(assetsAfterWithdrawal);

            return(false, 0);
            
        }
        
    }


    function checkEigenWithdrawal() internal override returns(bool) {
        return eigenContracts.strategyManagerProxy.withdrawalRootPending[eigenWithdrawalQueue.peek().root];
    }


    function completeWithdrawal() public override {
        // How to get timeIndex thing?
        eigenContracts.strategyManagerProxy.completeWithdrawal(eigenWithdrawalQueue.peek(), [_asset], ? , true);
    }
    

    function eigenDeposit(uint256 assets) internal override {
        require(getReserves() > amount, "Not enough in reserves!");

        uint256 eigenShares = eigenContracts.strategyManagerProxy.depositIntoStrategy(
            eigenContracts.strategyProxy,
            asset,
            assets
        );
    }

    function eigenWithdraw(uint256 assets) internal override {
        uint256 shares =  eigenContracts.strategyProxy.underlyingToSharesView(assets);

        // Build withdrawal struct the way EigenLayer does.
        WithdrawerAndNonce memory withdrawerAndNonce = WithdrawerAndNonce({
            withdrawer: address(this),
            nonce: eigenContracts.strategyManagerProxy.nonces[address(this)]
        })

        QueuedWithdrawal memory queuedWithdrawal = QueuedWithdrawal({
            strategies: [eigenContracts.strategyProxy],
            shares: [shares],
            depositor: address(this),
            withdrawerAndNoce: withdrawerAndNonce,
            withdrawalStartBlock: uint32(block.number),
            delegatedAddress: eigenContracts.strategyManagerProxy.delegation.delegatedTo(address(this))
        }) 

        bytes32 root = eigenContracts.strategyManagerProxy.queueWithdrawal([0], [eigenContracts.strategyProxy], [shares], address(this), false);
        
        eigenWithdrawalQueue.enqueue(root, queuedWithdrawal);
    }


    function servePriorityQueue() internal override {

        while ( (vaultPriorityWithdrawalQueue.getLength() > 0) && (getReserves() > vaultPriorityWithdrawalQueue.peek().order.amount) ) {
            SafeERC20.safeTransfer(_asset, vaultPriorityWithdrawalQueue.peek().order.account, vaultPriorityWithdrawalQueue.peek().order.amount);
            vaultPriorityWithdrawalQueue.dequeue();
        }

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
    }

    function triggerEigenDeposit() internal virtual returns (bool) {
        return (getReserves() > calculateDepositThreshold(totalAssets()));
    }

    function totalAssets() public view override returns (uint256) {
        return _asset.balanceOf(address(this)) +  getEigenAssets();
    }

    function getReserves() public override returns (uint256 reserves) {
        return _asset.balanceOf(address(this));
    }

    function getEigenShares() public override returns(uint256 shares) {
        uint256 shares = eigenContracts.strategyManagerProxy.stakerStrategyShares[address(this)][eigenContracts.strategyProxy];
    }

    function getEigenAssets() public override returns(uint256 assets) {
        uint256 shares = getEigenShares();
        uint256 assets = eigenContracts.strategyProxy.sharesToUnderlyingView(shares);
    }

    function updateVaultConfig(
        VaultConfig memory vaultConfigArg
    ) public override onlyOwner {
        vaultConfig = vaultConfigArg;
    }

    /**
        * Mask ERC4626 withdrawal method.
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256) {
        revert("Please use queueWithdrawal!");
    }
}
