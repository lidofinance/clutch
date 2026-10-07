# MAINNET recipes of the dry-run kit. They broadcast real transactions and spend real ETH.
# Agents never run them (AGENTS.md, ADR 012). A human runs one with:
#   CLUTCH_MAINNET=1 just --justfile mainnet.just <recipe>
# Signing uses a Foundry keystore, which asks for its password:
#   cast wallet import <name> --interactive
# .env names the keystore and its address (ACCOUNT, SENDER) and never holds a private key
# or a password. Only the governance heads are mocked; see test/README.md.

set dotenv-load

# Refuse unless a human asked for mainnet, outside CI, with a keystore and no raw key
_guard:
	@test "${CLUTCH_MAINNET:-}" = "1" || { echo "Refused: these recipes broadcast on mainnet. Set CLUTCH_MAINNET=1 to run one." >&2; exit 1; }
	@test -z "${CI:-}" || { echo "Refused: CI never broadcasts." >&2; exit 1; }
	@test -z "${PRIVATE_KEY:-}" || { echo "Refused: remove PRIVATE_KEY; the mainnet recipes sign with a keystore (ACCOUNT, SENDER)." >&2; exit 1; }
	@test -n "${ACCOUNT:-}" || { echo "Set ACCOUNT, the name of a cast wallet keystore." >&2; exit 1; }
	@test -n "${SENDER:-}" || { echo "Set SENDER, the address of that keystore." >&2; exit 1; }
	@test -n "${RPC:-}" || { echo "Set RPC, an archive mainnet RPC." >&2; exit 1; }

# 1. Deploy the dry run (mocked Agent and Easy Track), compile its policy and apply it through the Agent
[confirm("This broadcasts a deployment on MAINNET and spends real ETH. Continue?")]
dry-run: _guard
	forge script script/DeployDryRun.s.sol --rpc-url ${RPC} --account ${ACCOUNT} --sender ${SENDER} --broadcast --slow
	cd policy/constellation && bun compiler/compile.ts --manifest ../../dryrun-manifest.json --out ../../dryrun-artifact.json
	ARTIFACT=dryrun-artifact.json forge script script/ApplyPolicy.s.sol --rpc-url ${RPC} --account ${ACCOUNT} --sender ${SENDER} --broadcast --slow

# 2. Fund the dry-run Safe from a 0.05 ETH funder (after dry-run; SAFE from dryrun-manifest.json)
[confirm("This sends real ETH on MAINNET. Continue?")]
fund: _guard
	forge script script/BootstrapFunds.s.sol --rpc-url ${RPC} --account ${ACCOUNT} --sender ${SENDER} --broadcast

# 3. Tear it down: sweep the funds, disable both modifiers, write the teardown manifest
[confirm("This broadcasts the teardown on MAINNET. Continue?")]
teardown: _guard
	forge script script/Teardown.s.sol --rpc-url ${RPC} --account ${ACCOUNT} --sender ${SENDER} --broadcast

# Show the manifests that the recipes wrote
status:
	@cat dryrun-manifest.json dryrun-artifact.json bootstrap-manifest.json teardown-manifest.json 2>/dev/null || true
