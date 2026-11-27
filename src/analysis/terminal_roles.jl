# analysis/terminal_roles.jl
#
# Whether a terminal label is a return path (neutral or earth), read from the
# case's resolved roles (`_index_roles`). Without resolved roles, the naming
# convention decides (`_is_convention_neutral`).
#
# This is the label test the voltage-level and transformer-bank code uses.
# `_return_label_predicate` (BMOPFTools.jl) is a deliberately different test
# for terminal maps: it excludes labels that are also phases and, when roles
# were inferred, adds the naming convention. The two are kept apart because
# their callers' findings are tested against each behavior.
_is_return_label(roles, x)::Bool = roles === nothing ? _is_convention_neutral(x) :
    (x in roles.neutral || x in roles.earth)

# Neutral only (no earth), with the same fallback.
_is_neutral_label(neutral_labels, x)::Bool =
    neutral_labels === nothing ? _is_convention_neutral(x) : x in neutral_labels
