#!/usr/bin/env python3
"""
Print Unicode box tables summarising per-file code coverage for every
non-test target in an SPM coverage JSON (output of
`xcrun xccov view --report --json TestResults.xcresult`).

One section per library target, with a grand TOTAL row across all of them
at the bottom.

Usage: python3 cov_table.py <coverage.json>
"""
import json, os, sys

COV_JSON = sys.argv[1]

RED    = "\033[31m"
YELLOW = "\033[33m"
GREEN  = "\033[32m"
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


def render_table(target: dict) -> None:
    files = sorted(target["files"], key=lambda f: os.path.basename(f["path"]))

    name_w = max((len(os.path.basename(f["path"])) for f in files), default=4)
    name_w = max(name_w, len("File"))

    # Column visible widths: name | lines | covered | coverage
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

    for f in files:
        name    = os.path.basename(f["path"])
        pct     = f["lineCoverage"]
        pct_str = fmt_pct(pct)
        extra   = len(pct_str) - 6  # invisible ANSI bytes

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

    pct       = target["lineCoverage"]
    pct_str   = fmt_pct(pct)
    extra     = len(pct_str) - 6
    total_lbl = BOLD + "TARGET" + RESET

    print(
        VT
        + cell(total_lbl,                                       W[0] + len(BOLD) + len(RESET), "<")
        + VT
        + cell(BOLD + str(target["executableLines"]) + RESET,   W[1] + len(BOLD) + len(RESET), ">")
        + VT
        + cell(BOLD + str(target["coveredLines"])    + RESET,   W[2] + len(BOLD) + len(RESET), ">")
        + VT
        + cell(BOLD + pct_str + RESET,                          W[3] + extra + len(BOLD) + len(RESET), ">")
        + VT
    )
    print(hline(BL, BM, BR, W))


with open(COV_JSON) as fh:
    data = json.load(fh)

# Skip test targets — coverage of tests themselves is meaningless.
targets = [t for t in data["targets"] if not t["name"].endswith("Tests")]
targets.sort(key=lambda t: t["name"])

if not targets:
    sys.exit("No non-test targets found in coverage JSON")

for t in targets:
    pct        = t["lineCoverage"]
    bar_color  = pct_color(pct)
    pct_label  = f"{pct * 100:.1f}%"
    print()
    print(f"{BOLD}{bar_color}▸ {t['name']}{RESET}{bar_color}  {pct_label}{RESET}")

    if not t.get("files"):
        # No tests reach this target; xccov still reports it as 0/0 — surface
        # that explicitly so the table doesn't silently drop the row.
        print(f"  {RED}(no covered files — target has no test exercise){RESET}")
        continue

    render_table(t)

# Grand total across non-test targets.
total_exec = sum(t["executableLines"] for t in targets)
total_covd = sum(t["coveredLines"]    for t in targets)
total_pct  = (total_covd / total_exec) if total_exec else 0.0

print()
print(f"{BOLD}TOTAL  {fmt_pct(total_pct)}  ({total_covd}/{total_exec}){RESET}")
print()
