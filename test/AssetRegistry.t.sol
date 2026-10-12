// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {AssetRegistry} from "../src/AssetRegistry.sol";
import {IAssetRegistry} from "../src/interfaces/IAssetRegistry.sol";

/// @title AssetRegistryTest
/// @notice Unit coverage for asset provenance records: role gating, id allocation,
///         amendments, lifecycle status, and unknown-asset rejection.
contract AssetRegistryTest is Test {
    AssetRegistry registry;

    address admin = makeAddr("admin");
    address assetAdmin = makeAddr("assetAdmin");
    address stranger = makeAddr("stranger");
    address issuer = makeAddr("issuer");

    bytes32 constant DOC_HASH = keccak256("deed-123");
    string constant URI = "ipfs://asset-docs";
    uint256 constant VALUATION = 1_000_000e6; // $1M in 6-decimal USD terms
    uint64 constant VALUATION_AT = 1_700_000_000;

    function setUp() public {
        registry = new AssetRegistry(admin);
        vm.startPrank(admin);
        registry.grantRole(registry.ASSET_ADMIN_ROLE(), assetAdmin);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // Authorization
    // ------------------------------------------------------------------

    function test_registerAsset_revertsForNonAdmin() public {
        vm.prank(stranger);
        vm.expectRevert();
        registry.registerAsset(DOC_HASH, URI, issuer, VALUATION, VALUATION_AT);
    }

    function test_updateAsset_revertsForNonAdmin() public {
        uint256 id = _registerOne();
        vm.prank(stranger);
        vm.expectRevert();
        registry.updateAsset(id, DOC_HASH, URI, VALUATION, VALUATION_AT);
    }

    function test_setStatus_revertsForNonAdmin() public {
        uint256 id = _registerOne();
        vm.prank(stranger);
        vm.expectRevert();
        registry.setStatus(id, IAssetRegistry.AssetStatus.Frozen);
    }

    function test_constructor_revertsOnZeroAdmin() public {
        vm.expectRevert(AssetRegistry.ZeroAddress.selector);
        new AssetRegistry(address(0));
    }

    // ------------------------------------------------------------------
    // Registration
    // ------------------------------------------------------------------

    function test_registerAsset_idsStartAtOneAndIncrement() public {
        uint256 first = _registerOne();
        assertEq(first, 1, "first asset id must be 1");
        uint256 second = _registerOne();
        assertEq(second, 2, "ids increment monotonically");
        assertEq(registry.assetCount(), 2);
    }

    function test_registerAsset_roundTrips() public {
        uint256 id = _registerOne();
        IAssetRegistry.Asset memory asset = registry.getAsset(id);
        assertEq(asset.docHash, DOC_HASH);
        assertEq(asset.uri, URI);
        assertEq(asset.issuer, issuer);
        assertEq(asset.valuation, VALUATION);
        assertEq(asset.valuationAt, VALUATION_AT);
        assertEq(uint8(asset.status), uint8(IAssetRegistry.AssetStatus.Active));
    }

    function test_registerAsset_emitsEvent() public {
        vm.prank(assetAdmin);
        vm.expectEmit(true, true, false, true);
        emit AssetRegistry.AssetRegistered(1, DOC_HASH, issuer);
        registry.registerAsset(DOC_HASH, URI, issuer, VALUATION, VALUATION_AT);
    }

    function test_registerAsset_revertsOnZeroIssuer() public {
        vm.prank(assetAdmin);
        vm.expectRevert(AssetRegistry.ZeroAddress.selector);
        registry.registerAsset(DOC_HASH, URI, address(0), VALUATION, VALUATION_AT);
    }

    // ------------------------------------------------------------------
    // Amendments & lifecycle
    // ------------------------------------------------------------------

    function test_updateAsset_overwritesFields() public {
        uint256 id = _registerOne();
        bytes32 newHash = keccak256("deed-456");
        string memory newUri = "ipfs://amended";

        vm.prank(assetAdmin);
        registry.updateAsset(id, newHash, newUri, 2_000_000e6, VALUATION_AT + 1);

        IAssetRegistry.Asset memory asset = registry.getAsset(id);
        assertEq(asset.docHash, newHash);
        assertEq(asset.uri, newUri);
        assertEq(asset.valuation, 2_000_000e6);
    }

    function test_setStatus_transitions() public {
        uint256 id = _registerOne();
        vm.startPrank(assetAdmin);
        registry.setStatus(id, IAssetRegistry.AssetStatus.Frozen);
        assertEq(uint8(registry.getAsset(id).status), uint8(IAssetRegistry.AssetStatus.Frozen));
        registry.setStatus(id, IAssetRegistry.AssetStatus.Redeemed);
        assertEq(uint8(registry.getAsset(id).status), uint8(IAssetRegistry.AssetStatus.Redeemed));
        vm.stopPrank();
    }

    function test_batchSetStatus_updatesMany() public {
        uint256 id1 = _registerOne();
        uint256 id2 = _registerOne();
        uint256[] memory ids = new uint256[](2);
        ids[0] = id1;
        ids[1] = id2;
        IAssetRegistry.AssetStatus[] memory statuses = new IAssetRegistry.AssetStatus[](2);
        statuses[0] = IAssetRegistry.AssetStatus.Frozen;
        statuses[1] = IAssetRegistry.AssetStatus.Redeemed;

        vm.prank(assetAdmin);
        registry.batchSetStatus(ids, statuses);

        assertEq(uint8(registry.getAsset(id1).status), uint8(IAssetRegistry.AssetStatus.Frozen));
        assertEq(uint8(registry.getAsset(id2).status), uint8(IAssetRegistry.AssetStatus.Redeemed));
    }

    // ------------------------------------------------------------------
    // Unknown asset rejection — id 0 and beyond-count both fail closed
    // ------------------------------------------------------------------

    function test_getAsset_revertsOnZeroId() public {
        vm.expectRevert(abi.encodeWithSelector(AssetRegistry.UnknownAsset.selector, 0));
        registry.getAsset(0);
    }

    function test_getAsset_revertsOnBeyondCount() public {
        vm.expectRevert(abi.encodeWithSelector(AssetRegistry.UnknownAsset.selector, 1));
        registry.getAsset(1); // nothing registered
    }

    function test_setStatus_revertsOnUnknown() public {
        vm.prank(assetAdmin);
        vm.expectRevert(abi.encodeWithSelector(AssetRegistry.UnknownAsset.selector, 99));
        registry.setStatus(99, IAssetRegistry.AssetStatus.Frozen);
    }

    // ------------------------------------------------------------------
    // Fuzz — every registered id is retrievable, none collide
    // ------------------------------------------------------------------

    function testFuzz_registerMany_allRetrievable(uint8 count) public {
        count = uint8(bound(count, 1, 20));
        vm.startPrank(assetAdmin);
        for (uint256 i; i < count;) {
            registry.registerAsset(DOC_HASH, URI, issuer, VALUATION, VALUATION_AT);
            unchecked {
                ++i;
            }
        }
        vm.stopPrank();

        for (uint256 id = 1; id <= count; id++) {
            assertEq(registry.getAsset(id).docHash, DOC_HASH, "every id retrievable");
        }
        assertEq(registry.assetCount(), count);
    }

    function _registerOne() internal returns (uint256) {
        vm.prank(assetAdmin);
        return registry.registerAsset(DOC_HASH, URI, issuer, VALUATION, VALUATION_AT);
    }
}
