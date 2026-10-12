import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  Transfer as TransferEvent,
  AssetMinted,
  AssetBurned,
} from "../generated/RWAToken/RWAToken";
import {
  InvestorVerified,
  InvestorRevoked,
  InvestorFrozen,
} from "../generated/ComplianceRegistry/ComplianceRegistry";
import {
  AssetRegistered,
  AssetUpdated,
  AssetStatusChanged,
} from "../generated/AssetRegistry/AssetRegistry";
import { Transfer, Investor, Asset, GlobalStat } from "../generated/schema";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const GLOBAL_ID = "global";

function getGlobalStat(): GlobalStat {
  let stat = GlobalStat.load(GLOBAL_ID);
  if (stat == null) {
    stat = new GlobalStat(GLOBAL_ID);
    stat.totalTransfers = BigInt.zero();
    stat.totalMinted = BigInt.zero();
    stat.totalBurned = BigInt.zero();
    stat.holderCount = 0;
    stat.investorCount = 0;
  }
  return stat;
}

function getOrCreateInvestor(address: Bytes): Investor {
  let investor = Investor.load(address.toHexString());
  if (investor == null) {
    investor = new Investor(address.toHexString());
    investor.verified = false;
    investor.expiry = BigInt.zero();
    investor.jurisdiction = BigInt.zero();
    investor.frozen = false;
    investor.balance = BigInt.zero();
  }
  return investor;
}

// ── RWAToken ──────────────────────────────────────────────────────────────

export function handleTransfer(event: TransferEvent): void {
  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let transfer = new Transfer(id);
  transfer.from = event.params.from;
  transfer.to = event.params.to;
  transfer.value = event.params.value;
  transfer.blockNumber = event.block.number;
  transfer.blockTimestamp = event.block.timestamp;
  transfer.txHash = event.transaction.hash;
  transfer.save();

  let stat = getGlobalStat();
  stat.totalTransfers = stat.totalTransfers.plus(BigInt.fromI32(1));

  // Sender side. Mint legs (from = 0x0) only create value.
  if (event.params.from.toHexString() != ZERO_ADDRESS) {
    let sender = getOrCreateInvestor(event.params.from);
    let before = sender.balance;
    // Defensive clamp: history can be incomplete if indexing started late.
    let after = before.minus(event.params.value);
    sender.balance = after.lt(BigInt.zero()) ? BigInt.zero() : after;
    if (before.gt(BigInt.zero()) && sender.balance.equals(BigInt.zero())) {
      stat.holderCount = stat.holderCount - 1;
    }
    sender.save();
  }

  // Receiver side. Burn legs (to = 0x0) only destroy value.
  if (event.params.to.toHexString() != ZERO_ADDRESS) {
    let receiver = getOrCreateInvestor(event.params.to);
    let before = receiver.balance;
    receiver.balance = before.plus(event.params.value);
    if (before.equals(BigInt.zero())) {
      stat.holderCount = stat.holderCount + 1;
    }
    receiver.save();
  }

  stat.save();
}

export function handleAssetMinted(event: AssetMinted): void {
  // The recipient's balance is updated by the Transfer event that
  // ERC-20._mint emits alongside AssetMinted; here we only count.
  let stat = getGlobalStat();
  stat.totalMinted = stat.totalMinted.plus(event.params.amount);
  stat.save();
}

export function handleAssetBurned(event: AssetBurned): void {
  // The sender's balance is updated by the Transfer event that
  // ERC-20._burn emits alongside AssetBurned; here we only count.
  let stat = getGlobalStat();
  stat.totalBurned = stat.totalBurned.plus(event.params.amount);
  stat.save();
}

// ── ComplianceRegistry ────────────────────────────────────────────────────

export function handleInvestorVerified(event: InvestorVerified): void {
  let investor = getOrCreateInvestor(event.params.investor);
  let wasVerified = investor.verified;
  // verify() overwrites the whole record on-chain, including frozen=false.
  investor.verified = true;
  investor.expiry = event.params.expiry;
  investor.jurisdiction = BigInt.fromI32(event.params.jurisdiction);
  investor.frozen = false;
  investor.save();

  if (!wasVerified) {
    let stat = getGlobalStat();
    stat.investorCount = stat.investorCount + 1;
    stat.save();
  }
}

export function handleInvestorRevoked(event: InvestorRevoked): void {
  let investor = getOrCreateInvestor(event.params.investor);
  let wasVerified = investor.verified;
  // revoke() clears verified/expiry/jurisdiction but leaves frozen alone.
  investor.verified = false;
  investor.save();

  if (wasVerified) {
    let stat = getGlobalStat();
    stat.investorCount = stat.investorCount - 1;
    stat.save();
  }
}

export function handleInvestorFrozen(event: InvestorFrozen): void {
  let investor = getOrCreateInvestor(event.params.investor);
  investor.frozen = event.params.frozen;
  investor.save();
}

// ── AssetRegistry ─────────────────────────────────────────────────────────

export function handleAssetRegistered(event: AssetRegistered): void {
  let asset = new Asset(event.params.assetId.toString());
  asset.docHash = event.params.docHash;
  // AssetRegistered does not carry the uri — the first AssetUpdated does.
  asset.uri = "";
  asset.issuer = event.params.issuer;
  asset.status = 0; // AssetStatus.Active
  asset.registeredAt = event.block.timestamp;
  asset.save();
}

export function handleAssetUpdated(event: AssetUpdated): void {
  let asset = Asset.load(event.params.assetId.toString());
  if (asset == null) {
    // Defensive: create the record if an update ever indexes before its register.
    asset = new Asset(event.params.assetId.toString());
    asset.registeredAt = event.block.timestamp;
  }
  asset.docHash = event.params.docHash;
  asset.uri = event.params.uri;
  // valuation / valuationAt are readable on-chain but not part of the schema.
  asset.save();
}

export function handleAssetStatusChanged(event: AssetStatusChanged): void {
  let asset = Asset.load(event.params.assetId.toString());
  if (asset == null) {
    return;
  }
  asset.status = event.params.status;
  asset.save();
}
