/**
 * The accounts, named apart from what they hold.
 *
 * A role's permissions may target the Safe or the modifier, and the modifier is
 * declared with those roles — so the two files would import each other. An
 * uninvoked accessor is a forward reference to the same node, which breaks the
 * cycle: permissions point at these, `index.ts` is the only place that fills
 * them in, and `push()` resolves both to one account by label.
 */
const eth = constellation({
  workspace: "Default workspace",
  label: "Lido Active Treasury Management",
  chain: 1, // ethereum
});

export const assetSafeNode = eth.safe["Lido Asset Safe"];
export const treasuryRolesNode = eth.roles["Lido Treasury Roles"];
