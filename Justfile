# Dry-run of the Clutch permission system. Requires: foundry, an archive
# mainnet RPC, and a funded throwaway EOA for the mainnet recipes.
# Only the governance heads are mocked; see test/README.md.

set dotenv-load

# 1. Fork drill suite (no keys needed) on the pinned mainnet fork
test-fork:
	RPC=${RPC} forge test -vvv

# 2. Dry run on MAINNET: deploy (mocked Agent/ET + real Safe/Roles), compile the
#    policy against the deployment manifest, then apply the artifact through the Agent
dry-run:
	forge script script/DeployDryRun.s.sol --rpc-url ${RPC} --broadcast --slow
	cd policy/constellation && bun compiler/compile.ts --manifest ../../dryrun-manifest.json --out ../../dryrun-artifact.json
	ARTIFACT=dryrun-artifact.json forge script script/ApplyPolicy.s.sol --rpc-url ${RPC} --broadcast --slow

# 3. Fund it from a 0.05 ETH funder EOA (run after dry-run; SAFE from dryrun-manifest.json)
fund:
	forge script script/BootstrapFunds.s.sol --rpc-url ${RPC} --broadcast

# 4. Tear it all down: sweep funds, disable both modifiers, write teardown manifest
teardown:
	forge script script/Teardown.s.sol --rpc-url ${RPC} --broadcast

# 5. Compile only
build:
	forge build

# Policy (ADR 004): compile the constellation into the committed fork artifact
policy-compile:
	cd policy/constellation && bun install --frozen-lockfile && bun compiler/compile.ts --manifest manifests/fork-25946643.json

# Policy: fail if the committed artifact differs from a fresh compile; run the compiler tests
policy-check:
	cd policy/constellation && bun install --frozen-lockfile && bun compiler/compile.ts --manifest manifests/fork-25946643.json --check && bun test compiler

# Show all manifests
status:
	@cat dryrun-manifest.json dryrun-artifact.json bootstrap-manifest.json teardown-manifest.json 2>/dev/null || true
