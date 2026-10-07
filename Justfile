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

# Rebuild every generated file: the policy artifact, the log, the status register and the guide
regen: policy-compile
	{{py}} scripts/build_log.py
	{{py}} scripts/validate_docs.py --write-status
	{{py}} scripts/build_onboarding.py

# Run every check that CI runs, except the fork suite
check: check-docs check-policy check-browser

# The docs bundle, the generated files, the repository checks and their tests
check-docs:
	{{py}} scripts/validate_docs.py
	{{py}} scripts/validate_docs.py --check-status
	{{py}} scripts/test_validate_docs.py
	{{py}} scripts/build_log.py --check
	{{py}} scripts/build_onboarding.py --check
	{{py}} scripts/test_build_onboarding.py
	{{py}} scripts/check_redaction.py
	{{py}} scripts/check_licences.py
	{{py}} scripts/check_invariants.py
	{{py}} scripts/test_checks.py

# The policy artifact equals a fresh compile; the compiler's tests; the type check
check-policy:
	cd policy/constellation && bun install --frozen-lockfile --ignore-scripts && bun compiler/compile.ts --manifest manifests/fork-25946643.json --check && bun test compiler && ./node_modules/.bin/tsc --noEmit -p .

# Every control of the onboarding guide, in headless Chromium
check-browser:
	{{browser}} scripts/test_onboarding_page.py

# The fork suite on the pinned mainnet fork; needs RPC (no keys)
test-fork:
	RPC=${RPC} forge test -vvv

# Add a log entry dated now, and rebuild the log. KIND: Decision, Evidence, Import, Initialization or Update
log kind text:
	{{py}} scripts/build_log.py --new {{quote(kind)}} {{quote(text)}}

# Record a human's own verification of a page, with the hash of its body. Humans only (CONTRIBUTING.md)
verify page by *flags:
	{{py}} scripts/verify_page.py {{quote(page)}} --by {{quote(by)}} {{flags}}

# Compile the contracts and scripts
build:
	forge build

# Policy (ADR 004): compile the constellation into the committed fork artifact
policy-compile:
	cd policy/constellation && bun install --frozen-lockfile --ignore-scripts && bun compiler/compile.ts --manifest manifests/fork-25946643.json

# Policy: fail if the committed artifact differs from a fresh compile; run the compiler tests
policy-check:
	cd policy/constellation && bun install --frozen-lockfile --ignore-scripts && bun compiler/compile.ts --manifest manifests/fork-25946643.json --check && bun test compiler
