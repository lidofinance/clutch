# Local Sepolia work. Public writes are separate from the repository's mainnet recipes.
set dotenv-load

preflight:
    bun policy/constellation/sepolia/preflight.ts

check:
    PYTHONDONTWRITEBYTECODE=1 python3 scripts/test_sepolia_operational_guards.py
    PYTHONDONTWRITEBYTECODE=1 python3 scripts/test_sepolia_protocol_fees.py
    PYTHONDONTWRITEBYTECODE=1 python3 scripts/test_sepolia_cow_order.py
    PYTHONDONTWRITEBYTECODE=1 python3 scripts/test_sepolia_workflow.py
    cd policy/constellation && bun test sepolia
    cd policy/constellation && ./node_modules/.bin/tsc --noEmit --module esnext --moduleResolution bundler --target esnext --resolveJsonModule --esModuleInterop --skipLibCheck --strict sepolia/*.ts

# No public transactions. Anvil is stopped after the run.
rehearse:
    python3 scripts/sepolia_rehearse.py

# Read-only upstream RPC; all test mutations stay inside Forge's fork.
test-current:
    python3 scripts/sepolia_test_current.py

# The move to the universal factory on a pinned fork; no public transaction.
factory-migration:
    python3 scripts/sepolia_factory_migration.py

# Human-only public writes. Foundry prompts for the keystore password.
_guard:
    @test "${CLUTCH_SEPOLIA:-}" = 1
    @test -z "${CI:-}${PRIVATE_KEY:-}${EXECUTOR_KEY:-}"
    @test -n "${SEPOLIA_ACCOUNT:-}" && test -n "${SEPOLIA_SENDER:-}" && test -n "${SEPOLIA_RPC:-}"

deploy: _guard preflight
    @test ! -e cache/sepolia/manifest.json || { echo 'Manifest exists: inspect receipts before resuming a deployment.' >&2; exit 1; }
    python3 scripts/sepolia_receipts.py fresh broadcast/DeploySepolia.s.sol/11155111/run-latest.json
    forge script script/sepolia/DeploySepolia.s.sol --hardfork amsterdam --rpc-url "$SEPOLIA_RPC" --account "$SEPOLIA_ACCOUNT" --sender "$SEPOLIA_SENDER" --broadcast --verify --slow --gas-estimate-multiplier 200

deploy-factory: _guard
    python3 scripts/sepolia_receipts.py fresh broadcast/DeployFactorySepolia.s.sol/11155111/run-latest.json
    forge script script/sepolia/DeployFactorySepolia.s.sol --hardfork amsterdam --rpc-url "$SEPOLIA_RPC" --account "$SEPOLIA_ACCOUNT" --sender "$SEPOLIA_SENDER" --broadcast --verify --slow --gas-estimate-multiplier 200

# The budget motion of the insurance-funding caps: 1 WETH and 1000 USDC in 30 days, under the derived keys
# 0x6b3a ‖ First-loss Safe ‖ first ten bytes of the token. Prints the motion's input; reads the chain only.
caps-input:
    #!/usr/bin/env bash
    set -euo pipefail
    m=${SEPOLIA_MANIFEST:-cache/sepolia/manifest.json}
    op=$(jq -r .operatorModifier $m); fl=$(jq -r .firstLossSafe $m | tr A-F a-f); uf=$(jq -r .universalFactory $m)
    gov=$(cast format-bytes32-string governance)
    cap() { local token; token=$(jq -r ".dependencies.tokens.$1.address" $m | tr A-F a-f)
        cast calldata 'setAllowance(bytes32,uint128,uint128,uint128,uint64,uint64)' "0x6b3a${fl:2}${token:2:20}" $2 $2 $2 2592000 0; }
    epoch=$(cast call $uf 'epoch()(uint256)' --rpc-url "$SEPOLIA_RPC"); version=$(cast call $uf 'policyVersion()(uint256)' --rpc-url "$SEPOLIA_RPC")
    cast abi-encode 'f(uint256,uint256,(address,bytes32,address,bytes)[])' $epoch $version \
        "[($op,$gov,$op,$(cap weth 1000000000000000000)),($op,$gov,$op,$(cap usdc 1000000000))]"

# The Committee Safe is 1/1 with the sender as owner, so the sender's own call is its signature.
caps-motion: _guard
    #!/usr/bin/env bash
    set -euo pipefail
    m=${SEPOLIA_MANIFEST:-cache/sepolia/manifest.json}
    data=$(cast calldata 'createMotion(address,bytes)' $(jq -r .universalFactory $m) $(just --justfile sepolia.just caps-input))
    signature=0x000000000000000000000000${SEPOLIA_SENDER:2}$(printf '0%.0s' {1..64})01
    cast send $(jq -r .operatorSafe $m) 'execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)' \
        $(jq -r .easyTrack $m) 0 $data 0 0 0 0 0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000 $signature \
        --rpc-url "$SEPOLIA_RPC" --account "$SEPOLIA_ACCOUNT" --from "$SEPOLIA_SENDER"

caps-enact id: _guard
    #!/usr/bin/env bash
    set -euo pipefail
    m=${SEPOLIA_MANIFEST:-cache/sepolia/manifest.json}
    cast send $(jq -r .easyTrack $m) 'enactMotion(uint256,bytes)' {{id}} $(just --justfile sepolia.just caps-input) \
        --rpc-url "$SEPOLIA_RPC" --account "$SEPOLIA_ACCOUNT" --from "$SEPOLIA_SENDER"

retire-burn-factory: _guard
    m=${SEPOLIA_MANIFEST:-cache/sepolia/manifest.json}; cast send $(jq -r .easyTrack $m) 'removeEVMScriptFactory(address)' $(jq -r .burnFactory $m) --rpc-url "$SEPOLIA_RPC" --account "$SEPOLIA_ACCOUNT" --from "$SEPOLIA_SENDER"

compile:
    bun policy/constellation/sepolia/compile.ts cache/sepolia/manifest.json cache/sepolia/policy.json

# Local SDK serialization and a pinned RPC comparison. No Zodiac API key is used.
constellation workspace:
    bun policy/constellation/sepolia/prepare-constellation.ts {{quote(workspace)}}

constellation-diff:
    bun policy/constellation/sepolia/prepare-constellation.ts --diff

constellation-inspect:
    cd policy/constellation && bun run inspect sepolia/entrypoint.ts

# Human-only hosted calls to the Sepolia workspace (ADR 015). Agents never run these.
# Each run compares the chain again, then resolves; publish applies once, as a draft.
constellation-resolve:
    bun policy/constellation/sepolia/publish-constellation.ts resolve

constellation-publish:
    bun policy/constellation/sepolia/publish-constellation.ts apply

apply: _guard
    python3 scripts/sepolia_receipts.py fresh broadcast/ApplySepolia.s.sol/11155111/run-latest.json
    just --justfile sepolia.just compile
    forge script script/sepolia/ApplySepolia.s.sol --hardfork amsterdam --rpc-url "$SEPOLIA_RPC" --account "$SEPOLIA_ACCOUNT" --sender "$SEPOLIA_SENDER" --broadcast --slow --gas-estimate-multiplier 200

fund: _guard
    python3 scripts/sepolia_receipts.py fresh broadcast/FundSepolia.s.sol/11155111/run-latest.json
    forge script script/sepolia/FundSepolia.s.sol --hardfork amsterdam --rpc-url "$SEPOLIA_RPC" --account "$SEPOLIA_ACCOUNT" --sender "$SEPOLIA_SENDER" --broadcast --slow --gas-estimate-multiplier 200

# Reuse the saved transaction list; do not compile a fresh policy or simulate again.
# These guards check local records. Foundry checks current nonces; inspect chain state first.
resume-deploy: _guard
    python3 scripts/sepolia_receipts.py resume broadcast/DeploySepolia.s.sol/11155111/run-latest.json
    forge script script/sepolia/DeploySepolia.s.sol --hardfork amsterdam --rpc-url "$SEPOLIA_RPC" --account "$SEPOLIA_ACCOUNT" --sender "$SEPOLIA_SENDER" --resume --broadcast --slow --verify

resume-apply: _guard
    python3 scripts/sepolia_receipts.py resume broadcast/ApplySepolia.s.sol/11155111/run-latest.json
    forge script script/sepolia/ApplySepolia.s.sol --hardfork amsterdam --rpc-url "$SEPOLIA_RPC" --account "$SEPOLIA_ACCOUNT" --sender "$SEPOLIA_SENDER" --resume --broadcast --slow

resume-fund: _guard
    python3 scripts/sepolia_receipts.py resume broadcast/FundSepolia.s.sol/11155111/run-latest.json
    forge script script/sepolia/FundSepolia.s.sol --hardfork amsterdam --rpc-url "$SEPOLIA_RPC" --account "$SEPOLIA_ACCOUNT" --sender "$SEPOLIA_SENDER" --resume --broadcast --slow

verify-deployment:
    bun policy/constellation/sepolia/verify-deployment.ts
