# Brewfile — local-dev tooling for NanoViewController.
#
# Install everything in one shot:
#   brew bundle install
#
# Or run `just bootstrap`, which calls `brew bundle install` and installs
# the pre-commit / pre-push git hooks.

# Build / test
brew "just"          # task runner; recipes live in /justfile
brew "xcpretty"      # nicer xcodebuild output

# Lint / format / typo-check (matched to the CI versions where it matters)
brew "swiftformat"
brew "swiftlint"
brew "typos-cli"
brew "pre-commit"

# Coverage tooling — only needed if you run `just cov-detailed` locally.
brew "xcresultparser"
