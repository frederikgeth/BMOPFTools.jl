"""
extract_pmdlab_enrichment.py

For each PMDLab (network, feeder) pair, extracts enrichment data from the
ENG and MATH JSON models and writes a compact enrichment JSON to the same
directory.  The enrichment files are the self-contained baseline for porting
PMDLab additions back into BMOPF JSONs; once generated the ENG/MATH files
are no longer needed for this purpose.

Enrichment file schema (all quantities in SI units, BMOPF conventions):

{
  "source_eng":  "<key>_model_eng.json",
  "source_math": "<key>_model_math.json",
  "bases": {
    "v_base_V": <float>,   // phase-to-neutral base voltage (V)
    "s_base_VA": <float>,  // apparent power base (VA)
    "i_base_A": <float>    // current base (A)
  },
  "bus_bounds": {
    "<eng_bus_name>": { "vpn_min": <V>, "vpn_max": <V> },
    ...
  },
  "linecode_ratings": {
    "<lcname>": { "i_max_A": <float> },
    ...
  },
  "generators": {
    "der_<bus_name>": {
      "bus":           "<eng_bus_name>",
      "terminal_map":  ["<phase>", "n"],
      "configuration": "SINGLE_PHASE",
      "p_min_W":       [0.0],
      "p_max_W":       [<float>],
      "cost_per_W":    <float>    // linear cost coefficient ($/W)
    },
    ...
  }
}

Usage:
    python3 scripts/oneoff/extract_pmdlab_enrichment.py

Writes one *_enrichment.json per pair into test/data/PMDLab/.
"""

import json
import os
import re
import sys

PMDLAB_DIR = os.path.join(
    os.path.dirname(__file__), "..", "..", "test", "data", "PMDLab"
)
PMDLAB_DIR = os.path.normpath(PMDLAB_DIR)

# Integer terminal -> BMOPF string name convention (matches from_dss)
_TERMINAL_NAME = {1: "1", 2: "2", 3: "3", 4: "n"}


def _terminal_str(t):
    return _TERMINAL_NAME.get(int(t), str(t))


def _build_maps(math_data):
    """Return (math_bus_idx -> eng_bus_name, eng_bus_name -> math_bus_idx,
               math_load_idx -> eng_load_name) from the MATH map array."""
    math_bus_to_eng = {}
    eng_bus_to_math = {}
    math_load_to_eng = {}
    for entry in math_data.get("map", []):
        fn = entry.get("unmap_function", "")
        if fn == "_map_math2eng_bus!":
            idx = int(entry["to"].split(".")[1])
            name = entry["from"]
            math_bus_to_eng[idx] = name
            eng_bus_to_math[name] = idx
        elif fn == "_map_math2eng_load!":
            idx = int(entry["to"].split(".")[1])
            math_load_to_eng[idx] = entry["from"]
    return math_bus_to_eng, eng_bus_to_math, math_load_to_eng


def _extract_bases(eng_data):
    s = eng_data["settings"]
    vscale = float(s["voltage_scale_factor"])   # 1000 -> kV to V
    pscale = float(s["power_scale_factor"])      # 1000 -> kW to W
    sbase_kva = float(s["sbase_default"])
    vbase_kv = float(list(s["vbases_default"].values())[0])
    V_base = vbase_kv * vscale
    S_base = sbase_kva * pscale
    I_base = S_base / V_base
    return V_base, S_base, I_base


def _bus_bounds(math_data, math_bus_to_eng, eng_bus_to_math, V_base):
    src_math_idx = eng_bus_to_math.get("sourcebus")
    bounds = {}
    for bidx_str, bus in math_data["bus"].items():
        bidx = int(bidx_str)
        if bidx == src_math_idx:
            continue
        vmin_pu = bus.get("vmin")
        vmax_pu = bus.get("vmax")
        if vmin_pu is None or vmax_pu is None:
            continue
        # vmin/vmax are per-phase lists; skip if all None
        vmin_vals = [v for v in vmin_pu if v is not None]
        vmax_vals = [v for v in vmax_pu if v is not None]
        if not vmin_vals or not vmax_vals:
            continue
        eng_name = math_bus_to_eng.get(bidx)
        if eng_name is None:
            continue
        # Bounds are uniform across phases; take first value
        bounds[eng_name] = {
            "vpn_min": round(vmin_vals[0] * V_base, 6),
            "vpn_max": round(vmax_vals[0] * V_base, 6),
        }
    return bounds


def _linecode_ratings(eng_data):
    ratings = {}
    for lcid, lc in eng_data.get("linecode", {}).items():
        cm_ub = lc.get("cm_ub")
        if cm_ub is None:
            continue
        # cm_ub is a per-phase list (3 values, all equal); take first
        vals = [v for v in cm_ub if v is not None]
        if vals:
            ratings[lcid] = {"i_max_A": float(vals[0])}
    return ratings


