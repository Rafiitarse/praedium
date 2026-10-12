'use client';

import { useState } from 'react';
import {
  useAccount,
  useChainId,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from 'wagmi';
import { formatUnits, isAddress, parseUnits } from 'viem';
import { getContracts, isDeployed } from '@/lib/contracts';
import { RWA_TOKEN_ABI, COMPLIANCE_REGISTRY_ABI } from '@/lib/abis';
import {
  Badge,
  Button,
  Field,
  NotDeployed,
  PanelCard,
  Skeleton,
  Spinner,
  StatCard,
  TextInput,
  TxStatus,
} from '@/components/ui';

export function InvestorPanel() {
  const { address } = useAccount();
  const chainId = useChainId();
  const contracts = getContracts(chainId);
  const deployed = isDeployed(chainId);

  const [recipient, setRecipient] = useState('');
  const [amount, setAmount] = useState('');

  const { data: rawBalance, isLoading: balanceLoading } = useReadContract({
    address: contracts?.rwaToken,
    abi: RWA_TOKEN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!deployed && !!address },
  });
  const balance = rawBalance as bigint | undefined;

  const { data: rawTotalSupply } = useReadContract({
    address: contracts?.rwaToken,
    abi: RWA_TOKEN_ABI,
    functionName: 'totalSupply',
    query: { enabled: !!deployed },
  });
  const totalSupply = rawTotalSupply as bigint | undefined;

  const { data: rawStatus } = useReadContract({
    address: contracts?.complianceRegistry,
    abi: COMPLIANCE_REGISTRY_ABI,
    functionName: 'investorStatus',
    args: address ? [address] : undefined,
    query: { enabled: !!deployed && !!address },
  });
  // investorStatus returns the packed struct: [verified, expiry, jurisdiction, frozen]
  const status = rawStatus as readonly [boolean, bigint, number, boolean] | undefined;

  const validRecipient = isAddress(recipient);

  const { data: rawAllowed } = useReadContract({
    address: contracts?.complianceRegistry,
    abi: COMPLIANCE_REGISTRY_ABI,
    functionName: 'isTransferAllowed',
    args: address && validRecipient ? [address, recipient] : undefined,
    query: { enabled: !!deployed && !!address && validRecipient },
  });
  const transferAllowed = rawAllowed as boolean | undefined;

  const { writeContract, data: txHash, isPending, error, reset } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  const txState = isPending || confirming ? 'pending' : isSuccess ? 'success' : error ? 'error' : 'idle';

  function submit() {
    if (!contracts || !recipient || !amount) return;
    writeContract({
      address: contracts.rwaToken,
      abi: RWA_TOKEN_ABI,
      functionName: 'transfer',
      args: [recipient, parseUnits(amount, 18)],
    });
  }

  if (!deployed) return <NotDeployed />;

  const verified = status ? status[0] : false;
  const expiry = status ? status[1] : 0n;
  const frozen = status ? status[3] : false;
  const expired = expiry !== 0n && expiry <= BigInt(Math.floor(Date.now() / 1000));
  const eligible = !!verified && !frozen && !expired;

  return (
    <div className="space-y-6">
      <div className="grid gap-4 sm:grid-cols-2">
        <StatCard
          label="Your balance"
          value={balanceLoading ? '—' : formatUnits(balance ?? 0n, 18)}
          suffix="RWA"
        />
        <StatCard label="Total supply" value={formatUnits(totalSupply ?? 0n, 18)} suffix="RWA" />
      </div>

      <PanelCard>
        <div className="flex items-center justify-between">
          <h3 className="font-semibold">Compliance status</h3>
          <div className="flex gap-2">
            {frozen ? <Badge tone="error">Frozen</Badge> : null}
            {eligible ? (
              <Badge tone="success">Eligible</Badge>
            ) : frozen ? null : verified ? (
              <Badge tone="warning">Expired</Badge>
            ) : (
              <Badge tone="error">Not verified</Badge>
            )}
          </div>
        </div>
        <p className="mt-2 text-sm text-slate-400">
          {verified
            ? expiry === 0n
              ? 'Verification never expires.'
              : `Verification expires ${new Date(Number(expiry) * 1000).toLocaleDateString()}.`
            : 'This address cannot transact until a compliance officer verifies it.'}
        </p>
      </PanelCard>

      <PanelCard>
        <h3 className="font-semibold">Transfer</h3>
        <div className="mt-4 space-y-3">
          <Field label="Recipient address">
            <TextInput
              value={recipient}
              onChange={(e) => {
                setRecipient(e.target.value);
                reset();
              }}
              placeholder="0x…"
            />
          </Field>
          <Field label="Amount">
            <TextInput
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.0"
              type="number"
              min="0"
            />
          </Field>
          {validRecipient && transferAllowed === false ? (
            <p className="rounded-lg bg-rose-500/10 p-3 text-sm text-rose-400">
              The registry does not allow this transfer — the transaction would revert.
            </p>
          ) : null}
          <Button
            onClick={submit}
            disabled={!validRecipient || !amount || transferAllowed === false || txState === 'pending'}
          >
            {txState === 'pending' ? (
              <>
                <Spinner /> Sending…
              </>
            ) : (
              'Transfer'
            )}
          </Button>
          <TxStatus
            state={txState}
            hash={txHash}
            error={(error as { shortMessage?: string })?.shortMessage}
          />
        </div>
      </PanelCard>
    </div>
  );
}
