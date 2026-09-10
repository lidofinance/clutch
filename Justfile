# One-click dry-run (WS-M). Requires: foundry, a mainnet RPC, a funded throwaway EOA.
# Everything downstream of the mocked governance heads is production-grade.

set := env_set :=

# 1. Fork drill suite (no keys needed): D1-D6 + bootstrap on a pinned mainnet fork
test-fork:
	RPC=${RPC} forge test -vvv

# 2. Deploy the dry-run on MAINNET (mocked Agent/ET + real Safe/Roles + full policy)
dry-run:
	forge script script/DeployDryRun.s.sol --rpc-url ${RPC} --broadcast --slow

# 3. Fund it from a 0.5 ETH funder EOA (run after dry-run; SAFE from dryrun-manifest.json)
fund:
	forge script script/BootstrapFunds.s.sol --rpc-url ${RPC} --broadcast

# 4. Tear it all down: sweep funds, disable the module, write teardown manifest
teardown:
	forge script script/Teardown.s.sol --rpc-url ${RPC} --broadcast

# 5. Compile only
build:
	forge build

# Show all manifests
status:
	@cat dryrun-manifest.json bootstrap-manifest.json teardown-manifest.json 2>/dev/null || true
