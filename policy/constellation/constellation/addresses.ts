/**
 * Lido governance actors, from docs.lido.fi. None of these are declared by this
 * constellation — they already exist and are referenced by address.
 */

/**
 * Final governance authority over treasury assets and sole owner of the Asset
 * Safe. The Safe owns the Roles modifier. The Agent is also the fixed
 * destination the emergency role is allowed to return assets to.
 *
 * Easy Track motions execute *as* the Agent: the EVMScriptExecutor holds
 * RUN_SCRIPT_ROLE on it and forwards the EVM script the motion carries. So a
 * single owner covers both permission-change paths the RFP asks for — the Easy
 * Track factories and the direct LDO-vote override — without Easy Track ever
 * holding authority of its own.
 */
export const ARAGON_AGENT = "0x3e40D73EB977Dc6a537aF587D48316feE66E9C8c";

/** Treasury Management Committee, 4-of-7. Holds the `operator` role. */
export const OPERATOR_SAFE = "0xa02FC823cCE0D016bD7e17ac684c9abAb2d6D647";

/** Emergency Brakes (Ethereum), 3-of-5. Holds the `emergency` role. */
export const EMERGENCY_SAFE = "0x73b047fe6337183A454c5217241D780a932777bD";

/** CoW Protocol pulls sold tokens through this contract, so it is the spender
 * every swap approval names — and one the emergency role must be able to
 * revoke. */
export const COW_VAULT_RELAYER = "0xC92E8bdf79f0507f65a392b0ab4667716BFE0110";
