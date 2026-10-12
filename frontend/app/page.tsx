'use client';

import { useAccount } from 'wagmi';
import { WalletButton } from '@/components/WalletButton';
import { ContactFooter } from '@/components/ContactFooter';
import { PanelCard } from '@/components/ui';

export default function Home() {
  const { isConnected } = useAccount();

  return (
    <div className="app-bg flex min-h-screen flex-col">
      <header className="sticky top-0 z-20 border-b border-white/[0.06] bg-[#05070d]/80 backdrop-blur-xl">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
          <div className="flex items-center gap-3">
            <div className="h-8 w-8 rounded-lg bg-gradient-to-br from-emerald-400 to-cyan-400 shadow-glow" />
            <span className="text-lg font-semibold tracking-tight">Praedium</span>
          </div>
          <WalletButton />
        </div>
      </header>

      <main className="mx-auto w-full max-w-6xl flex-1 px-6 py-10">
        {!isConnected ? (
          <PanelCard className="animate-fade-up mx-auto max-w-xl py-16 text-center">
            <div className="mx-auto h-12 w-12 rounded-xl bg-gradient-to-br from-emerald-400 to-cyan-400 shadow-glow-lg" />
            <h1 className="mt-6 text-2xl font-bold">Praedium</h1>
            <p className="mt-2 text-slate-400">
              Connect your wallet to interact with the RWA contracts.
            </p>
          </PanelCard>
        ) : null}
      </main>

      <ContactFooter />
    </div>
  );
}
