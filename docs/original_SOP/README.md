# Original SOPs (archived, sanitized)

This directory preserves the **original source SOPs** that this toolkit was
packaged from, for provenance and traceability.  Nothing here is executed by
the toolkit; the executable copies live in `../workflows/`.

| Directory | Source (on the original machine) | Contents |
|---|---|---|
| `qiime2_amplicon_16S/` | `~/Desktop/QIIME2_analysis_SOP/qiime2_amplicon/` | The QIIME2 16S amplicon SOP (steps 00–09, config, `qiime2-sop` wrapper) |
| `metagenome_sop_MGTA/` | `~/Desktop/宏基因组数据分析 SOP 构建/metagenome_sop/` | The MGTA-based shotgun metagenome SOP (modules 01–08, `run_mg_sop.sh`, `mg-sop`) |
| `QIIME2_metagenome_parallel/` | `~/Desktop/QIIME2_analysis_SOP/metagenome/` | A **second, parallel** metagenome SOP (soybean-rhizosphere lineage: virome, virus-host, metaT, AMG, microbe-traits modules, Kaiju taxonomy). It is a separately maintained pipeline, not superseded — see `../SOP_REVIEW.md` section C for the packaging decision. |
| `legacy_code/` | `~/Desktop/QIIME2_analysis_SOP/legacy_code/` | Original Notion page text copies + the disabled DIAMOND+MEGAN virus script (historical reference only) |

## Sanitization

The copies are **lightly edited** for public release:

- Server-specific personal paths replaced with neutral placeholders
  (`/public/zycheng/...` → `/home/user/...`, `zycheng@...` → `user@...`,
  `node47` → `node01`, `/dev/shm/eggnog...` → `/tmp/eggnog...`).
- No passwords, tokens, SSH keys, sample-level personal data, or proprietary
  data files are included.
- Excluded files: `.DS_Store`, `__pycache__/`, `*.pyc`, binary archives
  (`metagenome_sop.zip`, tutorial PDFs), and downloaded KEGG data
  (`kegg_download/`) — KEGG data is available from its FTP site
  (see `../DATABASES.md`).

The **original directories on the user's machine were never modified**; these
are read-only archives.

> **Version note**: the archived `qiime2_amplicon_16S/README.md` references a
> future QIIME2 distribution ("2026.4"); the production server this SOP runs
> on uses **QIIME2 2020.11.1**, which is what the active toolkit
> (`envs/16s.yml`, `docs/`) is pinned to.
