# Dry-run of the Clutch permission system. Requires: foundry, an archive
# mainnet RPC, and a funded throwaway EOA for the mainnet recipes.
# Only the governance heads are mocked; see test/README.md.

set dotenv-load

# 1. Fork drill suite (no keys needed) on the pinned mainnet fork
test-fork:
	RPC=${RPC} forge test -vvv

# 2. Deploy the dry-run on MAINNET (mocked Agent/ET + real Safe/Roles + full policy)
dry-run:
	forge script script/DeployDryRun.s.sol --rpc-url ${RPC} --broadcast --slow

# 3. Fund it from a 0.05 ETH funder EOA (run after dry-run; SAFE from dryrun-manifest.json)
fund:
	forge script script/BootstrapFunds.s.sol --rpc-url ${RPC} --broadcast

# 4. Tear it all down: sweep funds, disable both modifiers, write teardown manifest
teardown:
	forge script script/Teardown.s.sol --rpc-url ${RPC} --broadcast

# 5. Compile only
build:
	forge build

# Show all manifests
status:
	@cat dryrun-manifest.json bootstrap-manifest.json teardown-manifest.json 2>/dev/null || true
