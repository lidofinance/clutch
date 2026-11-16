# Local Sepolia work. Public writes are separate from the repository's mainnet recipes.
set dotenv-load

manifest := env("SEPOLIA_MANIFEST", "cache/sepolia/manifest.json")
motions := env("SEPOLIA_MOTIONS", "cache/sepolia/motions")
# SEPOLIA_SIGNER replaces the keystore only on the local rehearsal.
signer := '${SEPOLIA_SIGNER:---account $SEPOLIA_ACCOUNT}'
forge := 'forge script --hardfork amsterdam --rpc-url "$SEPOLIA_RPC" ' + signer + ' --sender "$SEPOLIA_SENDER" --broadcast --slow --gas-estimate-multiplier 200'
# The Committee and Emergency Safes are 1/1 with the sender as owner, so the sender's own call is their signature.
safe_exec := '''execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)'''
safe_tail := '0 0 0 0 0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000 0x000000000000000000000000${SEPOLIA_SENDER:2}0000000000000000000000000000000000000000000000000000000000000000' + '01 --rpc-url "$SEPOLIA_RPC" ' + signer + ' --from "$SEPOLIA_SENDER"'

check:
    PYTHONDONTWRITEBYTECODE=1 python3 scripts/test_sepolia_operational_guards.py
    PYTHONDONTWRITEBYTECODE=1 python3 scripts/test_sepolia_workflow.py
    PYTHONDONTWRITEBYTECODE=1 python3 scripts/test_sepolia_motion.py
    cd policy/constellation && bun test sepolia
    cd policy/constellation && ./node_modules/.bin/tsc --noEmit --module esnext --moduleResolution bundler --target esnext --resolveJsonModule --esModuleInterop --skipLibCheck --strict sepolia/*.ts

# A fresh stand on a local Anvil fork: deploy, apply, fund, every motion, the comparison and the drills.
rehearse:
    python3 scripts/sepolia_rehearse.py

# Read-only upstream RPC; all test mutations stay inside Forge's fork.
test-current:
    python3 scripts/sepolia_test_current.py

# Human-only public writes. Foundry prompts for the keystore password. An interrupted run starts again.
_guard:
    @test "${CLUTCH_SEPOLIA:-}" = 1
    @test -z "${CI:-}${PRIVATE_KEY:-}${EXECUTOR_KEY:-}"
    @test -n "${SEPOLIA_ACCOUNT:-}" && test -n "${SEPOLIA_SENDER:-}" && test -n "${SEPOLIA_RPC:-}"
    @test -z "${SEPOLIA_SIGNER:-}" || { test "$SEPOLIA_SIGNER" = --unlocked && case "$SEPOLIA_RPC" in http://127.0.0.1:*) ;; *) false ;; esac; }

# The stand, its deposit queues and the universal factory. The script checks the chain and each dependency's code hash first.
deploy: _guard
    @test ! -e {{manifest}} || { echo 'Manifest exists: this stand is deployed.' >&2; exit 1; }
    {{forge}} script/sepolia/DeploySepolia.s.sol --verify

compile:
    bun policy/constellation/sepolia/compile.ts {{manifest}} cache/sepolia/policy.json

apply: _guard compile
    SEPOLIA_ARTIFACT=cache/sepolia/policy.json {{forge}} script/sepolia/ApplySepolia.s.sol

fund: _guard
    {{forge}} script/sepolia/FundSepolia.s.sol

# One universal-factory motion from the Committee Safe; scripts/sepolia_motion.py names them. The input is saved
# under the motion's id, because a policy motion that enacts first changes the input that a later one computes.
motion name: _guard
    #!/usr/bin/env bash
    set -euo pipefail
    et=$(jq -r .easyTrack {{manifest}})
    input=$(python3 scripts/sepolia_motion.py input {{name}})
    id=$(cast call $et 'motionsCount()(uint256)' --rpc-url "$SEPOLIA_RPC" | cut -d' ' -f1)
    data=$(cast calldata 'createMotion(address,bytes)' $(jq -r .universalFactory {{manifest}}) $input)
    cast send $(jq -r .operatorSafe {{manifest}}) '{{safe_exec}}' $et 0 $data {{safe_tail}}
    mkdir -p {{motions}} && echo $input > {{motions}}/$id.hex && echo "Motion {{name}}: id $id"

enact id: _guard
    cast send $(jq -r .easyTrack {{manifest}}) 'enactMotion(uint256,bytes)' {{id}} $(cat {{motions}}/{{id}}.hex) \
        --rpc-url "$SEPOLIA_RPC" {{signer}} --from "$SEPOLIA_SENDER"

# The Emergency Safe's asset-emergency role disables the operator modifier; the `restart` motion enables it again.
emergency-stop: _guard
    cast send $(jq -r .emergencySafe {{manifest}}) '{{safe_exec}}' $(jq -r .safetyModifier {{manifest}}) 0 $(python3 scripts/sepolia_motion.py stop) {{safe_tail}}

# The local SDK payload, after a comparison of the chain with the policy. No Zodiac API key is used.
constellation workspace:
    bun policy/constellation/sepolia/prepare-constellation.ts {{quote(workspace)}}

# Human-only hosted calls to the Sepolia workspace (ADR 015). Agents never run these.
# Each run compares the chain again, then resolves; publish applies once, as a draft.
constellation-resolve:
    bun policy/constellation/sepolia/publish-constellation.ts resolve

constellation-publish:
    bun policy/constellation/sepolia/publish-constellation.ts apply
