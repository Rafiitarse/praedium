// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IComplianceRegistry} from "./interfaces/IComplianceRegistry.sol";

/// @title ComplianceRegistry
/// @notice Single source of truth for investor eligibility across every RWA token that
///         points at it. One whitelist update satisfies all tokens an investor holds.
/// @dev Policy decisions never revert — `isTransferAllowed` returns a bool and the token
///      reverts with its own error, so failure modes are uniform and the function stays
///      cheap to call off-chain for UI pre-flight checks.
///
///      The COMPLIANCE_OFFICER_ROLE models a securities registrar: it can verify, revoke,
///      freeze, and re-verify investors. In production this must be a governed address
///      (multisig or hardened key service), never a hot wallet.
contract ComplianceRegistry is AccessControl, IComplianceRegistry {
    /// @notice Role permitted to mutate investor status (KYC pass/fail, freezes).
    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");

    mapping(address => Investor) private _investors;

    error ZeroAddress();
    error LengthMismatch(uint256 investorsLength, uint256 expiriesLength, uint256 jurisdictionsLength);

    /// @param admin Address receiving DEFAULT_ADMIN_ROLE (role administration).
    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // ---------------------------------------------------------------------
    // Compliance officer actions
    // ---------------------------------------------------------------------

    /// @notice Mark `investor` as KYC-verified until `expiry` (0 = never expires).
    /// @dev Re-verifying an unfrozen investor resets expiry and jurisdiction.
    ///      Re-verifying a FROZEN investor clears the freeze — freezes are a legal
    ///      mechanism, so unfreezing through `verify` is intentional: a cleared
    ///      sanctions hit must restore full eligibility in one action.
    /// @param investor Address to verify.
    /// @param expiry Unix timestamp after which the verification lapses; 0 = never.
    /// @param jurisdiction ISO 3166-1 numeric country code (informational in v1).
    function verify(address investor, uint64 expiry, uint16 jurisdiction) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        if (investor == address(0)) revert ZeroAddress();
        _investors[investor] = Investor({verified: true, expiry: expiry, jurisdiction: jurisdiction, frozen: false});
        emit InvestorVerified(investor, expiry, jurisdiction);
    }

    /// @notice Revoke `investor`'s verification. Their balance is frozen, not clawed back —
    ///         forced transfer is a legal process, not a smart-contract call.
    /// @dev Clears verified/expiry/jurisdiction; leaves `frozen` untouched (a sanctions
    ///      hold must survive a revocation).
    function revoke(address investor) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        Investor storage inv = _investors[investor];
        inv.verified = false;
        inv.expiry = 0;
        inv.jurisdiction = 0;
        emit InvestorRevoked(investor);
    }

    /// @notice Freeze or unfreeze `investor` (sanctions hit, court order).
    function setFrozen(address investor, bool frozen) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        _investors[investor].frozen = frozen;
        emit InvestorFrozen(investor, frozen);
    }

    /// @notice Verify many investors in one transaction (onboarding in bulk).
    /// @param investors Addresses to verify.
    /// @param expiries Per-investor expiry timestamps (0 = never).
    /// @param jurisdictions Per-investor ISO 3166-1 numeric codes.
    function batchVerify(address[] calldata investors, uint64[] calldata expiries, uint16[] calldata jurisdictions)
        external
        onlyRole(COMPLIANCE_OFFICER_ROLE)
    {
        if (investors.length != expiries.length || investors.length != jurisdictions.length) {
            revert LengthMismatch(investors.length, expiries.length, jurisdictions.length);
        }
        for (uint256 i; i < investors.length;) {
            if (investors[i] == address(0)) revert ZeroAddress();
            _investors[investors[i]] =
                Investor({verified: true, expiry: expiries[i], jurisdiction: jurisdictions[i], frozen: false});
            emit InvestorVerified(investors[i], expiries[i], jurisdictions[i]);
            unchecked {
                ++i;
            }
        }
    }

    // ---------------------------------------------------------------------
    // Views (token gate + frontend pre-flight)
    // ---------------------------------------------------------------------

    /// @inheritdoc IComplianceRegistry
    function isTransferAllowed(address from, address to) public view returns (bool) {
        // Mint path (from == 0): only the recipient must be eligible.
        // Burn path (to == 0): only the sender must be eligible.
        if (from != address(0) && !_isEligible(from)) return false;
        if (to != address(0) && !_isEligible(to)) return false;
        return true;
    }

    /// @inheritdoc IComplianceRegistry
    function isVerified(address investor) external view returns (bool) {
        return _isEligible(investor);
    }

    /// @inheritdoc IComplianceRegistry
    function investorStatus(address investor) external view returns (Investor memory) {
        return _investors[investor];
    }

    /// @dev An account is eligible when verified, not past expiry (0 = never),
    ///      and not frozen. A single SLOAD — the struct occupies one packed slot.
    function _isEligible(address account) internal view returns (bool) {
        Investor storage inv = _investors[account];
        if (!inv.verified) return false;
        if (inv.expiry != 0 && block.timestamp > inv.expiry) return false;
        if (inv.frozen) return false;
        return true;
    }
}
