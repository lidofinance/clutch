// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.24 <0.9.0;

/// @title Mainnet — the live contracts that the enabling-vote rehearsal uses.
/// @dev Read at block 26196400 (2026-10-15) and run again at block 26249900
///      (2026-10-22). The research note
///      docs/research/enabling-vote-rehearsal-2026-10-15.md records the
///      chain reads that its findings rest on.
library Mainnet {
    // The Aragon DAO
    address internal constant VOTING = 0x2e59A20f205bB85a89C53f1936454680651E618e;
    address internal constant TOKEN_MANAGER = 0xf73a1260d222f447210581DDf212D915c09a3249;
    address internal constant AGENT = 0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c;
    address internal constant ACL = 0x9895F0F17cc1d1891b6f18ee0b483B6f221b37Bb;
    address internal constant FINANCE = 0xB9E5CBB9CA5b0d659238807E84D0176930753d86;
    address internal constant LDO = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;

    // Easy Track and its payment stack
    address internal constant EASY_TRACK = 0xF0211b7660680B49De1A7E9f25C65660F0a13Fea;
    address internal constant ET_EXECUTOR = 0xFE5986E06210aC1eCC1aDCafc0cc7f8D63B3F977;
    address internal constant STABLECOIN_LIST = 0x4AC40c34f8992bb1e5E856A448792158022551ca;
    address internal constant BUILDER_MULTI = 0x334D6eDc13F63728b39e6A6D04A7Bbd5D6A9B9FF;
    address internal constant BUILDER_SINGLE = 0x958e0D946D014F377421a53AB5f9180d4485e63B;
    address internal constant RECIPIENTS_FACTORY_MULTI = 0xEe60C6ebC91237d334230b12263E26EE3b480ec4;
    address internal constant RECIPIENTS_FACTORY_SINGLE = 0x83E976758B7AB1bb676A4fEA073Fa0E2A807642B;
    address internal constant DATE_TIME = 0x75100bd564415731B5936A4A94D0dC29DdE5dB3C;

    // Committees
    address internal constant COMMITTEE_SAFE = 0xa02FC823cCE0D016bD7e17ac684c9abAb2d6D647;
    address internal constant GROWTH_COMMITTEE_SAFE = 0xf6F0732c1e9971497342C295141566E6F1A31e96;

    // Safe v1.5.0 and Zodiac
    address internal constant SAFE_SINGLETON = 0xFf51A5898e281Db6DfC7855790607438dF2ca44b;
    address internal constant SAFE_PROXY_FACTORY = 0x14F2982D601c9458F93bd70B218933A6f8165e7b;
    address internal constant MULTISEND_CALL_ONLY = 0xA83c336B20401Af773B6219BA5027174338D1836;
    address internal constant ROLES_MASTERCOPY = 0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5;
    address internal constant MODULE_PROXY_FACTORY = 0x000000000000aDdB49795b0f9bA5BC298cDda236;

    // CoW Protocol
    address internal constant COW_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address internal constant COW_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;
    address internal constant COW_FALLBACK_HANDLER = 0x2f55e8b20D0B9FEFA187AA7d00B6Cbe563605bF5;
    address internal constant COMPOSABLE_COW = 0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74;

    // Tokens
    address internal constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address internal constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address internal constant SUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address internal constant EARN_ETH_SHARE = 0xBBFC8683C8fE8cF73777feDE7ab9574935fea0A4;
    address internal constant EARN_USD_SHARE = 0x4Ce1ac8F43E0E5BD7A346A98aF777bF8fbeA1981;
    address internal constant EARN_USD_DEPOSIT_QUEUE = 0xC75E7E73B25fEa8bB23EB55CC48BA55067b5be76;
}
