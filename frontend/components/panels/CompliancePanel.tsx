'use client';

import { useState } from 'react';
import {
  useChainId,
  useWriteContract,
  useWaitForTransactionReceipt,
} from 'wagmi';
import { isAddress } from 'viem';
import { getContracts, isDeployed } from '@/lib/contracts';
import { COMPLIANCE_REGISTRY_ABI } from '@/lib/abis';
import {
  Badge,
  Button,
  Field,
  NotDeployed,
  PanelCard,
  Spinner,
  TextInput,
  TxStatus,
} from '@/components/ui';

const NEVER = 'never';

export function CompliancePanel() {
  const chainId = useChainId();
  const contracts = getContracts(chainId);
  const deployed = isDeployed(chainId);

  const [verifyAddress, setVerifyAddress] = useState('');
  const [expiry, setExpiry] = useState('');
  const [jurisdiction, setJurisdiction] = useState('');
  const [revokeAddress, setRevokeAddress] = useState('');
  const [freezeAddress, setFreezeAddress] = useState('');

  const { writeContract, data: txHash, isPending, error, reset } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  const busy = isPending || confirming;
  const txState = busy ? 'pending' : isSuccess ? 'success' : error ? 'error' : 'idle';

  function verify() {
    if (!contracts || !verifyAddress) return;
    const expiryUnix =
      expiry === NEVER ? 0 : Math.floor(new Date(expiry).getTime() / 1000);
    writeContract({
      address: contracts.complianceRegistry,
      abi: COMPLIANCE_REGISTRY_ABI,
      functionName: 'verify',
      args: [verifyAddress, BigInt(expiryUnix), Number(jurisdiction || 0)],
    });
  }

  function revoke() {
    if (!contracts || !revokeAddress) return;
    writeContract({
      address: contracts.complianceRegistry,
      abi: COMPLIANCE_REGISTRY_ABI,
      functionName: 'revoke',
      args: [revokeAddress],
    });
  }

  function setFrozen(frozen: boolean) {
    if (!contracts || !freezeAddress) return;
    writeContract({
      address: contracts.complianceRegistry,
      abi: COMPLIANCE_REGISTRY_ABI,
      functionName: 'setFrozen',
      args: [freezeAddress, frozen],
    });
  }

  if (!deployed) return <NotDeployed />;

  return (
    <div className="space-y-6">
      <PanelCard>
        <h3 className="font-semibold">Verify investor</h3>
        <p className="mt-1 text-sm text-slate-400">
          Grants eligibility to transact. Re-verifying resets the frozen flag — use freeze
          separately for legal holds.
        </p>
        <div className="mt-4 space-y-3">
          <Field label="Investor address">
            <TextInput
              value={verifyAddress}
              onChange={(e) => setVerifyAddress(e.target.value)}
              placeholder="0x…"
            />
          </Field>
          <div className="grid gap-3 sm:grid-cols-2">
            <Field label="Expiry">
              <TextInput
                value={expiry}
                onChange={(e) => setExpiry(e.target.value)}
                placeholder="YYYY-MM-DD or 'never'"
              />
            </Field>
            <Field label="Jurisdiction code" hint="ISO 3166-1 numeric, e.g. 360 for Indonesia">
              <TextInput
                value={jurisdiction}
                onChange={(e) => setJurisdiction(e.target.value)}
                placeholder="360"
                type="number"
              />
            </Field>
          </div>
          <Button
            onClick={() => {
              reset();
              verify();
            }}
            disabled={!isAddress(verifyAddress) || !expiry || busy}
          >
            {busy ? <Spinner /> : 'Verify'}
          </Button>
        </div>
      </PanelCard>

      <PanelCard>
        <h3 className="font-semibold">Revoke verification</h3>
        <div className="mt-4 space-y-3">
          <Field label="Investor address">
            <TextInput
              value={revokeAddress}
              onChange={(e) => setRevokeAddress(e.target.value)}
              placeholder="0x…"
            />
          </Field>
          <Button
            variant="secondary"
            onClick={() => {
              reset();
              revoke();
            }}
            disabled={!isAddress(revokeAddress) || busy}
          >
            {busy ? <Spinner /> : 'Revoke'}
          </Button>
        </div>
      </PanelCard>

      <PanelCard>
        <div className="flex items-center gap-2">
          <h3 className="font-semibold">Freeze / unfreeze</h3>
          <Badge tone="warning">Legal hold</Badge>
        </div>
        <p className="mt-1 text-sm text-slate-400">
          Frozen holders keep their balance but can neither send nor receive until unfrozen.
        </p>
        <div className="mt-4 space-y-3">
          <Field label="Investor address">
            <TextInput
              value={freezeAddress}
              onChange={(e) => setFreezeAddress(e.target.value)}
              placeholder="0x…"
            />
          </Field>
          <div className="flex gap-3">
            <Button
              variant="danger"
              onClick={() => {
                reset();
                setFrozen(true);
              }}
              disabled={!isAddress(freezeAddress) || busy}
            >
              {busy ? <Spinner /> : 'Freeze'}
            </Button>
            <Button
              onClick={() => {
                reset();
                setFrozen(false);
              }}
              disabled={!isAddress(freezeAddress) || busy}
            >
              {busy ? <Spinner /> : 'Unfreeze'}
            </Button>
          </div>
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
