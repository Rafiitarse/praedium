'use client';

import { useState } from 'react';
import { useAccount, useChainId } from 'wagmi';
import { WalletButton } from '@/components/WalletButton';
import { ContactFooter } from '@/components/ContactFooter';
import { InvestorPanel } from '@/components/panels/InvestorPanel';
import { IssuerPanel } from '@/components/panels/IssuerPanel';
import { CompliancePanel } from '@/components/panels/CompliancePanel';
import { AssetPanel } from '@/components/panels/AssetPanel';
import { GlobalStats } from '@/components/GlobalStats';
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
      <header className="sticky top-0 z-20 border-b border-white/[0.08] bg-[#101814]/85 backdrop-blur-xl">
        <div className="mx-auto flex w-full max-w-[1320px] items-center justify-between px-5 py-4 sm:px-8">
          <a href="#home" className="flex items-center gap-3" aria-label="Praedium home">
            <span className="flex size-10 items-center justify-center rounded-xl border border-[#c9a978]/30 bg-[#c9a978]/10 font-serif text-lg text-[#e4c99e]">P</span>
            <span>
              <span className="block text-[15px] font-semibold tracking-[0.12em] text-[#f4f0e8]">PRAEDIUM</span>
              <span className="block text-[10px] uppercase tracking-[0.2em] text-[#a8a99e]">Real asset platform</span>
            </span>
          </a>
          <div className="flex items-center gap-3">
            <span className="hidden items-center gap-2 rounded-full border border-white/[0.09] bg-white/[0.04] px-3 py-2 text-xs text-[#b8b9af] sm:flex">
              <span className={`size-1.5 rounded-full ${deployed ? 'bg-[#9bb69a]' : 'bg-[#c9a978]'}`} />
              {deployed ? 'Sepolia network' : 'Network not ready'}
            </span>
            <WalletButton />
          </div>
        </div>
      </header>

      <main id="home" className="mx-auto w-full max-w-[1320px] flex-1 px-5 pb-14 pt-8 sm:px-8 sm:pt-10">
        <section className="dashboard-hero relative isolate flex min-h-[260px] items-end overflow-hidden rounded-[28px] border border-white/[0.08] px-6 py-7 sm:min-h-[310px] sm:px-10 sm:py-9">
          <div className="relative z-10 max-w-2xl">
            <p className="mb-3 flex items-center gap-2 text-[11px] font-semibold uppercase tracking-[0.24em] text-[#d9bd91]">
              <span className="h-px w-7 bg-[#d9bd91]" /> Real-world assets, thoughtfully managed
            </p>
            <h1 className="max-w-xl font-serif text-4xl leading-[1.08] tracking-[-0.03em] text-[#f4f0e8] sm:text-5xl">
              A more grounded way to invest.
            </h1>
            <p className="mt-4 max-w-lg text-sm leading-6 text-[#d5d3ca] sm:text-base">
              Tokenized real estate with transparent ownership and compliance built in.
            </p>
          </div>
        </section>

        <div className="mb-6 mt-8 flex items-end justify-between">
          <h2 className="font-serif text-3xl tracking-tight text-[#f4f0e8]">Portfolio overview</h2>
        </div>

        {!isConnected ? (
          <PanelCard className="animate-fade-up flex flex-col items-start gap-6 p-6 sm:flex-row sm:items-center sm:justify-between sm:p-8">
            <div>
              <h3 className="font-serif text-2xl text-[#f4f0e8]">Your assets, in one place</h3>
              <p className="mt-2 max-w-xl text-sm leading-6 text-[#a8a99e]">Connect your wallet to view your balance, eligibility, and asset activity.</p>
            </div>
          </PanelCard>
        ) : !deployed ? (
          <PanelCard className="animate-fade-up py-10">
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[#c9a978]">Network notice</p>
            <h3 className="mt-2 font-serif text-2xl text-[#f4f0e8]">Switch to Sepolia</h3>
            <p className="mt-2 text-sm leading-6 text-[#a8a99e]">Contracts are not deployed on this network. Use the wallet action above to switch to Sepolia, where the deployment lives.</p>
          </PanelCard>
        ) : (
          <div className="animate-fade-up space-y-6">
            <GlobalStats />

            <div className="border-b border-white/[0.09]">
              <nav className="-mb-px flex gap-2 overflow-x-auto" aria-label="Contract panels">
                {visibleTabs.map((t) => (
                  <button
                    key={t.id}
                    onClick={() => setTab(t.id)}
                    aria-current={activeTab === t.id ? 'page' : undefined}
                    className={`shrink-0 border-b-2 px-4 py-3 text-sm font-medium transition-colors ${
                      activeTab === t.id
                        ? 'border-[#c9a978] text-[#e4c99e]'
                        : 'border-transparent text-[#92978e] hover:text-[#e8e5dc]'
                    }`}
                  >
                    {t.label}
                  </button>
                ))}
              </nav>
            </div>

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
