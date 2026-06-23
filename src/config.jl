# config.jl
#
# Centralised, user-tunable thresholds for the analysis, validation, and
# augmentation passes. Defaults live in `config/default.toml` (shipped with
# the package) and are loaded once at load time into `_DEFAULT_CONFIG`.
#
# Each entry point that consumes thresholds takes a `config=` keyword that
# defaults to `_DEFAULT_CONFIG`; callers can pass a merged override built with
# `load_config`. This mirrors the existing `domain_rules_check(thresholds=...)`
# pattern, just sourced from a file instead of an inline `const Dict`.

using TOML

# Absolute path to the shipped default configuration.
const _DEFAULT_CONFIG_PATH = normpath(joinpath(@__DIR__, "..", "config", "default.toml"))

"""
    _deep_merge(base, override) -> Dict

Recursively merge `override` onto `base`. Nested `AbstractDict`s are merged
key-by-key; any other value in `override` replaces the one in `base`. Neither
input is mutated.
"""
function _deep_merge(base::AbstractDict, override::AbstractDict)
    out = Dict{String,Any}(string(k) => v for (k, v) in base)
    for (k, v) in override
        k = string(k)
        if v isa AbstractDict && get(out, k, nothing) isa AbstractDict
            out[k] = _deep_merge(out[k], v)
        else
            out[k] = v
        end
    end
    out
end

"""
    load_config(path=nothing) -> Dict{String,Any}

Load a BMOPFTools threshold configuration.

With no argument, returns a fresh copy of the shipped defaults. With a `path`
to a user TOML file, the file is parsed and deep-merged *over* the defaults, so
the file need only specify the keys it wants to change.

The returned dict is sectioned exactly like `config/default.toml`
(`["domain_rules"]`, `["thermal"]`, `["provenance"]["grounding"]`, …) and is
suitable to pass to any entry point's `config=` keyword:

    cfg = load_config("my_lv_feeder.toml")
    report = analyze(net; config=cfg)
"""
function load_config(path::Union{AbstractString,Nothing}=nothing)::Dict{String,Any}
    defaults = TOML.parsefile(_DEFAULT_CONFIG_PATH)
    path === nothing && return defaults
    isfile(path) || throw(ArgumentError("config file not found: $path"))
    _deep_merge(defaults, TOML.parsefile(path))
end

# Loaded once at package load. Treated as read-only; callers that need
# different values pass an override built with `load_config`.
const _DEFAULT_CONFIG = load_config()

# Convenience section accessors — used as default keyword values so each pass
# stays decoupled from the file layout.
_domain_thresholds(cfg=_DEFAULT_CONFIG) = cfg["domain_rules"]
_thermal_cfg(cfg=_DEFAULT_CONFIG)       = cfg["thermal"]
# Guarded so a user TOML predating the section still resolves to packaged defaults.
_feeder_length_cfg(cfg=_DEFAULT_CONFIG) =
    get(get(cfg, "operational", Dict{String,Any}()), "feeder_length", Dict{String,Any}())
_grounding_cfg(cfg=_DEFAULT_CONFIG)     = cfg["provenance"]["grounding"]
_dss_defaults_cfg(cfg=_DEFAULT_CONFIG)  = cfg["provenance"]["dss_defaults"]
_switch_like_cfg(cfg=_DEFAULT_CONFIG)   = cfg["provenance"]["switch_like"]
# Guarded so a user TOML predating the [augment] section still resolves to the
# packaged defaults (which always carry it via the deep-merge in load_config).
_voltage_snap_cfg(cfg=_DEFAULT_CONFIG)  =
    get(get(cfg, "augment", Dict{String,Any}()), "voltage_snap", Dict{String,Any}())
_smart_inverter_cfg(cfg=_DEFAULT_CONFIG) =
    get(get(cfg, "augment", Dict{String,Any}()), "smart_inverter", Dict{String,Any}())
