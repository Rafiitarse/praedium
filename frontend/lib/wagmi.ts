import { WagmiAdapter } from '@reown/appkit-adapter-wagmi';
import { sepolia } from '@reown/appkit/networks';
import type { AppKitNetwork } from '@reown/appkit/networks';

const projectId = process.env.NEXT_PUBLIC_REOWN_PROJECT_ID ?? '';
const sepoliaRpcUrl = process.env.NEXT_PUBLIC_SEPOLIA_RPC_URL;

// Point the Sepolia network at our configured public RPC endpoint.
const sepoliaNetwork = sepoliaRpcUrl
  ? ({
      ...sepolia,
      rpcUrls: { ...sepolia.rpcUrls, default: { http: [sepoliaRpcUrl] } },
    } as AppKitNetwork)
  : sepolia;

export const networks = [sepoliaNetwork] as [AppKitNetwork];

export const wagmiAdapter = new WagmiAdapter({
  networks,
  projectId,
  ssr: true,
});

export const wagmiConfig = wagmiAdapter.wagmiConfig;
