#!/usr/bin/env python3
"""Write the regional system-type fixtures in this directory.

Original synthetic teaching cases: small enough to read, each one a wiring and
earthing practice the profiler must describe without a false ERROR. They are
not derived from any utility network. Run from anywhere:

    python3 test/data/profiler_systems/generate.py
"""
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
META = {"license": "CC-BY-4.0"}
ORIGIN = "Original synthetic teaching fixture, not calibrated to a utility population. "
A = [0.0, -2 * math.pi / 3, 2 * math.pi / 3]


def linecode(n, r=3.0e-4, x=1.0e-4, i_max=200.0, b=None):
    lc = {}
    for i in range(1, n + 1):
        for j in range(1, n + 1):  # full row-first storage, as the spec defines
            lc[f"R_series_{i}_{j}"] = r if i == j else r / 6
            lc[f"X_series_{i}_{j}"] = x * 3 if i == j else x
    if b is not None:  # shunt susceptance to earth, S/m, split over both ends
        for i in range(1, n + 1):
            lc[f"B_from_{i}_{i}"] = b / 2
            lc[f"B_to_{i}_{i}"] = b / 2
    lc["i_max"] = [i_max] * n
    return lc


def line(f, t, tm, code, length):
    return {"bus_from": f, "bus_to": t, "terminal_map_from": list(tm),
            "terminal_map_to": list(tm), "linecode": code, "length": length}


def source(bus, v, tm=("a", "b", "c")):
    return {"bus": bus, "terminal_map": list(tm), "v_magnitude": [v] * len(tm),
            "v_angle": A[:len(tm)]}


def load(bus, tm, p, pf=0.95, cfg="SINGLE_PHASE", v=None):
    p = p if isinstance(p, list) else [p]
    q = [round(x * math.tan(math.acos(pf)), 1) for x in p]
    out = {"bus": bus, "terminal_map": list(tm), "configuration": cfg,
           "p_nom": p, "q_nom": q}
    if v is not None:
        out["v_nom"] = [v] * len(p)
    return out


def xf(f, t, tmf, tmt, vf, vt, s, r=0.01, x=0.03, **extra):
    """r/x in per unit of the winding rating, split between the two sides."""
    zf = vf ** 2 / s
    zt = vt ** 2 / s
    out = {"bus_from": f, "bus_to": t, "terminal_map_from": list(tmf),
           "terminal_map_to": list(tmt), "v_nom_from": vf, "v_nom_to": vt, "s_rating": s,
           "r_series_from": round(r / 2 * zf, 6), "x_series_from": round(x / 2 * zf, 6),
           "r_series_to": round(r / 2 * zt, 8), "x_series_to": round(x / 2 * zt, 8)}
    out.update(extra)
    return out


def earth(bus, terminal, r_ohm):
    return {"bus": bus, "terminal_map": [terminal], "G_1_1": round(1 / r_ohm, 6), "B_1_1": 0.0}


def bus(names, grounded=None):
    b = {"terminal_names": list(names)}
    if grounded:
        b["perfectly_grounded_terminals"] = list(grounded)
    return b


def case(name, description, **parts):
    return {"name": name, "meta": dict(META, description=ORIGIN + description),
            "terminal_conventions": {"phase": ["a", "b", "c"], "neutral": ["n"], "earth": []},
            **parts}


CASES = {}

# North America: 12.47 kV four-wire multi-grounded-neutral primary, a
# single-phase lateral, and a center-tapped 120/240 V service.
CASES["na_mgn_split_phase"] = case(
    "na_mgn_split_phase",
    "12.47 kV multi-grounded-neutral primary, single-phase lateral, 120/240 V split-phase service",
    bus={"sub": bus("abcn", "n"), "p1": bus("abcn"), "p2": bus("abcn"),
         "lat": bus(["b", "n"]), "svc": bus(["a", "b", "n"])},
    voltage_source={"grid": source("sub", 7200.0)},
    linecode={"primary": linecode(4, i_max=300.0), "lateral": linecode(2, i_max=150.0)},
    line={"main1": line("sub", "p1", "abcn", "primary", 400.0),
          "main2": line("p1", "p2", "abcn", "primary", 400.0),
          "tap": line("p1", "lat", ["b", "n"], "lateral", 250.0)},
    shunt={"gnd_p1": earth("p1", "n", 25.0), "gnd_p2": earth("p2", "n", 25.0),
           "gnd_lat": earth("lat", "n", 25.0), "gnd_svc": earth("svc", "n", 25.0)},
    transformer={"center_tap": {"pole": xf("lat", "svc", ["b", "n"], ["a", "n", "b"],
                                           7200.0, 120.0, 25000.0)}},
    load={"house_a": load("svc", ["a", "n"], 3000.0, v=120.0),
          "house_b": load("svc", ["b", "n"], 2000.0, v=120.0),
          "range": load("svc", ["a", "b"], 4000.0, v=240.0),
          "mill": load("p2", "abcn", [20000.0, 22000.0, 18000.0], cfg="WYE", v=7200.0)})

