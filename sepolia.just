# Local Sepolia work. Public writes are separate from the repository's mainnet recipes.
set dotenv-load

preflight:
    bun policy/constellation/sepolia/preflight.ts

check:
    PYTHONDONTWRITEBYTECODE=1 python3 scripts/test_sepolia_workflow.py
    cd policy/constellation && bun test sepolia
    cd policy/constellation && ./node_modules/.bin/tsc --noEmit --module esnext --moduleResolution bundler --target esnext --resolveJsonModule --esModuleInterop --skipLibCheck --strict sepolia/*.ts

# No public transactions. Anvil is stopped after the run.
rehearse:
    python3 scripts/sepolia_rehearse.py

# Human-only public writes. Foundry prompts for the keystore password.
_guard:
    @test "${CLUTCH_SEPOLIA:-}" = 1
    @test -z "${CI:-}${PRIVATE_KEY:-}${EXECUTOR_KEY:-}"
    @test -n "${SEPOLIA_ACCOUNT:-}" && test -n "${SEPOLIA_SENDER:-}" && test -n "${SEPOLIA_RPC:-}"

deploy: _guard preflight
    @test ! -e cache/sepolia/manifest.json || { echo 'Manifest exists: inspect receipts before resuming a deployment.' >&2; exit 1; }
    python3 scripts/sepolia_receipts.py fresh broadcast/DeploySepolia.s.sol/11155111/run-latest.json
    forge script script/sepolia/DeploySepolia.s.sol --hardfork amsterdam --rpc-url "$SEPOLIA_RPC" --account "$SEPOLIA_ACCOUNT" --sender "$SEPOLIA_SENDER" --broadcast --slow --gas-estimate-multiplier 200

compile:
    bun policy/constellation/sepolia/compile.ts cache/sepolia/manifest.json cache/sepolia/policy.json

# Local SDK serialization and a pinned RPC comparison. No Zodiac API key is used.
constellation workspace:
    bun policy/constellation/sepolia/prepare-constellation.ts {{quote(workspace)}}

constellation-diff:
    bun policy/constellation/sepolia/prepare-constellation.ts --diff

constellation-inspect:
    cd policy/constellation && bun run inspect sepolia/entrypoint.ts

# Human-only hosted calls to the Sepolia workspace (ADR 013). Agents never run these.
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
    forge script script/sepolia/DeploySepolia.s.sol --hardfork amsterdam --rpc-url "$SEPOLIA_RPC" --account "$SEPOLIA_ACCOUNT" --sender "$SEPOLIA_SENDER" --resume --broadcast --slow

resume-apply: _guard
    python3 scripts/sepolia_receipts.py resume broadcast/ApplySepolia.s.sol/11155111/run-latest.json
    forge script script/sepolia/ApplySepolia.s.sol --hardfork amsterdam --rpc-url "$SEPOLIA_RPC" --account "$SEPOLIA_ACCOUNT" --sender "$SEPOLIA_SENDER" --resume --broadcast --slow

resume-fund: _guard
    python3 scripts/sepolia_receipts.py resume broadcast/FundSepolia.s.sol/11155111/run-latest.json
    forge script script/sepolia/FundSepolia.s.sol --hardfork amsterdam --rpc-url "$SEPOLIA_RPC" --account "$SEPOLIA_ACCOUNT" --sender "$SEPOLIA_SENDER" --resume --broadcast --slow

verify-deployment:
    bun policy/constellation/sepolia/verify-deployment.ts

explorer-prepare:
    python3 scripts/sepolia_prepare_verification.py

explorer-check:
    bun policy/constellation/sepolia/explorer.ts check

explorer-status:
    bun policy/constellation/sepolia/explorer.ts status

explorer-submit:
    bun policy/constellation/sepolia/explorer.ts submit
