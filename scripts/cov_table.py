#!/usr/bin/env python3
"""
Print Unicode box tables summarising per-file code coverage for every
non-test target in an SPM coverage JSON (output of
`xcrun xccov view --report --json TestResults.xcresult`).

One section per library target, with a grand TOTAL row across all of them
at the bottom.

Honours the `ignore:` block in `codecov.yml` (sibling of the script's
parent directory) so the local table reports the same metric Codecov
reports — files in the ignore list are skipped from both the per-target
table and the grand total.

Usage: python3 cov_table.py <coverage.json>
"""
import fnmatch, json, os, re, sys

COV_JSON = sys.argv[1]

RED    = "\033[31m"
YELLOW = "\033[33m"
GREEN  = "\033[32m"
DIM    = "\033[2m"
BOLD   = "\033[1m"
RESET  = "\033[0m"

TL, TM, TR = "┌", "┬", "┐"
ML, MM, MR = "├", "┼", "┤"
BL, BM, BR = "└", "┴", "┘"
HZ, VT     = "─", "│"


def pct_color(pct: float) -> str:
    if pct >= 0.90: return GREEN
    if pct >= 0.70: return YELLOW
    return RED


def fmt_pct(pct: float) -> str:
    """Return a fixed-width '  X.X%' string wrapped in ANSI colour codes."""
    return pct_color(pct) + f"{pct * 100:5.1f}%" + RESET


def hline(left: str, mid: str, right: str, widths: list[int]) -> str:
    return left + mid.join(HZ * (w + 2) for w in widths) + right


def cell(value: str, width: int, align: str = "<") -> str:
    return f" {value:{align}{width}} "


def repo_root() -> str:
    """Repo root = the directory containing `codecov.yml` / `Package.swift`,
    inferred from the script's location (scripts/ is a sibling of both)."""
    return os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))


def parse_codecov_ignore(path: str) -> list[str]:
    """Tiny YAML reader for just the top-level `ignore:` list. Avoids
    pulling in PyYAML, which isn't shipped with the system Python on macOS."""
    if not os.path.isfile(path):
        return []
    patterns: list[str] = []
    in_block = False
    with open(path) as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            stripped = line.lstrip()
            if not stripped or stripped.startswith("#"):
                continue
            indent = len(line) - len(stripped)
            if not in_block:
                if re.match(r"^ignore\s*:\s*$", line):
                    in_block = True
                continue
            # Inside the block: items are list entries indented past the key.
            if indent == 0:
                # New top-level key — block ends.
                in_block = False
                continue
            m = re.match(r"^-\s*(?:\"([^\"]+)\"|'([^']+)'|(\S+))\s*$", stripped)
            if m:
                patterns.append(m.group(1) or m.group(2) or m.group(3))
    return patterns


def is_ignored(repo_relative_path: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatchcase(repo_relative_path, p) for p in patterns)


def render_table(target: dict, files: list[dict]) -> tuple[int, int]:
    """Print a table for `files` of `target` and return (covered, executable)."""
    files = sorted(files, key=lambda f: os.path.basename(f["path"]))

    name_w = max((len(os.path.basename(f["path"])) for f in files), default=4)
    name_w = max(name_w, len("File"))

    W = [name_w, 6, 7, 8]
    HEADERS = ["File", "Lines", "Covered", "Coverage"]

    print(hline(TL, TM, TR, W))

    print(
        VT
        + VT.join([
            cell(BOLD + HEADERS[0] + RESET, W[0] + len(BOLD) + len(RESET), "<"),
            cell(BOLD + HEADERS[1] + RESET, W[1] + len(BOLD) + len(RESET), ">"),
            cell(BOLD + HEADERS[2] + RESET, W[2] + len(BOLD) + len(RESET), ">"),
            cell(BOLD + HEADERS[3] + RESET, W[3] + len(BOLD) + len(RESET), ">"),
        ])
        + VT
    )
    print(hline(ML, MM, MR, W))

    total_exec = 0
    total_covd = 0

    for f in files:
        name    = os.path.basename(f["path"])
        pct     = f["lineCoverage"]
        pct_str = fmt_pct(pct)
        extra   = len(pct_str) - 6
        total_exec += f["executableLines"]
        total_covd += f["coveredLines"]

        print(
            VT
            + cell(name,                       W[0], "<")
            + VT
            + cell(str(f["executableLines"]),  W[1], ">")
            + VT
            + cell(str(f["coveredLines"]),     W[2], ">")
            + VT
            + cell(pct_str,                    W[3] + extra, ">")
            + VT
        )

    print(hline(ML, MM, MR, W))

    pct       = (total_covd / total_exec) if total_exec else 0.0
    pct_str   = fmt_pct(pct)
    extra     = len(pct_str) - 6
    total_lbl = BOLD + "TARGET" + RESET

    print(
        VT
        + cell(total_lbl,                                       W[0] + len(BOLD) + len(RESET), "<")
        + VT
        + cell(BOLD + str(total_exec) + RESET,                  W[1] + len(BOLD) + len(RESET), ">")
        + VT
        + cell(BOLD + str(total_covd) + RESET,                  W[2] + len(BOLD) + len(RESET), ">")
        + VT
        + cell(BOLD + pct_str + RESET,                          W[3] + extra + len(BOLD) + len(RESET), ">")
        + VT
    )
    print(hline(BL, BM, BR, W))

    return total_covd, total_exec


root = repo_root()
ignore_patterns = parse_codecov_ignore(os.path.join(root, "codecov.yml"))

with open(COV_JSON) as fh:
    data = json.load(fh)

# Skip test targets — coverage of tests themselves is meaningless.
targets = [t for t in data["targets"] if not t["name"].endswith("Tests")]
targets.sort(key=lambda t: t["name"])

if not targets:
    sys.exit("No non-test targets found in coverage JSON")

grand_exec = 0
grand_covd = 0

for t in targets:
    kept = []
    skipped = []
    for f in t.get("files", []):
        path = f["path"]
        rel  = os.path.relpath(path, root) if path.startswith(root) else path
        if is_ignored(rel, ignore_patterns):
            skipped.append(rel)
        else:
            kept.append(f)

    if kept:
        kept_exec = sum(f["executableLines"] for f in kept)
        kept_covd = sum(f["coveredLines"]    for f in kept)
        pct       = (kept_covd / kept_exec) if kept_exec else 0.0
    else:
        kept_exec = 0
        kept_covd = 0
        pct       = 0.0

    bar_color  = pct_color(pct)
    pct_label  = f"{pct * 100:.1f}%" if kept else "—"
    print()
    print(f"{BOLD}{bar_color}▸ {t['name']}{RESET}{bar_color}  {pct_label}{RESET}")

    if not kept:
        if t.get("files"):
            print(f"  {DIM}(all files ignored by codecov.yml){RESET}")
        else:
            print(f"  {RED}(no covered files — target has no test exercise){RESET}")
        continue

    covd, execd = render_table(t, kept)
    grand_covd += covd
    grand_exec += execd

    if skipped:
        print(f"  {DIM}ignored by codecov.yml: {', '.join(os.path.basename(p) for p in skipped)}{RESET}")

total_pct = (grand_covd / grand_exec) if grand_exec else 0.0

print()
print(f"{BOLD}TOTAL  {fmt_pct(total_pct)}  ({grand_covd}/{grand_exec}){RESET}")
print()