# North America: open-wye primary / open-delta secondary bank with a
# center-tapped lighting unit — a four-wire (high-leg) 240/120 V delta service.
CASES["na_high_leg_open_delta"] = case(
    "na_high_leg_open_delta",
    "Open-wye/open-delta bank: center-tapped lighting unit plus power unit, 240/120 V high-leg service",
    bus={"sub": bus("abcn", "n"), "pole": bus("abcn"), "svc": bus("abcn")},
    voltage_source={"grid": source("sub", 7200.0)},
    linecode={"primary": linecode(4, i_max=300.0)},
    line={"main": line("sub", "pole", "abcn", "primary", 600.0)},
    shunt={"gnd_pole": earth("pole", "n", 25.0), "gnd_svc": earth("svc", "n", 25.0)},
    transformer={
        "center_tap": {"lighting": xf("pole", "svc", ["a", "n"], ["a", "n", "b"],
                                      7200.0, 120.0, 50000.0)},
        "single_phase": {"power": xf("pole", "svc", ["b", "n"], ["b", "c"],
                                     7200.0, 240.0, 25000.0)}},
    load={"lights_a": load("svc", ["a", "n"], 4000.0, v=120.0),
          "lights_b": load("svc", ["b", "n"], 4000.0, v=120.0),
          "motor": load("svc", "abc", [3000.0, 3000.0, 3000.0], cfg="DELTA", v=240.0)})

# Europe: 10 kV to 400 V Dyn, the star point earthed once at the transformer
# (TN source earthing), four-wire feeder with single- and three-phase customers.
CASES["eu_tn_four_wire"] = case(
    "eu_tn_four_wire",
    "10 kV / 400 V Dyn substation, neutral earthed at the transformer only, four-wire LV feeder",
    bus={"mv": bus("abc"), "lv0": bus("abcn", "n"), "lv1": bus("abcn"), "lv2": bus("abcn")},
    voltage_source={"grid": source("mv", 10000.0 / math.sqrt(3))},
    linecode={"cable": linecode(4, i_max=250.0)},
    line={"f1": line("lv0", "lv1", "abcn", "cable", 120.0),
          "f2": line("lv1", "lv2", "abcn", "cable", 150.0)},
    transformer={"delta_wye": {"sub": xf("mv", "lv0", "abc", "abcn", 10000.0, 400.0, 400000.0,
                                         r=0.01, x=0.04)}},
    load={"h1": load("lv1", ["a", "n"], 3500.0, v=230.0),
          "h2": load("lv1", ["b", "n"], 2500.0, v=230.0),
          "h3": load("lv2", ["c", "n"], 4000.0, v=230.0),
          "shop": load("lv2", "abcn", [5000.0, 5200.0, 4800.0], cfg="WYE", v=230.0)})

# Europe / industrial: an unearthed (IT) 400 V delta island behind a Yd
# transformer. With no modeled capacitance the island has no reference.
it_island = dict(
    bus={"mv": bus("abcn", "n"), "it0": bus("abc"), "it1": bus("abc")},
    voltage_source={"grid": source("mv", 10000.0 / math.sqrt(3))},
    transformer={"wye_delta": {"iso": xf("mv", "it0", "abcn", "abc", 10000.0, 400.0, 250000.0)}},
    load={"drive": load("it1", "abc", [8000.0, 8000.0, 8000.0], cfg="DELTA", v=400.0)})
