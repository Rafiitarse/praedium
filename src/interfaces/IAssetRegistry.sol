// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IAssetRegistry
/// @notice Minimal interface for the off-chain asset metadata registry consumed by RWA tokens.
interface IAssetRegistry {
    /// @notice Lifecycle status of a registered asset.
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
    function getAsset(uint256 assetId) external view returns (Asset memory);
}
