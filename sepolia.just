# Local Sepolia work. Public writes are separate from the repository's mainnet recipes.
set dotenv-load

preflight:
    bun policy/constellation/sepolia/preflight.ts

check:
    PYTHONDONTWRITEBYTECODE=1 python3 scripts/test_sepolia_operational_guards.py
    PYTHONDONTWRITEBYTECODE=1 python3 scripts/test_sepolia_protocol_fees.py
    PYTHONDONTWRITEBYTECODE=1 python3 scripts/test_sepolia_cow_order.py
    PYTHONDONTWRITEBYTECODE=1 python3 scripts/test_sepolia_workflow.py
    PYTHONDONTWRITEBYTECODE=1 python3 scripts/test_sepolia_motion.py
    cd policy/constellation && bun test sepolia
    cd policy/constellation && ./node_modules/.bin/tsc --noEmit --module esnext --moduleResolution bundler --target esnext --resolveJsonModule --esModuleInterop --skipLibCheck --strict sepolia/*.ts

# No public transactions. Anvil is stopped after the run.
rehearse:
    python3 scripts/sepolia_rehearse.py

# Read-only upstream RPC; all test mutations stay inside Forge's fork.
test-current:
    python3 scripts/sepolia_test_current.py

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

# The input of one universal-factory motion; reads the chain only. scripts/sepolia_motion.py names the motions,
# one for each motion role; `caps` sets the insurance-funding caps.
motion-input name:
    @python3 scripts/sepolia_motion.py input {{name}}

# The Committee and Emergency Safes are 1/1 with the sender as owner, so the sender's own call is their signature.
# SEPOLIA_SIGNER replaces the keystore only on the local rehearsal. The motion's input is saved under its id,
# because a policy motion that enacts first changes the input that a later one would compute.
motion name: _guard
    #!/usr/bin/env bash
    set -euo pipefail
    m=${SEPOLIA_MANIFEST:-cache/sepolia/manifest.json}; dir=${SEPOLIA_MOTIONS:-cache/sepolia/motions}; et=$(jq -r .easyTrack $m)
    input=$(python3 scripts/sepolia_motion.py input {{name}})
    id=$(cast call $et 'motionsCount()(uint256)' --rpc-url "$SEPOLIA_RPC" | cut -d' ' -f1)
    data=$(cast calldata 'createMotion(address,bytes)' $(jq -r .universalFactory $m) $input)
    signature=0x000000000000000000000000${SEPOLIA_SENDER:2}$(printf '0%.0s' {1..64})01
    cast send $(jq -r .operatorSafe $m) 'execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)' \
        $et 0 $data 0 0 0 0 0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000 $signature \
        --rpc-url "$SEPOLIA_RPC" ${SEPOLIA_SIGNER:---account $SEPOLIA_ACCOUNT} --from "$SEPOLIA_SENDER"
    mkdir -p $dir && echo $input > $dir/$id.hex && echo "Motion {{name}}: id $id"

enact id: _guard
    #!/usr/bin/env bash
    set -euo pipefail
    m=${SEPOLIA_MANIFEST:-cache/sepolia/manifest.json}; dir=${SEPOLIA_MOTIONS:-cache/sepolia/motions}
    cast send $(jq -r .easyTrack $m) 'enactMotion(uint256,bytes)' {{id}} $(cat $dir/{{id}}.hex) \
        --rpc-url "$SEPOLIA_RPC" ${SEPOLIA_SIGNER:---account $SEPOLIA_ACCOUNT} --from "$SEPOLIA_SENDER"

# The Emergency Safe's asset-emergency role disables the operator modifier; the `restart` motion enables it again.
emergency-stop: _guard
    #!/usr/bin/env bash
    set -euo pipefail
    m=${SEPOLIA_MANIFEST:-cache/sepolia/manifest.json}
    signature=0x000000000000000000000000${SEPOLIA_SENDER:2}$(printf '0%.0s' {1..64})01
    cast send $(jq -r .emergencySafe $m) 'execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)' \
        $(jq -r .safetyModifier $m) 0 $(python3 scripts/sepolia_motion.py stop) 0 0 0 0 0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000 $signature \
        --rpc-url "$SEPOLIA_RPC" ${SEPOLIA_SIGNER:---account $SEPOLIA_ACCOUNT} --from "$SEPOLIA_SENDER"

retire-burn-factory: _guard
    m=${SEPOLIA_MANIFEST:-cache/sepolia/manifest.json}; cast send $(jq -r .easyTrack $m) 'removeEVMScriptFactory(address)' $(jq -r .burnFactory $m) --rpc-url "$SEPOLIA_RPC" ${SEPOLIA_SIGNER:---account $SEPOLIA_ACCOUNT} --from "$SEPOLIA_SENDER"

# assignRoles enabled the Easy Track executor as a module, and removing its roles left it enabled.
# Disables it on the two modifiers where it held a role, through ApplySepolia with a two-call artifact.
retire-executor-module: _guard
    #!/usr/bin/env bash
    set -euo pipefail
    m=${SEPOLIA_MANIFEST:-cache/sepolia/manifest.json}; out=cache/sepolia/retire-executor-module.json
    export FOUNDRY_BROADCAST=${FOUNDRY_BROADCAST:-broadcast/retire-executor-module}
    python3 scripts/sepolia_receipts.py fresh $FOUNDRY_BROADCAST/ApplySepolia.s.sol/11155111/run-latest.json
    executor=$(jq -r .easyTrackExecutor $m | tr A-F a-f)
    disable() { local prev=0x0000000000000000000000000000000000000001
        for a in $(cast call $1 'getModulesPaginated(address,uint256)(address[],address)' $prev 100 --rpc-url "$SEPOLIA_RPC" | head -1 | tr -d '[] ' | tr , ' '); do
            [ "$(echo $a | tr A-F a-f)" = "$executor" ] && { cast calldata 'disableModule(address,address)' $prev $executor; return; }; prev=$a; done
        echo "Executor is not a module of $1" >&2; exit 1; }
    op=$(disable $(jq -r .operatorModifier $m)); fl=$(disable $(jq -r .firstLossModifier $m))
    jq --arg op $op --arg fl $fl \
        '{manifest: {chainId, controller, voting}, calls: {to: [.operatorModifier, .firstLossModifier], avatar: [.assetSafe, .firstLossSafe], data: [$op, $fl]}}' $m > $out
    SEPOLIA_ARTIFACT=$out forge script script/sepolia/ApplySepolia.s.sol --hardfork amsterdam --rpc-url "$SEPOLIA_RPC" ${SEPOLIA_SIGNER:---account $SEPOLIA_ACCOUNT} --sender "$SEPOLIA_SENDER" --broadcast --slow --gas-estimate-multiplier 200

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
