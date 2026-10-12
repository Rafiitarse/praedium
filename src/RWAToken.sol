// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IComplianceRegistry} from "./interfaces/IComplianceRegistry.sol";
import {IAssetRegistry} from "./interfaces/IAssetRegistry.sol";

/// @title RWAToken
/// @notice ERC-20 token representing a fractional interest in a real-world asset registered
///         in the AssetRegistry, with every balance change gated by the ComplianceRegistry.
/// @dev The compliance gate lives in a single `_update` override — the one funnel every
///      mint, burn, transfer, and transferFrom passes through (OpenZeppelin v5's intended
///      customization seam). A missed entry point is structurally impossible, not merely
///      disciplined against.
///
///      Trust model: MINTER_ROLE issues and redeems asset tokens; PAUSER_ROLE halts all
///      movement; DEFAULT_ADMIN_ROLE administers roles. On mainnet all three must be
///      multisigs. The compliance registry (not this contract) owns investor policy.
contract RWAToken is ERC20, AccessControl, Pausable {
    /// @notice Role permitted to mint (issuer onboarding) and burn (redemption) tokens.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role permitted to pause and unpause transfers (emergency circuit breaker).
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Investor-eligibility registry consulted on every balance change. Immutable.
    IComplianceRegistry public immutable compliance;

    /// @notice Asset metadata registry this token is backed by. Immutable.
    IAssetRegistry public immutable assets;

    /// @notice Id of the backing asset in the AssetRegistry. Immutable.
    uint256 public immutable assetId;

    event AssetMinted(uint256 indexed assetId, address indexed to, uint256 amount);
    event AssetBurned(uint256 indexed assetId, address indexed from, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error TransferNotAllowed(address from, address to);

    /// @param name_ ERC-20 token name.
    /// @param symbol_ ERC-20 token symbol.
    /// @param compliance_ ComplianceRegistry address (immutable).
    /// @param assets_ AssetRegistry address (immutable).
    /// @param assetId_ Id of the backing asset in the AssetRegistry (immutable).
    /// @param admin Address receiving DEFAULT_ADMIN_ROLE.
    constructor(
        string memory name_,
        string memory symbol_,
        address compliance_,
        address assets_,
        uint256 assetId_,
        address admin
    ) ERC20(name_, symbol_) {
        if (compliance_ == address(0) || assets_ == address(0) || admin == address(0)) {
            revert ZeroAddress();
        }
        compliance = IComplianceRegistry(compliance_);
        assets = IAssetRegistry(assets_);
        assetId = assetId_;
        // Fail fast: the backing asset must exist in the registry at deploy time,
        // otherwise assetURI() would revert forever on an unregistered id.
        assets.getAsset(assetId_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // ---------------------------------------------------------------------
    // Issuer operations (role-gated)
    // ---------------------------------------------------------------------

    /// @notice Mint `amount` tokens to `to` (issuer onboarding).
    /// @dev Reverts when paused or when `to` is not compliance-eligible
    ///      (the `_update` gate checks the mint path's recipient).
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        _mint(to, amount);
        emit AssetMinted(assetId, to, amount);
    }

    /// @notice Burn `amount` tokens from `from` (redemption / off-chain sale settlement).
    /// @dev Reverts when paused or when `from` is not compliance-eligible.
    ///      Burning requires the MINTER_ROLE — holder-initiated burns are not supported
    ///      because redemption is an issuer process, not a holder escape hatch.
    function burn(address from, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        _burn(from, amount);
        emit AssetBurned(assetId, from, amount);
    }

    // ---------------------------------------------------------------------
    // Emergency controls
    // ---------------------------------------------------------------------

    /// @notice Halt all mints, burns, and transfers.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Resume mints, burns, and transfers.
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ---------------------------------------------------------------------
    // Compliance gate — the single enforcement point
    // ---------------------------------------------------------------------

    /// @dev Every balance change (mint/burn/transfer/transferFrom) passes through here.
    ///      The registry is a view call: policy decisions return a bool, this contract
    ///      reverts with `TransferNotAllowed(from, to)` so failures are uniform and
    ///      debuggable. The check runs BEFORE `super._update`, so a rejected transfer
    ///      never mutates state.
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        if (!compliance.isTransferAllowed(from, to)) revert TransferNotAllowed(from, to);
        super._update(from, to, value);
    }

    /// @notice Off-chain metadata URI of the backing asset (from the AssetRegistry).
    /// @dev Lets wallets and tooling discover the asset's legal documents without
    ///      hardcoding off-chain endpoints.
    function assetURI() external view returns (string memory) {
        return assets.getAsset(assetId).uri;
    }
}