CASES["it_delta_island_unreferenced"] = case(
    "it_delta_island_unreferenced",
    "Unearthed 400 V delta island with no modeled path to earth: no voltage reference",
    linecode={"cable": linecode(3, i_max=200.0)},
    line={"run": line("it0", "it1", "abc", "cable", 80.0)}, **it_island)
CASES["it_delta_island_capacitive"] = case(
    "it_delta_island_capacitive",
    "The same unearthed delta island, referenced through its cable capacitance to earth",
    linecode={"cable": linecode(3, i_max=200.0, b=1.0e-7)},
    line={"run": line("it0", "it1", "abc", "cable", 80.0)}, **it_island)

# Japan: 6.6 kV three-wire primary; a single-phase pole transformer connected
# phase-to-phase feeds a 100/200 V single-phase three-wire service, and a
# V-connected pair (one unit center-tapped) feeds a three-phase 200 V service
# with the 100 V lighting legs taken from the center-tapped unit.
CASES["jp_three_wire_v_connection"] = case(
    "jp_three_wire_v_connection",
    "6.6 kV three-wire primary, 100/200 V single-phase three-wire service, V-connected 200 V service",
    bus={"sub": bus("abc"), "p1": bus("abc"), "p2": bus("abc"),
         "home": bus(["a", "b", "n"]), "shop": bus("abcn")},
    voltage_source={"grid": source("sub", 6600.0 / math.sqrt(3))},
    linecode={"primary": linecode(3, i_max=200.0)},
    line={"main1": line("sub", "p1", "abc", "primary", 300.0),
          "main2": line("p1", "p2", "abc", "primary", 300.0)},
    shunt={"gnd_home": earth("home", "n", 50.0), "gnd_shop": earth("shop", "n", 50.0)},
    transformer={
        "center_tap": {
            "pole_home": xf("p1", "home", ["a", "b"], ["a", "n", "b"], 6600.0, 100.0, 20000.0),
            "pole_shop_lighting": xf("p2", "shop", ["a", "b"], ["a", "n", "b"],
                                     6600.0, 100.0, 30000.0)},
        "single_phase": {
            "pole_shop_power": xf("p2", "shop", ["b", "c"], ["b", "c"], 6600.0, 200.0, 20000.0)}},
    load={"home_a": load("home", ["a", "n"], 1500.0, v=100.0),
          "home_b": load("home", ["b", "n"], 1200.0, v=100.0),
          "home_ih": load("home", ["a", "b"], 2500.0, v=200.0),
          "shop_lights": load("shop", ["a", "n"], 2000.0, v=100.0),
          "shop_motor": load("shop", "abc", [2500.0, 2500.0, 2500.0], cfg="DELTA", v=200.0)})

# Australia: 11 kV primary, Dyn distribution transformer, multiple-earthed
# neutral (MEN) LV with the neutral earthed at the transformer and at each
# customer installation.
CASES["au_men_four_wire"] = case(
    "au_men_four_wire",
    "11 kV / 415 V Dyn substation with a multiple-earthed-neutral four-wire LV feeder",
    bus={"mv": bus("abc"), "lv0": bus("abcn"), "lv1": bus("abcn"), "lv2": bus("abcn")},
    voltage_source={"grid": source("mv", 11000.0 / math.sqrt(3))},
    linecode={"abc4": linecode(4, i_max=250.0)},
    line={"f1": line("lv0", "lv1", "abcn", "abc4", 90.0),
          "f2": line("lv1", "lv2", "abcn", "abc4", 110.0)},
    shunt={"men_tx": earth("lv0", "n", 10.0), "men_1": earth("lv1", "n", 30.0),
           "men_2": earth("lv2", "n", 30.0)},
    transformer={"delta_wye": {"sub": xf("mv", "lv0", "abc", "abcn", 11000.0, 415.0, 200000.0,
                                         r=0.01, x=0.04)}},
    load={"h1": load("lv1", ["a", "n"], 3000.0, v=240.0),
          "h2": load("lv1", ["b", "n"], 3500.0, v=240.0),
          "h3": load("lv2", ["c", "n"], 2800.0, v=240.0)})

for name, data in CASES.items():
    (HERE / f"{name}.json").write_text(json.dumps(data, indent=1) + "\n")
print(f"wrote {len(CASES)} fixtures to {HERE}")
