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
contract AssetRegistry is AccessControl, IAssetRegistry {
    /// @notice Role permitted to register and amend asset records.
    bytes32 public constant ASSET_ADMIN_ROLE = keccak256("ASSET_ADMIN_ROLE");

    /// @notice Total number of registered assets; asset ids start at 1.
    uint256 public assetCount;

    mapping(uint256 => Asset) private _assets;

    event AssetRegistered(uint256 indexed assetId, bytes32 docHash, address indexed issuer);
    event AssetUpdated(uint256 indexed assetId, bytes32 docHash, string uri, uint256 valuation, uint64 valuationAt);
    event AssetStatusChanged(uint256 indexed assetId, AssetStatus status);

    error ZeroAddress();
    error UnknownAsset(uint256 assetId);
    error LengthMismatch(uint256 idsLength, uint256 statusesLength);

    /// @param admin Address receiving DEFAULT_ADMIN_ROLE (role administration).
    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Register a new asset and return its id (starts at 1, increments).
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
    function setStatus(uint256 assetId, AssetStatus status) external onlyRole(ASSET_ADMIN_ROLE) {
        Asset storage asset = _getAsset(assetId);
        asset.status = status;
        emit AssetStatusChanged(assetId, status);
    }

    /// @notice Set the status of many assets in one transaction.
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
    function getAsset(uint256 assetId) external view returns (Asset memory) {
        if (assetId == 0 || assetId > assetCount) revert UnknownAsset(assetId);
        return _assets[assetId];
    }

    function _getAsset(uint256 assetId) internal view returns (Asset storage) {
        if (assetId == 0 || assetId > assetCount) revert UnknownAsset(assetId);
        return _assets[assetId];
    }
}
