# Clutch: one command each for setup, for the checks that CI runs, and for the generated
# files (ADR 012). Run `just <recipe>`. Without just installed:
#   uvx --from rust-just==1.58.0 just <recipe>
# The mainnet recipes of the dry-run kit are in mainnet.just, which this file never loads.

set dotenv-load

py := "uv run --quiet --with pyyaml==6.0.2 python"
browser := "uv run --quiet --with pyyaml==6.0.2 --with playwright==1.63.0 --with axe-playwright-python==0.1.8 python"

# List the recipes
default:
	@{{just_executable()}} --list --justfile {{justfile()}}

# Install what the checks need: forge-std, the policy's packages and a headless Chromium
setup:
	git submodule update --init --depth 1
	cd policy/constellation && bun install --frozen-lockfile --ignore-scripts
	uv run --quiet --with playwright==1.63.0 python -m playwright install --only-shell chromium
	forge build
	@echo "Ready. The fork suite also needs RPC=<archive mainnet RPC> in .env, which git ignores."

# Print the versions of the tools that the checks use
doctor:
	@uv --version
	@echo "bun $(bun --version) (CI pins 1.3.0)"
	@forge --version | head -1
	@git --version

# Rebuild every generated file: the policy artifacts, the status register, the ADR index and the guide
regen: policy-compile
	{{py}} scripts/validate_docs.py --write-status
	{{py}} scripts/build_onboarding.py

# Run every check that CI runs, except the fork suite
check: check-docs check-policy check-browser check-workflows

# The docs bundle, the generated files, the repository checks and their tests
check-docs:
	{{py}} scripts/validate_docs.py
	{{py}} scripts/validate_docs.py --check-status
	{{py}} scripts/test_validate_docs.py
	{{py}} scripts/build_onboarding.py --check
	{{py}} scripts/test_build_onboarding.py
	{{py}} scripts/check_redaction.py
	{{py}} scripts/check_licences.py
	{{py}} scripts/check_invariants.py
	{{py}} scripts/test_checks.py

# The policy artifacts equal a fresh compile; the compiler's tests; the type check
check-policy:
	cd policy/constellation && bun install --frozen-lockfile --ignore-scripts && bun compiler/compile.ts --manifest manifests/fork-25946643.json --check && bun compiler/compile.ts --manifest manifests/rehearsal-26249900.json --check && bun compiler/motion.ts example --check && bun test compiler && ./node_modules/.bin/tsc --noEmit -p .

# Every control of the onboarding guide, in headless Chromium
check-browser:
	{{browser}} scripts/test_onboarding_page.py

# The workflows: actionlint and zizmor, offline
check-workflows:
	uvx --from actionlint-py==1.7.12.25 actionlint .github/workflows/*.yml
	uvx zizmor==1.30.1 --offline .github/workflows

# The guide's items whose content or sources changed since their pins, with each source's change
stale:
	{{py}} scripts/build_onboarding.py --stale

# After a review, pin guide items again: just repin actor:asset-safe flow:tranche
repin +items:
	{{py}} scripts/build_onboarding.py --repin {{items}}

# Every outside link of the committed guide, through the GitHub API (weekly in CI)
links:
	{{py}} scripts/check_links.py

# The fork suite on the pinned mainnet fork; needs RPC (no keys)
test-fork:
	RPC=${RPC} forge test -vvv
	bun policy/constellation/compiler/roundtrip.ts rehearsal --dir .roundtrip
	bun policy/constellation/compiler/watch.ts rehearsal --dir .roundtrip

# Build a motion from a merged policy change: just motion <base> <head> --epoch 0 --policy-version 0, or --rpc
motion base head *flags:
	bun policy/constellation/compiler/motion.ts build --base {{quote(base)}} --head {{quote(head)}} --out .motion/motion.json --post .motion/post.md {{flags}}

# Fail unless a motion's calldata turns the policy of <base> into the policy of <head>, and writes nothing else
motion-check base head calldata *flags:
	bun policy/constellation/compiler/motion.ts check --base {{quote(base)}} --head {{quote(head)}} --calldata {{quote(calldata)}} {{flags}}

# Commit a policy change's motion with it: writes pending/<network>/ from <base> to the working tree's artifact
motion-pending base *flags:
	bun policy/constellation/compiler/motion.ts build --pending --base {{quote(base)}} {{flags}}

# The two detectors: the chain against the policy, and every open motion against the pending motion
watch *flags:
	bun policy/constellation/compiler/watch.ts check {{flags}}

# Remove the pending motion's files once the chain holds the committed artifact
motion-settle *flags:
	bun policy/constellation/compiler/watch.ts settle {{flags}}

# Enact the motion of `just motion` through the live Easy Track on a fork, on the vault with the base policy
motion-replay:
	MOTION_FILE=.motion/motion.json POLICY_ARTIFACT=.motion/base.json RPC=${RPC} forge test --match-test test_replay_a_motion_file -vv

# The round-trip check and the two detectors on a fork: record the modifiers' events, rebuild their state and compare it with the policy
round-trip:
	RPC=${RPC} forge test --match-contract RoundTrip
	bun policy/constellation/compiler/roundtrip.ts rehearsal --dir .roundtrip
	bun policy/constellation/compiler/watch.ts rehearsal --dir .roundtrip

# The round-trip check of a policy against an events file or a chain: --events <file>, or --rpc --from-block N
round-trip-check artifact *flags:
	bun policy/constellation/compiler/roundtrip.ts check --artifact {{quote(artifact)}} {{flags}}

# Record a human's own verification of a page, with the hash of its body. Humans only (CONTRIBUTING.md)
verify page by *flags:
	{{py}} scripts/verify_page.py {{quote(page)}} --by {{quote(by)}} {{flags}}

# Compile the contracts and scripts
build:
	forge build

# Policy (ADR 004): compile the constellation into the committed fork artifact and the enabling-vote rehearsal's artifact
policy-compile:
	cd policy/constellation && bun install --frozen-lockfile --ignore-scripts && bun compiler/compile.ts --manifest manifests/fork-25946643.json && bun compiler/compile.ts --manifest manifests/rehearsal-26249900.json && bun compiler/motion.ts example
