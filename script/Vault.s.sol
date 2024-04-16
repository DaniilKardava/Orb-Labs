// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Script, console} from "forge-std/Script.sol";
import "../src/Vault.sol";

contract VaultScript is Script {
    struct VaultArguments {
        IERC20Metadata asset;
        string name;
        string symbol;
        VaultBase.VaultConfig vaultConfigArg;
        VaultBase.EigenContracts eigenContractsArg;
        address vaultOwner;
    }

    VaultArguments public vaultArguments;

    function setUp() public {
        uint256 reserveRequirement = 10 ** 18 / 10; // 10%
        uint256 depositThreshold = 10 ** 18 / 5; // 20%

        VaultBase.VaultConfig memory vaultConfig = VaultBase.VaultConfig({
            reserveRequirement: reserveRequirement,
            depositThreshold: depositThreshold
        });

        // Lido Strategy, Holesky addresses
        VaultBase.EigenContracts memory eigenContracts = VaultBase
            .EigenContracts({
                delegationManagerProxy: IDelegationManager(
                    0xA44151489861Fe9e3055d95adC98FbD462B948e7
                ),
                strategyProxy: IStrategy(
                    0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3
                ),
                strategyManagerProxy: StrategyManager(
                    0xdfB5f6CE42aAA7830E94ECFCcAd411beF4d4D5b6
                )
            });

        address stETH = 0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034;

        vaultArguments = VaultArguments({
            asset: IERC20Metadata(stETH),
            name: "OA Ethereum",
            symbol: "oaETH",
            vaultConfigArg: vaultConfig,
            eigenContractsArg: eigenContracts,
            vaultOwner: 0x3B3C3f31DAe1FD6d056f67fB2D0ea2FD3217AD67
        });
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        Vault vault = new Vault(
            vaultArguments.asset,
            vaultArguments.name,
            vaultArguments.symbol,
            vaultArguments.vaultConfigArg,
            vaultArguments.eigenContractsArg,
            vaultArguments.vaultOwner
        );

        vm.stopBroadcast();
    }
}
