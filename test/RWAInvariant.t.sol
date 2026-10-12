// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {RWAToken} from "../src/RWAToken.sol";
import {ComplianceRegistry} from "../src/ComplianceRegistry.sol";
import {AssetRegistry} from "../src/AssetRegistry.sol";

/// @title RWAInvariantTest
/// @notice Property-based testing over a bounded actor set via a handler contract.
///         The compliance invariant — no non-compliant address can EVER hold a
///         balance, regardless of action ordering — is unreachable by unit tests
///         alone; only random call sequences across verify/revoke/freeze/mint/
///         transfer/burn can falsify it.
contract RWAInvariantTest is Test {
    RWAHandler handler;
    RWAToken token;
    ComplianceRegistry compliance;

    address admin = makeAddr("admin");
    address officer = makeAddr("officer");
    address minter = makeAddr("minter");

    address[] actors;

    function setUp() public {
        actors.push(makeAddr("actor0"));
        actors.push(makeAddr("actor1"));
        actors.push(makeAddr("actor2"));
        actors.push(makeAddr("actor3"));
        actors.push(makeAddr("actor4"));

        compliance = new ComplianceRegistry(admin);
        AssetRegistry assets = new AssetRegistry(admin);

        vm.startPrank(admin);
        compliance.grantRole(compliance.COMPLIANCE_OFFICER_ROLE(), officer);
        assets.grantRole(assets.ASSET_ADMIN_ROLE(), admin);
        assets.registerAsset(keccak256("doc"), "ipfs://docs", admin, 1_000_000e6, 1_700_000_000);
        vm.stopPrank();

        token = new RWAToken("Invariant Token", "INV", address(compliance), address(assets), 1, admin);
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();

        handler = new RWAHandler(token, compliance, officer, minter, actors);
        targetContract(address(handler));
    }

    /// @notice Conservation of value: supply always equals the sum of balances.
    function invariant_totalSupplyEqualsSumOfBalances() public view {
        uint256 sum;
        for (uint256 i; i < actors.length; i++) {
            sum += token.balanceOf(actors[i]);
        }
        sum += token.balanceOf(address(handler)); // tokens stuck mid-flow would break this
        assertEq(token.totalSupply(), sum, "supply must equal sum of balances");
    }

    /// @notice THE compliance invariant: an ineligible address can never ACQUIRE tokens.
    ///         Revoked/frozen holders keep their existing (frozen) balance by design —
    ///         forced transfer is a legal process, not a contract call — but their
    ///         balance may never grow. This is falsifiable by random action sequences,
    ///         unlike a naive "balance > 0 ⟹ eligible" which the design rejects.
    function invariant_ineligibleBalanceNeverGrows() public view {
        for (uint256 i; i < actors.length; i++) {
            if (!compliance.isVerified(actors[i])) {
                assertLe(
                    token.balanceOf(actors[i]),
                    handler.lastEligibleBalance(actors[i]),
                    "ineligible address must never acquire tokens"
                );
            }
        }
    }

    /// @notice Ghost accounting: supply equals minted minus burned across every action.
    function invariant_supplyEqualsGhostTotals() public view {
        assertEq(token.totalSupply(), handler.ghostMinted() - handler.ghostBurned());
    }
}

/// @notice Handler driving the system with bounded, seed-selected actors.
///         Every seed is bound to the actor set; every action records ghost totals.
contract RWAHandler is Test {
    RWAToken token;
    ComplianceRegistry compliance;
    address officer;
    address minter;
    address[] actors;

    uint256 public ghostMinted;
    uint256 public ghostBurned;

    /// @notice Balance each actor held while last eligible. The compliance invariant
    ///         asserts an ineligible actor's balance never exceeds this snapshot.
    mapping(address => uint256) public lastEligibleBalance;

    constructor(
        RWAToken token_,
        ComplianceRegistry compliance_,
        address officer_,
        address minter_,
        address[] memory actors_
    ) {
        token = token_;
        compliance = compliance_;
        officer = officer_;
        minter = minter_;
        for (uint256 i; i < actors_.length; i++) {
            actors.push(actors_[i]);
        }
    }

    function verify(uint256 actorSeed) external {
        address actor = _actor(actorSeed);
        vm.prank(officer);
        compliance.verify(actor, 0, 360);
        _recordEligibleBalances();
    }

    function revoke(uint256 actorSeed) external {
        address actor = _actor(actorSeed);
        vm.prank(officer);
        compliance.revoke(actor);
        _recordEligibleBalances();
    }

    function freeze(uint256 actorSeed, bool frozen) external {
        address actor = _actor(actorSeed);
        vm.prank(officer);
        compliance.setFrozen(actor, frozen);
        _recordEligibleBalances();
    }

    function mint(uint256 actorSeed, uint256 amount) external {
        address actor = _actor(actorSeed);
        uint256 amt = bound(amount, 1, 1_000e18);
        vm.prank(minter);
        token.mint(actor, amt);
        ghostMinted += amt;
        _recordEligibleBalances();
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        uint256 amt = bound(amount, 0, token.balanceOf(from));
        if (amt == 0) return;
        vm.prank(from);
        token.transfer(to, amt);
        _recordEligibleBalances();
    }

    function burn(uint256 actorSeed, uint256 amount) external {
        address actor = _actor(actorSeed);
        uint256 amt = bound(amount, 1, token.balanceOf(actor));
        vm.prank(minter);
        token.burn(actor, amt);
        ghostBurned += amt;
        _recordEligibleBalances();
    }

    /// @dev Snapshot the current balance of every eligible actor. An actor whose
    ///      eligibility lapses afterwards keeps the snapshot as their ceiling.
    function _recordEligibleBalances() internal {
        for (uint256 i; i < actors.length; i++) {
            if (compliance.isVerified(actors[i])) {
                lastEligibleBalance[actors[i]] = token.balanceOf(actors[i]);
            }
        }
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[bound(seed, 0, actors.length - 1)];
    }
}
