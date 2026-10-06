import { defineConfig } from "@zodiaceco/sdk/cli/config";

/**
 * Contracts the `allow` kit generates typed permissions for.
 *
 * Protocols with a defi-kit preset (Aave, Sky, Spark, CoW) only appear here
 * where a role needs a narrower slice than the preset gives: the emergency role
 * may withdraw but must never deposit, and no preset splits those apart.
 *
 * Lido Earn addresses follow docs.lido.fi/earn/deployment-contracts.
 */
export default defineConfig({
  contracts: {
    eth: {
      // Launch asset set
      steth: "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84",
      wsteth: "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0",
      ldo: "0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32",
      usdc: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      usdt: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
      dai: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
      sdai: "0x83F20F44975D03b1b09e64809B757c47f942BEeA",
      usds: "0xdC035D45d973E3EC169d2276DDab16f1e407384F",
      susds: "0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD",

      // The implementations the Asset Safe and the Roles modifier run as
      // proxies. They are listed for their ABIs: the emergency role's calls on
      // those two accounts are built from the typed `allow` kit and then
      // retargeted at the nodes, which have no address until they deploy.
      zodiac: {
        safe_mastercopy: "0x41675C099F32341bf84BFc5382aF534df5C7461a",
        roles_mastercopy: "0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5",
      },

      aave_v3: {
        // Core market pool, the address defi-kit's `market: "Core"` resolves to
        pool: "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2",

        // Supplying mints these. Listed so the emergency role can return them
        // to the DAO when a reserve has no liquidity to withdraw against; they
        // stay transferable while `withdraw` reverts. Each was read from the
        // pool's own `getReserveAToken` and checked against its
        // `UNDERLYING_ASSET_ADDRESS` and `POOL`.
        atoken_usdc: "0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c",
        atoken_usdt: "0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a",
        atoken_dai: "0x018008bfb33d285247A21d44E50697654f754e63",
        atoken_usds: "0x32a6268f9Ba3642Dda7892aDd74f1D34469A4259",
        atoken_wsteth: "0x0B925eD163218f6662a35e0f0371Ac234f9E9371",
      },

      lido_earn: {
        earneth: {
          share: "0xBBFC8683C8fE8cF73777feDE7ab9574935fea0A4",
          deposit_queue_eth: "0x1db7094Ef0D994B0b62f6Cd67dB801ad194999A8",
          deposit_queue_weth: "0x3Fc48660d02e59fBedD0a5Cc18a5580D1f8dD6A4",
          deposit_queue_wsteth: "0xe39EED9A454C4918F8d0682062777cB251cd513F",
          redeem_queue: "0x095bFAca9f1c6F2B063Cd67C6d6bfcd0c3aaB7b4",
        },
        earnusd: {
          share: "0x4Ce1ac8F43E0E5BD7A346A98aF777bF8fbeA1981",
          deposit_queue_usdc: "0xC75E7E73B25fEa8bB23EB55CC48BA55067b5be76",
          redeem_queue: "0x9e36A74FE278906a76e7615263e46a83fC40c47F",
        },
      },
    },
  },
});
