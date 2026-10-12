// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IComplianceRegistry
/// @notice Minimal interface for the investor-eligibility registry consumed by RWA tokens.
/// @dev Tokens depend on this interface, not on the ComplianceRegistry implementation, so
///      the policy engine can be swapped without redeploying the token. Every function is
///      a view: policy is read-only from the token's perspective and the registry never
///      reverts on a policy decision — it returns a bool and lets the caller revert.
/// @author Lintar Ar' Rafii
/// @custom:security-contact arrafiilintar@gmail.com
interface IComplianceRegistry {
    /// @notice Emitted when an investor is verified (or re-verified) with an expiry and jurisdiction.
    /// @param investor Address that was verified.
    /// @param expiry Unix timestamp after which the verification lapses; 0 means it never expires.
    /// @param jurisdiction ISO 3166-1 numeric country code recorded for the investor.
    event InvestorVerified(address indexed investor, uint64 expiry, uint16 jurisdiction);

    /// @notice Emitted when an investor's verification is revoked (KYC fail, withdrawal).
    /// @param investor Address whose verification was revoked.
    event InvestorRevoked(address indexed investor);

    /// @notice Emitted when an investor is frozen or unfrozen (sanctions, legal hold).
    /// @param investor Address that was frozen or unfrozen.
    /// @param frozen True when the investor was frozen, false when unfrozen.
    event InvestorFrozen(address indexed investor, bool frozen);

    /// @notice Investor eligibility record. Packed into a single storage slot:
    ///         verified (1) + expiry (8) + jurisdiction (2) + frozen (1) = 12 bytes.
    /// @dev `expiry == 0` means the verification never expires.
    /// @param verified Whether KYC verification has been granted and not revoked.
    /// @param expiry Unix timestamp after which the verification lapses; 0 means it never expires.
    /// @param jurisdiction ISO 3166-1 numeric country code (informational in v1).
    /// @param frozen Whether the account is under a legal or sanctions hold.
    struct Investor {
        bool verified;
        uint64 expiry;
        uint16 jurisdiction;
        bool frozen;
    }

    /// @notice Whether `from` may send to `to` under the current compliance policy.
    /// @dev Called by the token on every balance change. Mint passes from == address(0),
    ///      burn passes to == address(0); the zero side is not checked.
    /// @param from Source of the balance change; `address(0)` on the mint path.
    /// @param to Recipient of the balance change; `address(0)` on the burn path.
    /// @return allowed True when both non-zero sides are eligible.
    function isTransferAllowed(address from, address to) external view returns (bool allowed);

    /// @notice Whether `investor` is currently eligible to transact
    ///         (verified, not past expiry, not frozen).
    /// @dev Useful for frontend pre-flight checks before submitting a transfer.
    /// @param investor Address whose current eligibility is queried.
    /// @return True when `investor` is verified, unexpired, and unfrozen.
    function isVerified(address investor) external view returns (bool);

    /// @notice The raw eligibility record for `investor`.
    /// @dev Includes expiry, jurisdiction, and frozen flag, which `isVerified` collapses
    ///      into a single bool — useful for showing an investor *why* they are blocked.
    /// @param investor Address whose record is queried.
    /// @return The full eligibility record for `investor`.
    function investorStatus(address investor) external view returns (Investor memory);
}
