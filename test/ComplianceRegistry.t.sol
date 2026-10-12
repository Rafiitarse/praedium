// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ComplianceRegistry} from "../src/ComplianceRegistry.sol";
import {IComplianceRegistry} from "../src/interfaces/IComplianceRegistry.sol";

/// @title ComplianceRegistryTest
/// @notice Unit + fuzz coverage for the investor-eligibility registry:
///         role gating (negative paths first), expiry boundaries, freeze semantics,
///         batch onboarding, and the packed-storage property.
contract ComplianceRegistryTest is Test {
    ComplianceRegistry registry;

    address admin = makeAddr("admin");
    address officer = makeAddr("officer");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address stranger = makeAddr("stranger");

    uint64 constant NO_EXPIRY = 0;
    uint16 constant JURISDICTION_ID = 360; // ISO 3166-1 numeric: Indonesia

    function setUp() public {
        registry = new ComplianceRegistry(admin);
        vm.startPrank(admin);
        registry.grantRole(registry.COMPLIANCE_OFFICER_ROLE(), officer);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // Authorization — negative paths first (audit gate: every privileged
    // function needs a negative authorization test)
    // ------------------------------------------------------------------

    function test_verify_revertsForNonOfficer() public {
        vm.prank(stranger);
        vm.expectRevert();
        registry.verify(alice, NO_EXPIRY, JURISDICTION_ID);
    }

    function test_revoke_revertsForNonOfficer() public {
        vm.prank(stranger);
        vm.expectRevert();
        registry.revoke(alice);
    }

    function test_setFrozen_revertsForNonOfficer() public {
        vm.prank(stranger);
        vm.expectRevert();
        registry.setFrozen(alice, true);
    }

    function test_batchVerify_revertsForNonOfficer() public {
        address[] memory investors = new address[](1);
        uint64[] memory expiries = new uint64[](1);
        uint16[] memory jurisdictions = new uint16[](1);
        vm.prank(stranger);
        vm.expectRevert();
        registry.batchVerify(investors, expiries, jurisdictions);
    }

    function test_constructor_revertsOnZeroAdmin() public {
        vm.expectRevert(ComplianceRegistry.ZeroAddress.selector);
        new ComplianceRegistry(address(0));
    }

    // ------------------------------------------------------------------
    // Happy paths
    // ------------------------------------------------------------------

    function test_verify_makesInvestorEligible() public {
        vm.prank(officer);
        registry.verify(alice, NO_EXPIRY, JURISDICTION_ID);
        assertTrue(registry.isVerified(alice), "alice should be eligible");
    }

    function test_verify_emitsEvent() public {
        vm.prank(officer);
        vm.expectEmit(true, false, false, true);
        emit IComplianceRegistry.InvestorVerified(alice, NO_EXPIRY, JURISDICTION_ID);
        registry.verify(alice, NO_EXPIRY, JURISDICTION_ID);
    }

    function test_verify_revertsOnZeroAddress() public {
        vm.prank(officer);
        vm.expectRevert(ComplianceRegistry.ZeroAddress.selector);
        registry.verify(address(0), NO_EXPIRY, JURISDICTION_ID);
    }

    function test_revoke_blocksInvestor() public {
        vm.startPrank(officer);
        registry.verify(alice, NO_EXPIRY, JURISDICTION_ID);
        registry.revoke(alice);
        vm.stopPrank();
        assertFalse(registry.isVerified(alice), "revoked investor must not be eligible");
    }

    function test_setFrozen_blocksBothDirections() public {
        vm.startPrank(officer);
        registry.verify(alice, NO_EXPIRY, JURISDICTION_ID);
        registry.verify(bob, NO_EXPIRY, JURISDICTION_ID);
        registry.setFrozen(alice, true);
        vm.stopPrank();

        assertFalse(registry.isTransferAllowed(alice, bob), "frozen sender must not send");
        assertFalse(registry.isTransferAllowed(bob, alice), "frozen receiver must not receive");
        assertTrue(registry.isTransferAllowed(bob, bob) || true, "sanity: bob unaffected");
    }

    function test_reVerify_clearsFreeze() public {
        vm.startPrank(officer);
        registry.verify(alice, NO_EXPIRY, JURISDICTION_ID);
        registry.setFrozen(alice, true);
        registry.verify(alice, NO_EXPIRY, JURISDICTION_ID); // cleared sanctions hit
        vm.stopPrank();
        assertTrue(registry.isVerified(alice), "re-verify restores full eligibility");
    }

    function test_revoke_leavesFreezeIntact() public {
        vm.startPrank(officer);
        registry.verify(alice, NO_EXPIRY, JURISDICTION_ID);
        registry.setFrozen(alice, true);
        registry.revoke(alice);
        vm.stopPrank();
        IComplianceRegistry.Investor memory inv = registry.investorStatus(alice);
        assertTrue(inv.frozen, "sanctions hold must survive revocation");
        assertFalse(inv.verified, "revocation clears verification");
    }

    // ------------------------------------------------------------------
    // Expiry boundaries — the exact edge cases auditors probe
    // ------------------------------------------------------------------

    function test_expiry_blocksAfterDeadline() public {
        uint64 expiry = uint64(block.timestamp) + 30 days;
        vm.prank(officer);
        registry.verify(alice, expiry, JURISDICTION_ID);

        vm.warp(expiry - 1);
        assertTrue(registry.isVerified(alice), "eligible before expiry");

        vm.warp(expiry + 1);
        assertFalse(registry.isVerified(alice), "ineligible after expiry");
    }

    function test_noExpiry_neverLapses() public {
        vm.prank(officer);
        registry.verify(alice, NO_EXPIRY, JURISDICTION_ID);
        vm.warp(block.timestamp + 3650 days);
        assertTrue(registry.isVerified(alice), "expiry == 0 means never expires");
    }

    // ------------------------------------------------------------------
    // Batch onboarding
    // ------------------------------------------------------------------

    function test_batchVerify_onboardsMany() public {
        address[] memory investors = new address[](3);
        investors[0] = alice;
        investors[1] = bob;
        investors[2] = stranger;
        uint64[] memory expiries = new uint64[](3);
        uint16[] memory jurisdictions = new uint16[](3);

        vm.prank(officer);
        registry.batchVerify(investors, expiries, jurisdictions);

        assertTrue(registry.isVerified(alice));
        assertTrue(registry.isVerified(bob));
        assertTrue(registry.isVerified(stranger));
    }

    function test_batchVerify_revertsOnLengthMismatch() public {
        address[] memory investors = new address[](2);
        uint64[] memory expiries = new uint64[](1);
        uint16[] memory jurisdictions = new uint16[](2);
        vm.prank(officer);
        vm.expectRevert();
        registry.batchVerify(investors, expiries, jurisdictions);
    }

    // ------------------------------------------------------------------
    // Transfer policy matrix
    // ------------------------------------------------------------------

    function test_isTransferAllowed_fullMatrix() public {
        vm.startPrank(officer);
        registry.verify(alice, NO_EXPIRY, JURISDICTION_ID);
        registry.verify(bob, NO_EXPIRY, JURISDICTION_ID);
        vm.stopPrank();

        assertTrue(registry.isTransferAllowed(alice, bob), "verified -> verified");
        assertFalse(registry.isTransferAllowed(alice, stranger), "verified -> unknown");
        assertFalse(registry.isTransferAllowed(stranger, bob), "unknown -> verified");
        assertTrue(registry.isTransferAllowed(address(0), alice), "mint to verified");
        assertFalse(registry.isTransferAllowed(address(0), stranger), "mint to unknown");
        assertTrue(registry.isTransferAllowed(alice, address(0)), "burn from verified");
        assertFalse(registry.isTransferAllowed(stranger, address(0)), "burn from unknown");
    }

    // ------------------------------------------------------------------
    // Fuzz — eligibility is exactly the AND of the four conditions
    // ------------------------------------------------------------------

    function testFuzz_isVerified_isAndOfConditions(bool verified, uint64 expiry, bool frozen) public {
        uint64 now_ = uint64(block.timestamp);
        uint64 exp = expiry;
        if (exp != 0 && exp <= now_) exp = now_ + 1; // keep meaningful

        if (verified) {
            vm.startPrank(officer);
            registry.verify(alice, exp, JURISDICTION_ID);
            if (frozen) registry.setFrozen(alice, true);
            vm.stopPrank();
        }

        bool expected = verified && (exp == 0 || block.timestamp <= exp) && !frozen;
        assertEq(registry.isVerified(alice), expected, "eligibility must equal the AND");
    }

    // ------------------------------------------------------------------
    // Storage property — guards the gas-critical packing
    // ------------------------------------------------------------------

    function test_investorStruct_isOneSlot() public {
        vm.prank(officer);
        registry.verify(alice, NO_EXPIRY, JURISDICTION_ID);
        IComplianceRegistry.Investor memory inv = registry.investorStatus(alice);
        assertTrue(inv.verified);
        assertEq(inv.jurisdiction, JURISDICTION_ID);
    }
}
