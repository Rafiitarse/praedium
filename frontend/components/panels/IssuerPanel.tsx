'use client';

import { useState } from 'react';
import {
  useChainId,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from 'wagmi';
import { isAddress, parseUnits } from 'viem';
import { getContracts, isDeployed } from '@/lib/contracts';
import { RWA_TOKEN_ABI } from '@/lib/abis';
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

export function IssuerPanel() {
  const chainId = useChainId();
  const contracts = getContracts(chainId);
  const deployed = isDeployed(chainId);

  const [mintTo, setMintTo] = useState('');
  const [mintAmount, setMintAmount] = useState('');
  const [burnFrom, setBurnFrom] = useState('');
  const [burnAmount, setBurnAmount] = useState('');

  const { data: rawPaused } = useReadContract({
    address: contracts?.rwaToken,
    abi: RWA_TOKEN_ABI,
    functionName: 'paused',
    query: { enabled: !!deployed },
  });
  const paused = rawPaused as boolean | undefined;

  const { writeContract, data: txHash, isPending, error, reset } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  const busy = isPending || confirming;
  const txState = busy ? 'pending' : isSuccess ? 'success' : error ? 'error' : 'idle';

  function mint() {
    if (!contracts || !mintTo || !mintAmount) return;
    writeContract({
      address: contracts.rwaToken,
      abi: RWA_TOKEN_ABI,
      functionName: 'mint',
      args: [mintTo, parseUnits(mintAmount, 18)],
    });
  }

  function burn() {
    if (!contracts || !burnFrom || !burnAmount) return;
    writeContract({
      address: contracts.rwaToken,
      abi: RWA_TOKEN_ABI,
      functionName: 'burn',
      args: [burnFrom, parseUnits(burnAmount, 18)],
    });
  }

  function togglePause() {
    if (!contracts) return;
    writeContract({
      address: contracts.rwaToken,
      abi: RWA_TOKEN_ABI,
      functionName: paused ? 'unpause' : 'pause',
    });
  }

  if (!deployed) return <NotDeployed />;

  return (
    <div className="space-y-6">
      <PanelCard>
        <div className="flex items-center justify-between">
          <h3 className="font-semibold">Token state</h3>
          {paused ? <Badge tone="warning">Paused</Badge> : <Badge tone="success">Active</Badge>}
        </div>
        <p className="mt-2 text-sm text-slate-400">
          While paused, every transfer, mint and burn reverts. Compliance checks still apply
          on unpause.
        </p>
        <div className="mt-4">
          <Button variant={paused ? 'primary' : 'danger'} onClick={togglePause} disabled={busy}>
            {busy ? <Spinner /> : paused ? 'Unpause transfers' : 'Pause transfers'}
          </Button>
        </div>
      </PanelCard>

      <PanelCard>
        <h3 className="font-semibold">Mint</h3>
        <div className="mt-4 space-y-3">
          <Field label="Recipient address">
            <TextInput value={mintTo} onChange={(e) => setMintTo(e.target.value)} placeholder="0x…" />
          </Field>
          <Field label="Amount">
            <TextInput
              value={mintAmount}
              onChange={(e) => setMintAmount(e.target.value)}
              placeholder="0.0"
              type="number"
              min="0"
            />
          </Field>
          <Button
            onClick={() => {
              reset();
              mint();
            }}
            disabled={!isAddress(mintTo) || !mintAmount || busy}
          >
            {busy ? <Spinner /> : 'Mint'}
          </Button>
        </div>
      </PanelCard>

      <PanelCard>
        <h3 className="font-semibold">Burn</h3>
        <div className="mt-4 space-y-3">
          <Field label="Holder address">
            <TextInput value={burnFrom} onChange={(e) => setBurnFrom(e.target.value)} placeholder="0x…" />
          </Field>
          <Field label="Amount">
            <TextInput
              value={burnAmount}
              onChange={(e) => setBurnAmount(e.target.value)}
              placeholder="0.0"
              type="number"
              min="0"
            />
          </Field>
          <Button
            variant="danger"
            onClick={() => {
              reset();
              burn();
            }}
            disabled={!isAddress(burnFrom) || !burnAmount || busy}
          >
            {busy ? <Spinner /> : 'Burn'}
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
