// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {RWAToken} from "../src/RWAToken.sol";
import {ComplianceRegistry} from "../src/ComplianceRegistry.sol";
import {AssetRegistry} from "../src/AssetRegistry.sol";

/// @title RWATokenTest
/// @notice Unit + fuzz coverage for the token core. The compliance gate must fire on
///         ALL of mint / burn / transfer / transferFrom — a missed entry point would
///         be a silent compliance bypass, the worst failure mode for an RWA token.
contract RWATokenTest is Test {
    RWAToken token;
    ComplianceRegistry compliance;
    AssetRegistry assets;

    address admin = makeAddr("admin");
    address officer = makeAddr("officer");
    address minter = makeAddr("minter");
    address pauser = makeAddr("pauser");
    address alice = makeAddr("alice"); // verified
    address bob = makeAddr("bob"); // verified
    address carol = makeAddr("carol"); // NOT verified

    uint256 constant ASSET_ID = 1;
    uint256 constant MINT_AMOUNT = 1000e18;

    function setUp() public {
        compliance = new ComplianceRegistry(admin);
        assets = new AssetRegistry(admin);

        vm.startPrank(admin);
        compliance.grantRole(compliance.COMPLIANCE_OFFICER_ROLE(), officer);
        assets.grantRole(assets.ASSET_ADMIN_ROLE(), admin);
        assets.registerAsset(keccak256("doc"), "ipfs://docs", admin, 1_000_000e6, 1_700_000_000);
        vm.stopPrank();

        token = new RWAToken("Manhattan REIT Token", "MRE", address(compliance), address(assets), ASSET_ID, admin);

        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.PAUSER_ROLE(), pauser);
        vm.stopPrank();

        vm.startPrank(officer);
        compliance.verify(alice, 0, 360);
        compliance.verify(bob, 0, 360);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // Mint
    // ------------------------------------------------------------------

    function test_mint_onlyMinter() public {
        vm.prank(strangerAddr());
        vm.expectRevert();
        token.mint(alice, MINT_AMOUNT);
    }

    function test_mint_toVerifiedSucceeds() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);
        assertEq(token.balanceOf(alice), MINT_AMOUNT);
        assertEq(token.totalSupply(), MINT_AMOUNT);
    }

    function test_mint_toUnverified_revertsWithTransferNotAllowed() public {
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(RWAToken.TransferNotAllowed.selector, address(0), carol));
        token.mint(carol, MINT_AMOUNT);
    }

    function test_mint_emitsAssetMinted() public {
        vm.prank(minter);
        vm.expectEmit(true, true, false, true);
        emit RWAToken.AssetMinted(ASSET_ID, alice, MINT_AMOUNT);
        token.mint(alice, MINT_AMOUNT);
    }

    function test_mint_revertsOnZeroAmountAndZeroAddress() public {
        vm.startPrank(minter);
        vm.expectRevert(RWAToken.ZeroAmount.selector);
        token.mint(alice, 0);
        vm.expectRevert(RWAToken.ZeroAddress.selector);
        token.mint(address(0), MINT_AMOUNT);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // Burn
    // ------------------------------------------------------------------

    function test_burn_onlyMinter() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);
        vm.prank(strangerAddr());
        vm.expectRevert();
        token.burn(alice, MINT_AMOUNT);
    }

    function test_burn_reducesSupply() public {
        vm.startPrank(minter);
        token.mint(alice, MINT_AMOUNT);
        token.burn(alice, 400e18);
        vm.stopPrank();
        assertEq(token.balanceOf(alice), 600e18);
        assertEq(token.totalSupply(), 600e18);
    }

    function test_burn_fromUnverified_reverts() public {
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(RWAToken.TransferNotAllowed.selector, carol, address(0)));
        token.burn(carol, MINT_AMOUNT);
    }

    // ------------------------------------------------------------------
    // Transfers — the compliance gate on the primary path
    // ------------------------------------------------------------------

    function test_transfer_verifiedToVerified() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);
        vm.prank(alice);
        token.transfer(bob, 300e18);
        assertEq(token.balanceOf(bob), 300e18);
    }

    function test_transfer_toUnverified_reverts() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(RWAToken.TransferNotAllowed.selector, alice, carol));
        token.transfer(carol, 100e18);
    }

    function test_transfer_fromUnverified_reverts() public {
        // Carol somehow holds tokens (e.g. verified then revoked) — she cannot send
        vm.startPrank(officer);
        compliance.verify(carol, 0, 360);
        vm.stopPrank();
        vm.prank(minter);
        token.mint(carol, MINT_AMOUNT);
        vm.prank(officer);
        compliance.revoke(carol);

        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(RWAToken.TransferNotAllowed.selector, carol, alice));
        token.transfer(alice, 100e18);
        assertEq(token.balanceOf(carol), MINT_AMOUNT, "frozen, not clawed back");
    }

    // ------------------------------------------------------------------
    // transferFrom — allowance AND compliance both apply
    // ------------------------------------------------------------------

    function test_transferFrom_respectsAllowanceAndCompliance() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);
        vm.prank(alice);
        token.approve(bob, 500e18);

        vm.prank(bob);
        token.transferFrom(alice, bob, 500e18);
        assertEq(token.balanceOf(bob), 500e18);

        // Beyond allowance
        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(alice, bob, 1e18);
    }

    function test_transferFrom_toUnverified_revertsDespiteAllowance() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);
        vm.prank(alice);
        token.approve(bob, MINT_AMOUNT);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(RWAToken.TransferNotAllowed.selector, alice, carol));
        token.transferFrom(alice, carol, 100e18);
    }

    function test_approve_isNotComplianceGated() public {
        // Approving is not a transfer — Carol can hold an allowance, she just cannot receive
        vm.prank(alice);
        token.approve(carol, MINT_AMOUNT);
        assertEq(token.allowance(alice, carol), MINT_AMOUNT);
    }

    // ------------------------------------------------------------------
    // Pause
    // ------------------------------------------------------------------

    function test_pause_onlyPauser() public {
        vm.prank(strangerAddr());
        vm.expectRevert();
        token.pause();
    }

    function test_pause_blocksAllMovement() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);
        vm.prank(pauser);
        token.pause();

        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 100e18);

        vm.prank(minter);
        vm.expectRevert();
        token.mint(bob, 100e18);
    }

    function test_unpause_restoresMovement() public {
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);
        vm.startPrank(pauser);
        token.pause();
        token.unpause();
        vm.stopPrank();

        vm.prank(alice);
        token.transfer(bob, 100e18);
        assertEq(token.balanceOf(bob), 100e18);
    }

    // ------------------------------------------------------------------
    // Asset provenance
    // ------------------------------------------------------------------

    function test_assetURI_readsFromRegistry() public {
        assertEq(token.assetURI(), "ipfs://docs");
    }

    function test_constructor_revertsOnZeroAddresses() public {
        vm.expectRevert(RWAToken.ZeroAddress.selector);
        new RWAToken("X", "X", address(0), address(assets), ASSET_ID, admin);
        vm.expectRevert(RWAToken.ZeroAddress.selector);
        new RWAToken("X", "X", address(compliance), address(0), ASSET_ID, admin);
        vm.expectRevert(RWAToken.ZeroAddress.selector);
        new RWAToken("X", "X", address(compliance), address(assets), ASSET_ID, address(0));
    }

    // ------------------------------------------------------------------
    // Fuzz — compliance gate is absolute across random actors/amounts
    // ------------------------------------------------------------------

    function testFuzz_transferGate_neverBypasses(bool senderVerified, bool receiverVerified, uint96 amount) public {
        // Alice always starts eligible so she can hold tokens to send
        _verify(alice);
        vm.prank(minter);
        token.mint(alice, MINT_AMOUNT);

        if (!senderVerified) {
            // Revoke AFTER minting — she holds frozen tokens but cannot send
            vm.prank(officer);
            compliance.revoke(alice);
        }
        // Bob is pre-verified in setUp — flip him explicitly for the false case
        if (receiverVerified) {
            _verify(bob);
        } else {
            vm.prank(officer);
            compliance.revoke(bob);
        }

        uint256 send = bound(amount, 1, MINT_AMOUNT);
        if (senderVerified && receiverVerified) {
            vm.prank(alice);
            token.transfer(bob, send);
            assertEq(token.balanceOf(bob), send);
        } else {
            vm.prank(alice);
            vm.expectRevert(abi.encodeWithSelector(RWAToken.TransferNotAllowed.selector, alice, bob));
            token.transfer(bob, send);
        }
    }

    function _verify(address account) internal {
        vm.prank(officer);
        compliance.verify(account, 0, 360);
    }

    function strangerAddr() internal pure returns (address) {
        return address(0xdead);
    }
}
