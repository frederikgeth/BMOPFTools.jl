# Bundled fixture provenance inventory

The CC BY-NC-SA MV/LV corpora and ENWL corpus are external in BMOPFDraftData.
See `../RESTRICTED_DATA.md`. This inventory records the evidence available in
the package; it does not assign a new licence to third-party source material.

| Paths | Provenance evidence and remaining review |
|---|---|
| `SWER/`, `pf_comparison/` | Existing `license.md` files describe synthetic package fixtures under CC BY 4.0. Keep those notices. |
| `line_geometry/ieee13_601.dss`, `ieee13_606_cn.dss`, `ieee13_607_ts.dss` | Headers identify IEEE-13 configurations and published Kersting conductor/cable data. These are not wholly original source data. Before release, record the exact upstream publication/files and applicable attribution/redistribution terms. Do not infer those terms from the package code licence. |
| `powerio_v08_bmopf.json` | `test/powerio_v08_tests.jl` records PowerIO 0.8.0 conversion of a three-bus regression case. Retain converter provenance; confirm the original input case's provenance before release. |
| `pmd_bounds/`, `ybus/`, `issue190_generator.dss` | Small regression inputs. Confirm authorship/source from their introducing changes before treating the repository's general fixture policy as sufficient attribution. |
| `scientific_review/`, `transformer_interoperability/`, `powerio_duplicate_new/`, `parameter_updates/` | Minimized/package-behavior witnesses; local READMEs and consuming tests explain their purpose. Confirm attribution for each addition in the final maintainer review. Scientific-review data do not independently establish a general PSK claim. |
| `schema_alias/` | Synthetic one-bus URI regression authored for BMOPFTools; explicit CC BY 4.0 notice in the directory. |
| `roundtrip_*.json`, `roundtrip_expectations.md` | Test expectations and source-to-target node mappings. Referenced external cases are not themselves bundled by these files. |

This inventory was inspected on 2026-09-26. Update it when adding fixture
families. A missing non-commercial header is not evidence of permission.
