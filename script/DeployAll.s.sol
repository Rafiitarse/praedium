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
contract DeployAll is Script {
    function setUp() public {}

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
        RWAToken token = new RWAToken(
            "Real World Asset Token",
            "RWA",
            address(compliance),
            address(assets),
            assetId,
            admin
        );
        console2.log("RWAToken:", address(token));

        // 5. Role grants (admin keeps DEFAULT_ADMIN_ROLE on all three)
        if (officer != admin) {
            compliance.grantRole(compliance.COMPLIANCE_OFFICER_ROLE(), officer);
        }
        if (minter != admin) {
            token.grantRole(token.MINTER_ROLE(), minter);
        }

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
