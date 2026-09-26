# Bundled fixture provenance

The copyright holder confirmed ownership of the non-IEEE/Kersting fixtures
and authorized CC BY 4.0 on 2026-09-26. The common grant and attribution are in
`license.md`; existing directory notices remain applicable.

| Paths | Provenance |
|---|---|
| `SWER/`, `pf_comparison/` | Synthetic package fixtures; original directory notices retained. |
| `line_geometry/` | Original synthetic overhead, concentric-neutral, and tape-shield inputs and independently generated OpenDSS reference matrices. See its README. Replaces the former IEEE-13/Kersting configurations. |
| `powerio_v08_bmopf.json` | PowerIO 0.8.0 output from the copyright holder's three-bus regression input; conversion provenance described in `test/powerio_v08_tests.jl`. |
| `pmd_bounds/`, `ybus/`, `issue190_generator.dss` | Copyright-holder-authorized regression inputs. |
| `scientific_review/`, `transformer_interoperability/`, `powerio_duplicate_new/`, `parameter_updates/` | Minimized package-behavior witnesses; consuming tests and local READMEs describe their purpose. |
| `schema_alias/` | Original one-bus URI regression. |
| `roundtrip_*.json`, `roundtrip_expectations.md` | Package test expectations and source-to-target mappings. References do not bundle external source cases. |

The separate IEEE13_FIXTURE embedded in `test/runtests.jl` is not covered by
this grant. Its replacement or attribution decision remains a release item.
Scientific citations to Kersting and other authors are retained as references
to methods, not relabelled as original fixture data.

Restricted MV/LV and ENWL corpora remain external in BMOPFDraftData under their
existing notices; see `../RESTRICTED_DATA.md`. No Git history was rewritten.
