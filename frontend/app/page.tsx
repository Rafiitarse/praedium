'use client';

import { useState } from 'react';
import { useAccount, useChainId } from 'wagmi';
import { WalletButton } from '@/components/WalletButton';
import { ContactFooter } from '@/components/ContactFooter';
import { InvestorPanel } from '@/components/panels/InvestorPanel';
import { IssuerPanel } from '@/components/panels/IssuerPanel';
import { CompliancePanel } from '@/components/panels/CompliancePanel';
import { AssetPanel } from '@/components/panels/AssetPanel';
import { useRoles } from '@/lib/useRoles';
import { isDeployed } from '@/lib/contracts';
import { PanelCard } from '@/components/ui';

type TabId = 'investor' | 'issuer' | 'compliance' | 'assets';

export default function Home() {
  const { isConnected } = useAccount();
  const chainId = useChainId();
  const deployed = isDeployed(chainId);
  const roles = useRoles();
  const [tab, setTab] = useState<TabId>('investor');

  const tabs: { id: TabId; label: string; visible: boolean }[] = [
    { id: 'investor', label: 'Investor', visible: true },
    { id: 'issuer', label: 'Issuer', visible: roles.isMinter || roles.isPauser },
    { id: 'compliance', label: 'Compliance', visible: roles.isOfficer },
    { id: 'assets', label: 'Assets', visible: roles.isAssetAdmin },
  ];
  const visibleTabs = tabs.filter((t) => t.visible);
  const activeTab: TabId = visibleTabs.some((t) => t.id === tab) ? tab : 'investor';

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
        ) : !deployed ? (
          <PanelCard className="animate-fade-up py-12 text-center">
            <p className="text-slate-400">
              Contracts are not deployed on this network. Switch to Sepolia where the
              deployment lives.
            </p>
          </PanelCard>
        ) : (
          <div className="animate-fade-up space-y-6">
            <nav className="flex flex-wrap gap-2" aria-label="Contract panels">
              {visibleTabs.map((t) => (
                <button
                  key={t.id}
                  onClick={() => setTab(t.id)}
                  aria-current={activeTab === t.id}
                  className={`rounded-xl px-4 py-2 text-sm font-medium transition-all duration-200 ${
                    activeTab === t.id
                      ? 'bg-gradient-to-r from-emerald-400/20 to-cyan-400/20 text-emerald-300 shadow-glow'
                      : 'border border-white/[0.06] bg-white/[0.02] text-slate-400 hover:bg-white/[0.05] hover:text-slate-200'
                  }`}
                >
                  {t.label}
                </button>
              ))}
            </nav>

            {activeTab === 'investor' ? <InvestorPanel /> : null}
            {activeTab === 'issuer' ? <IssuerPanel /> : null}
            {activeTab === 'compliance' ? <CompliancePanel /> : null}
            {activeTab === 'assets' ? <AssetPanel /> : null}
          </div>
        )}
      </main>

      <ContactFooter />
    </div>
  );
}
