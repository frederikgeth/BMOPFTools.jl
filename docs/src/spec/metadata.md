# Document metadata

Every case may carry a top-level `meta` object providing provenance, licensing, and
versioning. It is optional for backward compatibility, but conformant writers should
populate it. This is a *data-model* page — `meta` carries no OPF variables or
constraints. Symbols are defined in [Notation](notation.md).

## The `meta` object

| Field | Type | Description |
|-------|------|-------------|
| `$schema` | string (URI) | URI of the JSON Schema this file was validated against |
| `version` | string | Version of this **dataset** (not the schema) |
| `title` | string | Human-readable dataset name (distinct from the machine-readable root `name`) |
| `description` | string | Free-text notes or caveats |
| `created` | string (ISO 8601) | Creation timestamp, UTC |
| `modified` | string (ISO 8601) | Last-revision timestamp, UTC |
| `license` | string | SPDX identifier (e.g. `CC-BY-4.0`) or an `https://` URI to the licence |
| `frequency` | number (Hz) | Nominal system frequency — **check-only** (validated against `line_geometry`/linecode derivation frequency; never rescales) |
| `authors` | object[] | Ordered authors — see below |
| `sources` | object[] | Upstream data references — see below |
| `generator` | object | Tool that wrote the file — see below |
| `provenance` | object | Free-form conversion/audit notes written by tooling |

**`authors[]`**: `name`, `email`, `orcid` (bare hyphenated form `XXXX-XXXX-XXXX-XXXX`,
without the `https://orcid.org/` prefix).

**`sources[]`**: `name`, `url` (dereferenceable `https://`), `format` (e.g. `OpenDSS`,
`PMD-JSON`, `MATPOWER`), `doi`, `version`.

**`generator`**: `tool`, `version`.

## Conformance notes

- `$schema` follows the JSON Schema `$schema` keyword convention; it should be a
  versioned, dereferenceable URI (a floating reference to `main` is acceptable in draft).
- Dates must be UTC and should include a time component (`THH:MM:SSZ`); a date-only
  value is permitted when the time is unknown.
- `license` should be a URI when the licence needs specific attribution language beyond
  an SPDX identifier.
- Unknown fields may be present; conformant readers must ignore them.
- `frequency` is a consistency check only — it never defaults or rescales any quantity.

## Example

```json
{
  "name": "enwl_network1_feeder1",
  "meta": {
    "$schema": "https://example.org/bmopf/schema/v1/bmopf.json",
    "version": "1.0",
    "title": "ENWL LV Network 1, Feeder 1",
    "description": "Four-wire 230/400 V LV feeder from the ENWL LVNS dataset.",
    "created": "2026-06-15T10:00:00Z",
    "license": "https://creativecommons.org/licenses/by/4.0/",
    "frequency": 50.0,
    "authors": [
      { "name": "A. Researcher", "email": "a@example.org", "orcid": "0000-0001-9534-2265" }
    ],
    "sources": [
      { "name": "ENWL LVNS dataset", "url": "https://www.enwl.co.uk/lvns", "format": "OpenDSS" }
    ],
    "generator": { "tool": "BMOPFTools.jl", "version": "0.1.0" }
  },
  "bus": { "...": {} },
  "line": { "...": {} }
}
```
