// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {RWAToken} from "../src/RWAToken.sol";
import {ComplianceRegistry} from "../src/ComplianceRegistry.sol";
import {AssetRegistry} from "../src/AssetRegistry.sol";

/// @title DeployAll
/// @notice One-shot orchestrator: deploys the registries, registers the backing asset,
///         deploys the token wired to both, and prints every address.
/// @dev Deployment order is a hard dependency — RWAToken takes both registry addresses
///      (and a valid assetId) as immutable constructor arguments:
///
///      1. ComplianceRegistry  →  2. AssetRegistry  →  3. registerAsset (assetId = 1)
///      →  4. RWAToken(compliance, assets, 1, admin)  →  5. role grants
///
///      Config via environment (same script runs on anvil / Sepolia / mainnet):
///        DEPLOYER_ADDRESS   — broadcast signer (funded)
///        ADMIN_ADDRESS      — receives DEFAULT_ADMIN_ROLE on all three contracts
///        OFFICER_ADDRESS    — receives COMPLIANCE_OFFICER_ROLE
///        MINTER_ADDRESS     — receives MINTER_ROLE on the token
///        ASSET_URI          — off-chain asset metadata URI (ipfs://…)
///
///      Sepolia usage:
///        source .env
///        forge script script/DeployAll.s.sol --rpc-url sepolia --broadcast -vvvv
///
///      The admin keeps DEFAULT_ADMIN_ROLE on all three contracts — no role is granted to
///      a second address unless it differs from the admin, keeping a single-key testnet
///      deploy minimal. On mainnet the admin should be a multisig.
/// @author Lintar Ar' Rafii
/// @custom:security-contact arrafiilintar@gmail.com
contract DeployAll is Script {
    /// @notice Pre-execution hook required by forge script.
    /// @dev Intentionally empty: every input comes from environment variables read in
    ///      `run`, so there is nothing to set up beforehand.
    function setUp() public {}

    /// @notice Execute the full deployment in dependency order.
    /// @dev Reads all addresses and the asset URI from the environment (see the contract
    ///      header). Broadcasts as the `DEPLOYER_PRIVATE_KEY` holder when one is set, and
    ///      otherwise as `DEPLOYER_ADDRESS` — the anvil/local path, where the node signs
    ///      on its own. Prints every deployed address and a summary of the role holders so
    ///      the output can be copied straight into `frontend/lib/contracts.ts`.
    function run() public {
        uint256 deployerKey = vm.envOr("DEPLOYER_PRIVATE_KEY", uint256(0));
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        address admin = vm.envOr("ADMIN_ADDRESS", deployer);
        address officer = vm.envOr("OFFICER_ADDRESS", deployer);
        address minter = vm.envOr("MINTER_ADDRESS", deployer);
        string memory assetUri = vm.envOr("ASSET_URI", string("ipfs://placeholder-asset-docs"));

        // Broadcast as the key holder when a key is provided, else as the deployer address
        // (anvil auto-signs; --private-key flag also works for cast-wallet flows)
        if (deployerKey != 0) {
            vm.startBroadcast(deployerKey);
        } else {
            vm.startBroadcast(deployer);
        }

        // 1. Compliance registry
        ComplianceRegistry compliance = new ComplianceRegistry(admin);
        console2.log("ComplianceRegistry:", address(compliance));

        // 2. Asset registry
        AssetRegistry assets = new AssetRegistry(admin);
        console2.log("AssetRegistry:", address(assets));

        // 3. Register the backing asset (assetId = 1)
        // The deployer grants itself ASSET_ADMIN_ROLE because only that role can register;
        // it then registers with the deployer as issuer and a zero (informational) valuation.
        assets.grantRole(assets.ASSET_ADMIN_ROLE(), admin);
        uint256 assetId = assets.registerAsset(
            keccak256("asset-docs-v1"),
            assetUri,
            deployer,
            0, // valuation: informational, 0 for testnet demo
            uint64(block.timestamp)
        );
        console2.log("Asset registered, id:", assetId);

        // 4. Token wired to both registries (constructor validates assetId exists)
        RWAToken token =
            new RWAToken("Real World Asset Token", "RWA", address(compliance), address(assets), assetId, admin);
        console2.log("RWAToken:", address(token));

        // 5. Role grants — always grant to the configured holders. The
        //    constructors only grant DEFAULT_ADMIN_ROLE, so the functional
        //    roles must be granted here explicitly even when a holder equals
        //    admin (single-owner setup). grantRole is idempotent.
        compliance.grantRole(compliance.COMPLIANCE_OFFICER_ROLE(), officer);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.PAUSER_ROLE(), admin);

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Deployment summary ===");
        console2.log("admin:   ", admin);
        console2.log("officer: ", officer);
        console2.log("minter:  ", minter);
        console2.log("");
        console2.log("Next: write these addresses to frontend/lib/contracts.ts");
    }
}