def _generators(math_data, eng_data, math_bus_to_eng, S_base):
    # Build: eng_bus_name -> {connections, ...} from ENG loads
    eng_load_by_bus = {}
    for lid, load in eng_data.get("load", {}).items():
        bus = load.get("bus")
        if bus:
            eng_load_by_bus.setdefault(bus, []).append(load)

    gens = {}
    for gid, g in math_data.get("gen", {}).items():
        # Skip voltage source (gen.1)
        if g.get("source_id") == "voltage_source.source":
            continue

        gen_bus_math = g.get("gen_bus")
        if gen_bus_math is None:
            continue
        eng_bus = math_bus_to_eng.get(gen_bus_math)
        if eng_bus is None:
            continue

        # Determine single phase from the co-located load's connections
        loads_here = eng_load_by_bus.get(eng_bus, [])
        if not loads_here:
            # No co-located load found — skip with warning
            print(f"  WARNING: gen.{gid} at eng bus {eng_bus} has no co-located load", file=sys.stderr)
            continue
        load = loads_here[0]
        conns = load.get("connections", [])
        # conns is e.g. [1, 4] or [2, 4]; phase = first non-neutral terminal
        phase_int = next((c for c in conns if c != 4), None)
        if phase_int is None:
            print(f"  WARNING: gen.{gid} at eng bus {eng_bus} load has no phase terminal", file=sys.stderr)
            continue
        phase_str = _terminal_str(phase_int)
        terminal_map = [phase_str, "n"]

        # pmax: per-phase list in pu; all equal — take first non-None
        pmax_pu_list = g.get("pmax", [])
        pmax_pu = next((v for v in pmax_pu_list if v is not None), None)
        if pmax_pu is None:
            print(f"  WARNING: gen.{gid} has no pmax", file=sys.stderr)
            continue
        p_max_W = float(pmax_pu) * S_base

        # cost: [c1_pu, c0] linear model; c1 in $/pu -> $/W
        cost = g.get("cost", [])
        c1_pu = float(cost[0]) if cost else 0.0
        cost_per_W = c1_pu / S_base

        der_id = f"der_{eng_bus}"
        gens[der_id] = {
            "bus":           eng_bus,
            "terminal_map":  terminal_map,
            "configuration": "SINGLE_PHASE",
            "p_min_W":       [0.0],
            "p_max_W":       [round(p_max_W, 4)],
            "cost_per_W":    round(cost_per_W, 12),
        }

    return gens


def process_pair(key):
    eng_file  = os.path.join(PMDLAB_DIR, f"{key}_model_eng.json")
    math_file = os.path.join(PMDLAB_DIR, f"{key}_model_math.json")
    out_file  = os.path.join(PMDLAB_DIR, f"{key}_enrichment.json")

    with open(eng_file) as f:
        eng = json.load(f)
    with open(math_file) as f:
        math = json.load(f)

    math_bus_to_eng, eng_bus_to_math, math_load_to_eng = _build_maps(math)
    V_base, S_base, I_base = _extract_bases(eng)

    result = {
        "source_eng":  os.path.basename(eng_file),
        "source_math": os.path.basename(math_file),
        "bases": {
            "v_base_V":  round(V_base, 8),
            "s_base_VA": round(S_base, 2),
            "i_base_A":  round(I_base, 6),
        },
        "bus_bounds":        _bus_bounds(math, math_bus_to_eng, eng_bus_to_math, V_base),
        "linecode_ratings":  _linecode_ratings(eng),
        "generators":        _generators(math, eng, math_bus_to_eng, S_base),
    }

    with open(out_file, "w") as f:
        json.dump(result, f, indent=2)

    n_buses = len(result["bus_bounds"])
    n_lcs   = len(result["linecode_ratings"])
    n_gens  = len(result["generators"])
    return n_buses, n_lcs, n_gens


def main():
    pairs = sorted(set(
        re.match(r"(network_\d+_feeder_\d+)_model_eng\.json", fname).group(1)
        for fname in os.listdir(PMDLAB_DIR)
        if re.match(r"network_\d+_feeder_\d+_model_eng\.json", fname)
    ))

    print(f"Processing {len(pairs)} pairs...")
    ok = 0
    failed = 0
    for key in pairs:
        try:
            n_buses, n_lcs, n_gens = process_pair(key)
            print(f"  {key}: {n_buses} buses, {n_lcs} linecodes, {n_gens} DERs")
            ok += 1
        except Exception as e:
            print(f"  ERROR {key}: {e}", file=sys.stderr)
            failed += 1

    print(f"\nDone: {ok} succeeded, {failed} failed.")
    print(f"Enrichment files written to: {PMDLAB_DIR}")


if __name__ == "__main__":
    main()
