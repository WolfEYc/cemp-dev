#!/usr/bin/env python3
"""Generate synthetic Kohl's NPS NDJSON rows consistent with MOCK_DATA.json."""

from __future__ import annotations

import argparse
import json
import random
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

try:
    import ulid as _ulid
except ImportError:
    _ulid = None

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DATASET_DIR = REPO_ROOT / "data" / "vendor=khols" / "dataset=nps"
DEFAULT_MOCK_PATH = DEFAULT_DATASET_DIR / "MOCK_DATA.json"

# (mu, sigma) for random.gauss; TX/NY use wider sigma for a more even 1–10 spread.
STATE_SCORE_PARAMS: dict[str, tuple[float, float]] = {
    "CA": (8.0, 1.35),
    "FL": (8.0, 1.35),
    "TX": (5.5, 2.05),
    "NY": (5.5, 2.05),
    "IL": (4.0, 1.35),
}

OUTLIER_PROB = 0.03
EVENT_START = datetime(2025, 1, 1, tzinfo=timezone.utc)
EVENT_END = datetime(2026, 12, 31, 23, 59, 59, tzinfo=timezone.utc)


def utc_run_timestamp_prefix() -> str:
    res = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return res


def load_store_mappings(mock_path: Path) -> dict[str, list[str]]:
    """Return state -> list of referal_store_code (one state per store enforced)."""
    store_to_state: dict[str, str] = {}
    with mock_path.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            row = json.loads(line)
            store = row["referal_store_code"]
            state = row["state"]
            if store in store_to_state and store_to_state[store] != state:
                msg = f"store {store!r} maps to multiple states"
                raise ValueError(msg)
            store_to_state[store] = state

    by_state: dict[str, list[str]] = defaultdict(list)
    for store, state in store_to_state.items():
        by_state[state].append(store)
    for stores in by_state.values():
        stores.sort()
    return dict(by_state)


def resolve_output_path(output: Path | None, default_dir: Path, ts: str) -> Path:
    """Basename always starts with ts (UTC prefix)."""
    name_default = f"{ts}_synthetic_nps.ndjson"
    if output is None:
        res = default_dir / name_default
        return res

    output = output.expanduser()
    if output.exists() and output.is_dir():
        res = output / name_default
        return res

    if output.suffix.lower() not in (".ndjson", ".json"):
        res = output / name_default
        return res

    stem = output.stem
    suffix = output.suffix
    res = output.parent / f"{ts}_{stem}{suffix}"
    return res


def clamp_score(value: int) -> int:
    res = max(1, min(10, value))
    return res


def sample_promoter_score(state: str, rng: random.Random) -> int:
    if rng.random() < OUTLIER_PROB:
        branch = rng.random()
        if branch < 0.34:
            raw = rng.gauss(1.8, 1.0)
        elif branch < 0.67:
            raw = rng.gauss(9.2, 1.0)
        else:
            raw = float(rng.randint(1, 10))
        score = clamp_score(int(round(raw)))
        return score

    mu, sigma = STATE_SCORE_PARAMS[state]
    raw = rng.gauss(mu, sigma)
    score = clamp_score(int(round(raw)))
    return score


def random_event_timestamp(rng: random.Random) -> str:
    delta = EVENT_END - EVENT_START
    seconds = int(delta.total_seconds())
    offset = rng.randrange(seconds + 1)
    dt = EVENT_START + timedelta(seconds=offset)
    res = dt.strftime("%Y-%m-%dT%H:%M:%SZ")
    return res


def new_ulid_string() -> str:
    if _ulid is None:
        msg = "ulid-py is required; install with: uv sync --extra data-gen"
        raise RuntimeError(msg)
    res = str(_ulid.new())
    return res


def parse_args() -> argparse.Namespace:
    epilog = (
        "Requires ulid-py (optional project extra). Install with: uv sync --extra data-gen"
    )
    parser = argparse.ArgumentParser(
        description="Generate synthetic NPS NDJSON for vendor=khols/dataset=nps.",
        epilog=epilog,
    )
    parser.add_argument(
        "--rows",
        type=int,
        required=True,
        help="Number of JSON lines (records) to write.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output directory, or .ndjson/.json file path; basename is prefixed with UTC timestamp.",
    )
    parser.add_argument(
        "--mock",
        type=Path,
        default=DEFAULT_MOCK_PATH,
        help="NDJSON file to derive store→state mapping (default: MOCK_DATA.json).",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=None,
        help="RNG seed for reproducible output.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    ts = utc_run_timestamp_prefix()
    out_path = resolve_output_path(args.output, DEFAULT_DATASET_DIR, ts)

    if args.rows < 1:
        print("--rows must be >= 1", file=sys.stderr)
        sys.exit(1)

    mock_path = args.mock
    if not mock_path.is_file():
        print(f"mock file not found: {mock_path}", file=sys.stderr)
        sys.exit(1)

    stores_by_state = load_store_mappings(mock_path)
    states = sorted(stores_by_state.keys())
    if not states:
        print("no states found in mock data", file=sys.stderr)
        sys.exit(1)

    rng = random.Random(args.seed)

    out_path.parent.mkdir(parents=True, exist_ok=True)

    with out_path.open("w", encoding="utf-8") as out:
        for _ in range(args.rows):
            state = rng.choice(states)
            store = rng.choice(stores_by_state[state])
            promoter_score = sample_promoter_score(state, rng)
            event_timestamp = random_event_timestamp(rng)
            shopper_id = new_ulid_string()
            event_id = new_ulid_string()
            record = {
                "country": "US",
                "state": state,
                "promoter_score": promoter_score,
                "khols_shopper_id": shopper_id,
                "event_id": event_id,
                "event_timestamp": event_timestamp,
                "referal_store_code": store,
            }
            line = json.dumps(record, separators=(",", ":"), ensure_ascii=False)
            out.write(line)
            out.write("\n")

    print(f"wrote {args.rows} rows to {out_path}")


if __name__ == "__main__":
    main()
