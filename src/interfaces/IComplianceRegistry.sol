// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IComplianceRegistry
/// @notice Minimal interface for the investor-eligibility registry consumed by RWA tokens.
interface IComplianceRegistry {
    /// @notice Emitted when an investor is verified (or re-verified) with an expiry and jurisdiction.
    event InvestorVerified(address indexed investor, uint64 expiry, uint16 jurisdiction);

    /// @notice Emitted when an investor's verification is revoked (KYC fail, withdrawal).
    event InvestorRevoked(address indexed investor);

    /// @notice Emitted when an investor is frozen or unfrozen (sanctions, legal hold).
    event InvestorFrozen(address indexed investor, bool frozen);

    /// @notice Investor eligibility record. Packed into a single storage slot:
    ///         verified (1) + expiry (8) + jurisdiction (2) + frozen (1) = 12 bytes.
    /// @dev `expiry == 0` means the verification never expires.
    struct Investor {
        bool verified;
        uint64 expiry;
        uint16 jurisdiction;
        bool frozen;
    }

    /// @notice Whether `from` may send to `to` under the current compliance policy.
    /// @dev Called by the token on every balance change. Mint passes from == address(0),
    ///      burn passes to == address(0); the zero side is not checked.
    /// @return allowed True when both non-zero sides are eligible.
    function isTransferAllowed(address from, address to) external view returns (bool allowed);

    /// @notice Whether `investor` is currently eligible to transact
    ///         (verified, not past expiry, not frozen).
    function isVerified(address investor) external view returns (bool);

    /// @notice The raw eligibility record for `investor`.
    function investorStatus(address investor) external view returns (Investor memory);
}
