# NanoViewController — task runner (https://github.com/casey/just)
#
# First-time setup:
#   brew install just     # bootstraps the rest
#   just bootstrap        # `brew bundle install` + install git hooks

set shell := ["zsh", "-cu"]

scheme     := "NanoViewController-Package"
result_dir := ".build"
result     := result_dir + "/TestResults.xcresult"
cov_json   := result_dir + "/coverage.json"
sim_device := env_var_or_default("SIM_DEVICE", "iPhone 17")
sim_os     := env_var_or_default("SIM_OS", "26.1")

# Keep in sync with .github/workflows/ci.yml to ensure local and CI use
# the same Apple Silicon simulator destination.
sim := "platform=iOS Simulator,name=" + sim_device + ",OS=" + sim_os + ",arch=arm64"

# ── Default ───────────────────────────────────────────────────────────────────

# List available recipes
default:
    @just --list

# ── Bootstrap ────────────────────────────────────────────────────────────────

# One-shot: install every brew tool the repo needs and the git hooks.
# Run after a fresh checkout. Idempotent — safe to re-run anytime.
bootstrap:
    brew bundle install
    pre-commit install --hook-type pre-commit --hook-type pre-push
    just example-gen

# ── Testing ───────────────────────────────────────────────────────────────────

# Build and run every per-package test target against the iOS Simulator.
# `xcodebuild test` against the SPM package picks up every `.testTarget` in
# Package.swift via the auto-generated `<PackageName>-Package` scheme.
test:
    xcodebuild test \
        -scheme {{scheme}} \
        -destination '{{sim}}' \
        ENABLE_USER_SCRIPT_SANDBOXING=NO \
        | xcpretty

# Run tests, then print a pretty per-file coverage table.
# Produces .build/coverage.json for machine use (no extra tools required).
cov: _run-cov
    @python3 scripts/cov_table.py {{cov_json}}

# Like cov, but also writes Cobertura XML for upload to Codecov.
cov-cobertura: _run-cov
    xcresultparser --output-format cobertura {{result}} > {{result_dir}}/coverage.xml

# ── Examples ─────────────────────────────────────────────────────────────────

# (Re)generate the SignUpDemo Xcode project from its project.yml.
# Run after pulling new commits / editing project.yml — the .xcodeproj
# under Examples/SignUpDemo/ is gitignored.
example-gen:
    cd Examples/SignUpDemo && xcodegen generate

# Build the SignUpDemo example for the simulator.
example-build:
    xcodebuild build \
        -project Examples/SignUpDemo/SignUpDemo.xcodeproj \
        -scheme SignUpDemo \
        -destination '{{sim}}' \
        ENABLE_USER_SCRIPT_SANDBOXING=NO \
        | xcpretty

# ── Formatting ────────────────────────────────────────────────────────────────

# Auto-format all Swift sources in-place; silently skips any tool not installed.
fmt:
    @if command -v swiftformat >/dev/null 2>&1; then swiftformat Sources Tests; fi
    @if command -v swiftlint  >/dev/null 2>&1; then swiftlint --fix --force-exclude; fi

# ── Internal ──────────────────────────────────────────────────────────────────

# Run xcodebuild with coverage enabled and write the result bundle + JSON.
_run-cov:
    rm -rf {{result}}
    mkdir -p {{result_dir}}
    xcodebuild test \
        -scheme {{scheme}} \
        -destination '{{sim}}' \
        -enableCodeCoverage YES \
        -resultBundlePath {{result}} \
        ENABLE_USER_SCRIPT_SANDBOXING=NO \
        | xcpretty
    @xcrun xccov view --report --json {{result}} > {{cov_json}}
