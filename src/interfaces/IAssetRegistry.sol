// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IAssetRegistry
/// @notice Minimal interface for the off-chain asset metadata registry consumed by RWA tokens.
/// @dev Tokens depend on this interface, not on the AssetRegistry implementation, so the
///      metadata backend can be swapped without redeploying the token. Only `getAsset` is
///      exposed here — registration and lifecycle changes are admin operations that the
///      token has no business calling.
/// @author Lintar Ar' Rafii
/// @custom:security-contact arrafiilintar@gmail.com
interface IAssetRegistry {
    /// @notice Lifecycle status of a registered asset.
    /// @dev Informational metadata: it does not by itself halt token transfers, which are
    ///      controlled by the token's pause mechanism.
    /// @param Active The asset is live and its token is expected to trade.
    /// @param Frozen The asset is under a hold (dispute, investigation).
    /// @param Redeemed The asset has been redeemed and its tokens retired.
    enum AssetStatus {
        Active,
        Frozen,
        Redeemed
    }

    /// @notice Provenance record for a real-world asset backing a token.
    /// @param docHash    Hash of the off-chain legal documents (deed, prospectus, invoice).
    /// @param uri        Pointer to the asset metadata documents.
    /// @param issuer     Address of the asset issuer.
    /// @param valuation  Informational valuation — never used in token math.
    /// @param valuationAt Timestamp of the last valuation.
    /// @param status     Lifecycle status.
    struct Asset {
        bytes32 docHash;
        string uri;
        address issuer;
        uint256 valuation;
        uint64 valuationAt;
        AssetStatus status;
    }

    /// @notice The registered asset with id `assetId`.
    /// @dev Implementations reject unknown ids (0 or above the current count) rather than
    ///      returning a zero-filled record, so callers can never mistake a missing asset
    ///      for a valid one with empty metadata.
    /// @param assetId Id of the asset to read.
    /// @return The provenance record for the asset.
    function getAsset(uint256 assetId) external view returns (Asset memory);
}
