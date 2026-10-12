// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {RWAToken} from "../src/RWAToken.sol";
import {ComplianceRegistry} from "../src/ComplianceRegistry.sol";
import {AssetRegistry} from "../src/AssetRegistry.sol";
import {IAssetRegistry} from "../src/interfaces/IAssetRegistry.sol";

/// @title RWASystemTest
/// @notice Integration harness deploying all three contracts with real wiring
///         (no mocks) — cross-contract constructor args and assetId agreement are
///         where the real integration bugs live, and unit tests with mocks miss them.
contract RWASystemTest is Test {
    ComplianceRegistry compliance;
    AssetRegistry assets;
    RWAToken token;

    address admin = makeAddr("admin");
    address officer = makeAddr("officer");
    address minter = makeAddr("minter");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol"); // never verified

    uint256 constant ASSET_ID = 1;
    uint256 constant INITIAL_MINT = 10_000e18;

    function setUp() public {
        // Deploy in dependency order: registries first, token last
        compliance = new ComplianceRegistry(admin);
        assets = new AssetRegistry(admin);

        vm.startPrank(admin);
        compliance.grantRole(compliance.COMPLIANCE_OFFICER_ROLE(), officer);
        assets.grantRole(assets.ASSET_ADMIN_ROLE(), admin);
        uint256 assetId = assets.registerAsset(
            keccak256("bond-prospectus-v1"), "ipfs://bond-prospectus", admin, 5_000_000e6, uint64(block.timestamp)
        );
        assertEq(assetId, ASSET_ID);
        vm.stopPrank();

        token = new RWAToken("Infrastructure Bond Token", "IBT", address(compliance), address(assets), ASSET_ID, admin);

        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();

        vm.startPrank(officer);
        compliance.verify(alice, 0, 360);
        compliance.verify(bob, 0, 360);
        vm.stopPrank();
    }

    /// @notice The canonical lifecycle: register -> verify -> mint -> transfer -> redeem.
    function test_fullLifecycle() public {
        // 1. Onboard investors (already verified in setUp)
        assertTrue(compliance.isVerified(alice));

        // 2. Issue
        vm.prank(minter);
        token.mint(alice, INITIAL_MINT);
        assertEq(token.totalSupply(), INITIAL_MINT);

        // 3. Secondary transfer between verified investors
        vm.prank(alice);
        token.transfer(bob, 4_000e18);
        assertEq(token.balanceOf(bob), 4_000e18);

        // 4. Attempted transfer to unverified party — blocked
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(carol, 1e18);

        // 5. Compliance revokes Carol-adjacent risk: revoke Bob (e.g. KYC lapse)
        vm.prank(officer);
        compliance.revoke(bob);
        assertEq(token.balanceOf(bob), 4_000e18, "revoked: frozen, not clawed back");

        // Bob can no longer send
        vm.prank(bob);
        vm.expectRevert();
        token.transfer(alice, 1e18);

        // 6. The issuer CANNOT unilaterally burn a revoked holder's tokens —
        //    forced transfer is a legal process, not a contract call.
        //    Frozen tokens stay frozen until legal resolution.
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(RWAToken.TransferNotAllowed.selector, bob, address(0)));
        token.burn(bob, 4_000e18);

        // 7. Legal resolution: re-verify Bob, then redeem his position
        vm.prank(officer);
        compliance.verify(bob, 0, 360);
        vm.prank(minter);
        token.burn(bob, 4_000e18);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.totalSupply(), 6_000e18);

        // 8. Asset lifecycle metadata
        IAssetRegistry.Asset memory asset = assets.getAsset(ASSET_ID);
        assertEq(asset.uri, "ipfs://bond-prospectus");
        assertEq(token.assetURI(), "ipfs://bond-prospectus", "token exposes asset URI");
    }

    /// @notice Emergency stop halts everything, resume restores it.
    function test_pauseHaltsEntireSystem() public {
        vm.prank(minter);
        token.mint(alice, INITIAL_MINT);

        // Read the role constant BEFORE pranking — the getter call consumes the prank
        bytes32 pauserRole = token.PAUSER_ROLE();
        vm.prank(admin);
        token.grantRole(pauserRole, admin);
        vm.prank(admin);
        token.pause();

        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 1e18);
        vm.prank(minter);
        vm.expectRevert();
        token.mint(bob, 1e18);

        vm.prank(admin);
        token.unpause();
        vm.prank(alice);
        token.transfer(bob, 1e18);
        assertEq(token.balanceOf(bob), 1e18);
    }

    /// @notice Freeze is immediate in both directions (sanctions scenario).
    function test_freezeIsImmediateBothDirections() public {
        vm.prank(minter);
        token.mint(alice, INITIAL_MINT);

        vm.prank(officer);
        compliance.setFrozen(alice, true);

        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 1e18);
        vm.prank(minter);
        vm.expectRevert();
        token.mint(alice, 1e18);
    }

    /// @notice Expiry lapses mid-life: eligible at mint time, blocked after deadline.
    function test_expiryLapsesMidLife() public {
        uint64 expiry = uint64(block.timestamp) + 7 days;
        vm.prank(officer);
        compliance.verify(alice, expiry, 360);

        vm.prank(minter);
        token.mint(alice, INITIAL_MINT);

        vm.warp(expiry + 1);
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 1e18);

        // Re-verification restores
        vm.prank(officer);
        compliance.verify(alice, 0, 360);
        vm.prank(alice);
        token.transfer(bob, 1e18);
        assertEq(token.balanceOf(bob), 1e18);
    }
}
