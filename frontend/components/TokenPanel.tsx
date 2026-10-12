'use client';

import { useState } from 'react';
import {
  useAccount,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
  useChainId,
} from 'wagmi';
import { parseUnits, formatUnits } from 'viem';
import { SEPOLIA_CHAIN_ID, getContracts } from '@/lib/contracts';
import { RWA_TOKEN_ABI, COMPLIANCE_REGISTRY_ABI } from '@/lib/abis';

type Eligibility = { ok: boolean; reason: string };

export function TokenPanel() {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const contracts = getContracts(chainId);
  const [recipient, setRecipient] = useState('');
  const [amount, setAmount] = useState('');

  const onSepolia = chainId === SEPOLIA_CHAIN_ID;
  const deployed = onSepolia && contracts && contracts.rwaToken !== '0x0000000000000000000000000000000000000000';

  // ── reads ────────────────────────────────────────────────────────────
  const { data: balance } = useReadContract({
    address: contracts?.rwaToken,
    abi: RWA_TOKEN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!deployed && !!address },
  });

  const { data: totalSupply } = useReadContract({
    address: contracts?.rwaToken,
    abi: RWA_TOKEN_ABI,
    functionName: 'totalSupply',
    query: { enabled: !!deployed },
  });

  const { data: paused } = useReadContract({
    address: contracts?.rwaToken,
    abi: RWA_TOKEN_ABI,
    functionName: 'paused',
    query: { enabled: !!deployed },
  });

  const { data: eligibility } = useReadContract({
    address: contracts?.complianceRegistry,
    abi: COMPLIANCE_REGISTRY_ABI,
    functionName: 'isVerified',
    args: address ? [address] : undefined,
    query: { enabled: !!deployed && !!address },
  }) as { data: Eligibility | undefined };

  // Pre-flight: would this exact transfer be allowed? Always ask the registry —
  // never recompute eligibility locally.
  const { data: transferAllowed } = useReadContract({
    address: contracts?.complianceRegistry,
    abi: COMPLIANCE_REGISTRY_ABI,
    functionName: 'isTransferAllowed',
    args: address && recipient ? [address, recipient as `0x${string}`] : undefined,
    query: { enabled: !!deployed && !!address && !!recipient },
  }) as { data: boolean | undefined };

  // ── write ────────────────────────────────────────────────────────────
  const { writeContract, data: txHash, isPending, error } = useWriteContract();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  function submit() {
    if (!contracts || !recipient || !amount) return;
    writeContract({
      address: contracts.rwaToken,
      abi: RWA_TOKEN_ABI,
      functionName: 'transfer',
      args: [recipient as `0x${string}`, parseUnits(amount, 18)],
    });
  }

  // ── render ───────────────────────────────────────────────────────────
  if (!isConnected) {
    return (
      <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-8 text-center text-slate-400">
        Connect a wallet to view your position.
      </div>
    );
  }

  if (!onSepolia) {
    return (
      <div className="rounded-xl border border-amber-800/60 bg-amber-950/30 p-8 text-center text-amber-300">
        Wrong network — switch to Sepolia to interact with the deployed contracts.
      </div>
    );
  }

  if (!deployed) {
    return (
      <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-8 text-center text-slate-400">
        Contracts not deployed yet on Sepolia.
        <br />
        <span className="text-sm">
          Run <code className="rounded bg-slate-800 px-1">script/DeployAll.s.sol</code>, then set{' '}
          <code className="rounded bg-slate-800 px-1">NEXT_PUBLIC_RWA_TOKEN_ADDRESS_SEPOLIA</code>.
        </span>
      </div>
    );
  }

  const fmt = (v: bigint | undefined) => (v === undefined ? '—' : Number(formatUnits(v, 18)).toLocaleString());

  return (
    <div className="space-y-6">
      {/* position */}
      <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-6">
        <div className="flex items-center justify-between">
          <h3 className="font-semibold">Your position</h3>
          <div className="flex gap-2">
            <span
              className={`rounded-full px-3 py-1 text-xs font-semibold ${
                eligibility?.ok ? 'bg-emerald-500/15 text-emerald-400' : 'bg-rose-500/15 text-rose-400'
              }`}
            >
              {eligibility?.ok ? 'Whitelisted' : 'Not whitelisted'}
            </span>
            {paused ? (
              <span className="rounded-full bg-rose-500/15 px-3 py-1 text-xs font-semibold text-rose-400">
                Paused
              </span>
            ) : null}
          </div>
        </div>
        <div className="mt-4 grid grid-cols-2 gap-4">
          <div>
            <p className="text-sm text-slate-400">Your balance</p>
            <p className="text-2xl font-bold">{fmt(balance as bigint | undefined)} RWA</p>
          </div>
          <div>
            <p className="text-sm text-slate-400">Total supply</p>
            <p className="text-2xl font-bold">{fmt(totalSupply as bigint | undefined)} RWA</p>
          </div>
        </div>
        {!eligibility?.ok ? (
          <p className="mt-4 rounded-lg bg-slate-800/60 p-3 text-sm text-slate-400">
            Your address is not compliance-eligible. Transfers to or from it will revert
            (<code className="text-rose-400">TransferNotAllowed</code>). Contact the compliance officer.
          </p>
        ) : null}
      </div>

      {/* transfer */}
      <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-6">
        <h3 className="font-semibold">Transfer</h3>
        <div className="mt-4 space-y-3">
          <input
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
            placeholder="Recipient address (0x…)"
            className="w-full rounded-lg border border-slate-700 bg-slate-950 px-4 py-2.5 font-mono text-sm outline-none focus:border-emerald-500"
          />
          <input
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="Amount"
            type="number"
            className="w-full rounded-lg border border-slate-700 bg-slate-950 px-4 py-2.5 text-sm outline-none focus:border-emerald-500"
          />
          {recipient && transferAllowed === false ? (
            <p className="rounded-lg bg-rose-500/10 p-3 text-sm text-rose-400">
              Registry says this transfer is not allowed (recipient not eligible). The transaction would revert.
            </p>
          ) : null}
          <button
            onClick={submit}
            disabled={isPending || confirming || !recipient || !amount || transferAllowed === false}
            className="w-full rounded-lg bg-emerald-500 py-2.5 font-semibold text-slate-950 transition hover:bg-emerald-400 disabled:opacity-40"
          >
            {isPending ? 'Signing…' : confirming ? 'Confirming…' : isSuccess ? 'Sent ✓' : 'Transfer'}
          </button>
          {error ? (
            <p className="text-sm text-rose-400">{(error as { shortMessage?: string }).shortMessage ?? 'Transaction failed'}</p>
          ) : null}
          {txHash ? (
            <p className="truncate font-mono text-xs text-slate-500">
              tx: {txHash}
            </p>
          ) : null}
        </div>
      </div>
    </div>
  );
}
