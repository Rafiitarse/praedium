'use client';

import { useState } from 'react';
import {
  useChainId,
  useWriteContract,
  useWaitForTransactionReceipt,
} from 'wagmi';
import { isAddress, parseUnits } from 'viem';
import { getContracts, isDeployed } from '@/lib/contracts';
import { ASSET_REGISTRY_ABI } from '@/lib/abis';
import {
  Button,
  Field,
  NotDeployed,
  PanelCard,
  Select,
  Spinner,
  TextInput,
  TxStatus,
} from '@/components/ui';

const STATUS_OPTIONS = [
  { value: '0', label: 'Active' },
  { value: '1', label: 'Frozen' },
  { value: '2', label: 'Redeemed' },
];

function nowLocal() {
  const d = new Date();
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function toUnix(local: string) {
  return Math.floor(new Date(local).getTime() / 1000);
}

const DOC_HASH_RE = /^0x[0-9a-fA-F]{64}$/;

export function AssetPanel() {
  const chainId = useChainId();
  const contracts = getContracts(chainId);
  const deployed = isDeployed(chainId);

  const [docHash, setDocHash] = useState('');
  const [uri, setUri] = useState('');
  const [issuer, setIssuer] = useState('');
  const [valuation, setValuation] = useState('');
  const [valuationAt, setValuationAt] = useState(nowLocal());

  const [updateId, setUpdateId] = useState('');
  const [updateDocHash, setUpdateDocHash] = useState('');
  const [updateUri, setUpdateUri] = useState('');
  const [updateValuation, setUpdateValuation] = useState('');
  const [updateValuationAt, setUpdateValuationAt] = useState(nowLocal());

  const [statusId, setStatusId] = useState('');
  const [status, setStatus] = useState('0');

  const { writeContract, data: txHash, isPending, error, reset } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  const busy = isPending || confirming;
  const txState = busy ? 'pending' : isSuccess ? 'success' : error ? 'error' : 'idle';

  function register() {
    if (!contracts) return;
    writeContract({
      address: contracts.assetRegistry,
      abi: ASSET_REGISTRY_ABI,
      functionName: 'registerAsset',
      args: [
        docHash,
        uri,
        issuer,
        valuation ? parseUnits(valuation, 2) : 0n,
        BigInt(toUnix(valuationAt)),
      ],
    });
  }

  function update() {
    if (!contracts) return;
    writeContract({
      address: contracts.assetRegistry,
      abi: ASSET_REGISTRY_ABI,
      functionName: 'updateAsset',
      args: [
        BigInt(updateId),
        updateDocHash,
        updateUri,
        updateValuation ? parseUnits(updateValuation, 2) : 0n,
        BigInt(toUnix(updateValuationAt)),
      ],
    });
  }

  function setAssetStatus() {
    if (!contracts) return;
    writeContract({
      address: contracts.assetRegistry,
      abi: ASSET_REGISTRY_ABI,
      functionName: 'setStatus',
      args: [BigInt(statusId), Number(status)],
    });
  }

  if (!deployed) return <NotDeployed />;

  return (
    <div className="space-y-6">
      <PanelCard>
        <h3 className="font-semibold">Register asset</h3>
        <div className="mt-4 space-y-3">
          <Field label="Document hash" hint="keccak256 of the off-chain legal documents (0x + 64 hex)">
            <TextInput
              value={docHash}
              onChange={(e) => setDocHash(e.target.value)}
              placeholder="0x…"
            />
          </Field>
          <Field label="Metadata URI" hint="e.g. ipfs://…">
            <TextInput value={uri} onChange={(e) => setUri(e.target.value)} placeholder="ipfs://…" />
          </Field>
          <Field label="Issuer address">
            <TextInput
              value={issuer}
              onChange={(e) => setIssuer(e.target.value)}
              placeholder="0x…"
            />
          </Field>
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Valuation (USD)">
              <TextInput
                value={valuation}
                onChange={(e) => setValuation(e.target.value)}
                placeholder="0.00"
                type="number"
                min="0"
                step="0.01"
              />
            </Field>
            <Field label="Valuation date">
              <TextInput
                value={valuationAt}
                onChange={(e) => setValuationAt(e.target.value)}
                type="datetime-local"
              />
            </Field>
          </div>
          <Button
            onClick={() => {
              reset();
              register();
            }}
            disabled={!DOC_HASH_RE.test(docHash) || !uri || !isAddress(issuer) || busy}
          >
            {busy ? <Spinner /> : 'Register'}
          </Button>
        </div>
      </PanelCard>

      <PanelCard>
        <h3 className="font-semibold">Update asset</h3>
        <p className="mt-1 text-sm text-slate-400">
          Full overwrite — resubmit every field you want to keep.
        </p>
        <div className="mt-4 space-y-3">
          <Field label="Asset ID">
            <TextInput
              value={updateId}
              onChange={(e) => setUpdateId(e.target.value)}
              placeholder="1"
              type="number"
              min="1"
            />
          </Field>
          <Field label="Document hash">
            <TextInput
              value={updateDocHash}
              onChange={(e) => setUpdateDocHash(e.target.value)}
              placeholder="0x…"
            />
          </Field>
          <Field label="Metadata URI">
            <TextInput
              value={updateUri}
              onChange={(e) => setUpdateUri(e.target.value)}
              placeholder="ipfs://…"
            />
          </Field>
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Valuation (USD)">
              <TextInput
                value={updateValuation}
                onChange={(e) => setUpdateValuation(e.target.value)}
                placeholder="0.00"
                type="number"
                min="0"
                step="0.01"
              />
            </Field>
            <Field label="Valuation date">
              <TextInput
                value={updateValuationAt}
                onChange={(e) => setUpdateValuationAt(e.target.value)}
                type="datetime-local"
              />
            </Field>
          </div>
          <Button
            variant="secondary"
            onClick={() => {
              reset();
              update();
            }}
            disabled={
              !updateId ||
              !DOC_HASH_RE.test(updateDocHash) ||
              !updateUri ||
              busy
            }
          >
            {busy ? <Spinner /> : 'Update'}
          </Button>
        </div>
      </PanelCard>

      <PanelCard>
        <h3 className="font-semibold">Set status</h3>
        <p className="mt-1 text-sm text-slate-400">
          Informational only — status changes do not halt transfers. Use the token pause for
          that.
        </p>
        <div className="mt-4 space-y-3">
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Asset ID">
              <TextInput
                value={statusId}
                onChange={(e) => setStatusId(e.target.value)}
                placeholder="1"
                type="number"
                min="1"
              />
            </Field>
            <Field label="Status">
              <Select value={status} onChange={(e) => setStatus(e.target.value)}>
                {STATUS_OPTIONS.map((o) => (
                  <option key={o.value} value={o.value}>
                    {o.label}
                  </option>
                ))}
              </Select>
            </Field>
          </div>
          <Button
            variant="secondary"
            onClick={() => {
              reset();
              setAssetStatus();
            }}
            disabled={!statusId || busy}
          >
            {busy ? <Spinner /> : 'Set status'}
          </Button>
        </div>
      </PanelCard>

      <TxStatus
        state={txState}
        hash={txHash}
        error={(error as { shortMessage?: string })?.shortMessage}
      />
    </div>
  );
}
