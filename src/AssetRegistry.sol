// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IAssetRegistry} from "./interfaces/IAssetRegistry.sol";

/// @title AssetRegistry
/// @notice Binds on-chain RWA tokens to their off-chain legal reality (deed, prospectus,
///         invoice) and tracks asset lifecycle status. Metadata changes here never touch
///         the money contract.
/// @dev Valuations are informational metadata only — they are never read by RWAToken and
///      never participate in supply math. An admin-written valuation is not an oracle.
/// @author Lintar Ar' Rafii
/// @custom:security-contact arrafiilintar@gmail.com
contract AssetRegistry is AccessControl, IAssetRegistry {
    /// @notice Role permitted to register and amend asset records.
    bytes32 public constant ASSET_ADMIN_ROLE = keccak256("ASSET_ADMIN_ROLE");

    /// @notice Total number of registered assets; asset ids start at 1.
    uint256 public assetCount;

    /// @notice Per-asset provenance records, keyed by asset id (1-based).
    /// @dev Private; read through `getAsset`, which rejects ids outside `[1, assetCount]`
    ///      so callers never receive a silently zero-filled record.
    mapping(uint256 => Asset) private _assets;

    /// @notice Emitted when a new asset is registered with its document hash and issuer.
    /// @param assetId Id assigned to the new asset (starts at 1).
    /// @param docHash Hash of the off-chain legal documents at registration time.
    /// @param issuer Address of the asset issuer.
    event AssetRegistered(uint256 indexed assetId, bytes32 docHash, address indexed issuer);

    /// @notice Emitted when an asset's documents, URI, or valuation are amended.
    /// @param assetId Id of the amended asset.
    /// @param docHash New hash of the off-chain legal documents.
    /// @param uri New pointer to the asset metadata documents.
    /// @param valuation New informational valuation; never used in token math.
    /// @param valuationAt Timestamp the new valuation refers to.
    event AssetUpdated(uint256 indexed assetId, bytes32 docHash, string uri, uint256 valuation, uint64 valuationAt);

    /// @notice Emitted when an asset's lifecycle status changes.
    /// @param assetId Id of the asset whose status changed.
    /// @param status New lifecycle status (Active / Frozen / Redeemed).
    event AssetStatusChanged(uint256 indexed assetId, AssetStatus status);

    /// @notice Reverts when a required address (admin, issuer) is zero.
    error ZeroAddress();

    /// @notice Reverts when an asset id is 0 or above `assetCount` — never registered.
    /// @param assetId The id that was requested.
    error UnknownAsset(uint256 assetId);

    /// @notice Reverts when `batchSetStatus` is called with arrays of different lengths.
    /// @param idsLength Number of entries in the `ids` array.
    /// @param statusesLength Number of entries in the `statuses` array.
    error LengthMismatch(uint256 idsLength, uint256 statusesLength);

    /// @param admin Address receiving DEFAULT_ADMIN_ROLE (role administration).
    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Register a new asset and return its id (starts at 1, increments).
    /// @dev Reverts with `ZeroAddress` when `issuer` is zero. The returned id is
    ///      `assetCount` after increment, so the first registered asset is id 1 —
    ///      id 0 is permanently reserved as "not registered".
    /// @param docHash Hash of the off-chain legal documents (deed, prospectus, invoice).
    /// @param uri Pointer to the asset metadata documents.
    /// @param issuer Address of the asset issuer; must not be zero.
    /// @param valuation Informational valuation; never used in token math.
    /// @param valuationAt Timestamp the valuation refers to.
    /// @return assetId Id of the newly registered asset.
    function registerAsset(bytes32 docHash, string calldata uri, address issuer, uint256 valuation, uint64 valuationAt)
        external
        onlyRole(ASSET_ADMIN_ROLE)
        returns (uint256 assetId)
    {
        if (issuer == address(0)) revert ZeroAddress();
        assetId = ++assetCount;
        _assets[assetId] = Asset({
            docHash: docHash,
            uri: uri,
            issuer: issuer,
            valuation: valuation,
            valuationAt: valuationAt,
            status: AssetStatus.Active
        });
        emit AssetRegistered(assetId, docHash, issuer);
    }

    /// @notice Amend an asset's documents, URI, or valuation (re-valuation, doc amendment).
    /// @dev Reverts with `UnknownAsset` when the id does not exist. Overwrites every
    ///      field — the caller must resubmit values it wants to keep. Emits an event on
    ///      every amendment so off-chain indexers can diff document versions.
    /// @param assetId Id of the asset to amend; must already exist.
    /// @param docHash New hash of the off-chain legal documents.
    /// @param uri New pointer to the asset metadata documents.
    /// @param valuation New informational valuation; never used in token math.
    /// @param valuationAt Timestamp the new valuation refers to.
    function updateAsset(uint256 assetId, bytes32 docHash, string calldata uri, uint256 valuation, uint64 valuationAt)
        external
        onlyRole(ASSET_ADMIN_ROLE)
    {
        Asset storage asset = _getAsset(assetId);
        asset.docHash = docHash;
        asset.uri = uri;
        asset.valuation = valuation;
        asset.valuationAt = valuationAt;
        emit AssetUpdated(assetId, docHash, uri, valuation, valuationAt);
    }

    /// @notice Change an asset's lifecycle status (Active / Frozen / Redeemed).
    /// @dev Reverts with `UnknownAsset` when the id does not exist. Status is metadata
    ///      only — it does not by itself halt the token, which is controlled by
    ///      `RWAToken.pause`. Moving to Redeemed signals the off-chain process finished.
    /// @param assetId Id of the asset whose status changes; must already exist.
    /// @param status New lifecycle status.
    function setStatus(uint256 assetId, AssetStatus status) external onlyRole(ASSET_ADMIN_ROLE) {
        Asset storage asset = _getAsset(assetId);
        asset.status = status;
        emit AssetStatusChanged(assetId, status);
    }

    /// @notice Set the status of many assets in one transaction.
    /// @dev Reverts with `LengthMismatch` when the arrays differ in length, and with
    ///      `UnknownAsset` on any unknown id — the whole batch reverts, so a batch is
    ///      never partially applied.
    /// @param ids Ids of the assets whose status changes; every id must already exist.
    /// @param statuses New status per asset, positionally matched to `ids`.
    function batchSetStatus(uint256[] calldata ids, AssetStatus[] calldata statuses)
        external
        onlyRole(ASSET_ADMIN_ROLE)
    {
        if (ids.length != statuses.length) {
            revert LengthMismatch(ids.length, statuses.length);
        }
        for (uint256 i; i < ids.length;) {
            Asset storage asset = _getAsset(ids[i]);
            asset.status = statuses[i];
            emit AssetStatusChanged(ids[i], statuses[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IAssetRegistry
    /// @dev Reverts with `UnknownAsset` when `assetId` is 0 or above `assetCount`.
    /// @param assetId Id of the asset to read.
    /// @return The provenance record for the asset.
    function getAsset(uint256 assetId) external view returns (Asset memory) {
        if (assetId == 0 || assetId > assetCount) revert UnknownAsset(assetId);
        return _assets[assetId];
    }

    /// @dev Existence-checked storage accessor used by the mutating functions so they
    ///      can write through a reference instead of copying the struct.
    /// @param assetId Id of the asset to access; must already exist.
    /// @return Storage reference to the asset's record.
    function _getAsset(uint256 assetId) internal view returns (Asset storage) {
        if (assetId == 0 || assetId > assetCount) revert UnknownAsset(assetId);
        return _assets[assetId];
    }
}
