#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
yaml2env.py -- translate a Microbiome-SOP-Toolkit YAML config file into
shell-exportable environment variables.

Why this exists:
  The toolkit's two drivers (run_16s.sh / run_metagenome.sh) are bash-native
  and parameterized via environment variables / CLI flags.  Users however
  prefer a single YAML config file.  This converter bridges the two: it reads
  a *deliberately simple* YAML subset (flat keys, two-level nesting, scalars,
  comments) and emits `export VAR='value'` lines that the drivers source.

The parser intentionally implements only the subset used by the example
configs in config/ (see docs/PARAMETERS.md).  It is NOT a general YAML
engine -- keep configs simple on purpose.  Supported value types:
  - plain scalars      input: /data/fastq
  - quoted scalars     region: "16S_V4"
  - numbers            threads: 16
  - yes/no (bool)      resume: yes
  - inline lists       binners: [metabat2, maxbin2, concoct]
  - nested blocks      dada2:
                         trim_left_f: 0

Unknown keys are reported on stderr and ignored, so configs may document
parameters of the other workflow without breaking anything.

Usage:
  yaml2env.py 16s       config/16s_config.yaml > /tmp/16s.env
  yaml2env.py metagenome config/metagenome_config.yaml
  (or: yaml2env.py <workflow> --example  to print the mapping table)

Output lines are shell-quoted; the drivers consume them with:
  eval "$(python3 "$PIPELINE/bin/yaml2env.py" "$WORKFLOW" "$CONFIG")"
"""

import argparse
import re
import shlex
import sys

# ---------------------------------------------------------------------------
# workflow -> {yaml key (dots allowed): internal variable}
# ---------------------------------------------------------------------------
MAP_16S = {
    # paths
    "input": "FASTQ_DIR",
    "output": "PROJECT_DIR",
    "project_dir": "PROJECT_DIR",
    "metadata": "METADATA_FILE",
    # amplicon setup
    "region": "REGION",
    "mode": "SEQUENCING_MODE",
    "forward_primer": "FORWARD_PRIMER",
    "reverse_primer": "REVERSE_PRIMER",
    "classifier": "CLASSIFIER",
    "classifier_dir": "CLASSIFIER_DIR",
    # shared runtime
    "threads": "DADA2_THREADS",          # also propagated below to the other thread vars
    # primer trimming
    "run_cutadapt": "RUN_CUTADAPT",
    "auto_primer_trim": "AUTO_PRIMER_TRIM",
    "cutadapt.error_rate": "CUTADAPT_ERROR_RATE",
    "cutadapt.minimum_length": "CUTADAPT_MINIMUM_LENGTH",
    # DADA2
    "auto_trunc": "AUTO_TRUNC",
    "dada2.trim_left_f": "TRIM_LEFT_F",
    "dada2.trim_left_r": "TRIM_LEFT_R",
    "dada2.trunc_len_f": "TRUNC_LEN_F",
    "dada2.trunc_len_r": "TRUNC_LEN_R",
    "max_ee": "MAX_EE",
    "quality_threshold": "QUALITY_THRESHOLD",
    "min_trunc_len": "MIN_TRUNC_LEN",
    "expected_amplicon_len": "EXPECTED_AMPLICON_LENGTH",
    "min_samples": "MIN_SAMPLES",
    # taxonomy filtering
    "filtering.target_domain": "TARGET_DOMAIN",
    "filtering.exclude_mitochondria": "EXCLUDE_MITOCHONDRIA",
    "filtering.exclude_chloroplast": "EXCLUDE_CHLOROPLAST",
    "filtering.exclude_archaea": "EXCLUDE_ARCHAEA",
    "filtering.exclude_eukaryota": "EXCLUDE_EUKARYOTA",
    "filtering.exclude_unassigned": "EXCLUDE_UNASSIGNED_DOMAIN",
    # conda
    "conda.conda_sh": "CONDA_SH",
    "conda.conda_module": "CONDA_MODULE",
    "conda.qiime2_env": "QIIME2_ENV",
    "conda.microeco_env": "R_MICROECO_ENV",
    # optional downstream
    "optional.run_core_metrics": "RUN_CORE_METRICS",
    "optional.sampling_depth": "SAMPLING_DEPTH",
    "optional.run_alpha_rarefaction": "RUN_ALPHA_RAREFACTION",
    "optional.alpha_max_depth": "ALPHA_MAX_DEPTH",
    "optional.run_taxa_barplot": "RUN_TAXA_BARPLOT",
    "optional.run_file2meco_validation": "RUN_FILE2MECO_VALIDATION",
    # runtime
    "runtime.resume": "RESUME",
    "runtime.check_gzip_integrity": "CHECK_GZIP_INTEGRITY",
    "runtime.count_reads": "COUNT_READS",
}

MAP_METAGENOME = {
    # paths
    "project_dir": "PROJECT_DIR",
    "input": "FASTQ_DIR",
    "fastq_dir": "FASTQ_DIR",
    "group_file": "GROUP_FILE",
    # QC / host removal
    "qc_needed": "QC_NEEDED",
    "host_genome": "HOST_GENOME",
    "host_fasta": "HOST_FASTA",
    "host_name": "HOST_NAME",
    "host_db_dir": "HOST_DB_DIR",
    "adapters": "ADAPTERS",
    "trimmomatic_dir": "TRIMMOMATIC_DIR",
    "trimmomatic_opts": "TRIMMOMATIC_OPTS",
    "bowtie2_opts": "BOWTIE2_OPTS",
    # assembly
    "assembly": "ASSEMBLY_MODE",
    "min_contig_len": "GENE_MIN_CONTIG_LEN",
    "bin_min_contig_len": "BIN_MIN_CONTIG_LEN",
    # gene catalog
    "cluster": "GENE_CLUSTERER",
    "gene.identity": "GENE_MIN_IDENTITY",
    "gene.coverage": "GENE_MIN_COVERAGE",
    "gene.translate_trim": "TRANSLATE_TRIM",
    # quantification
    "quant": "QUANT_TOOL",
    "contig_coverage": "CONTIG_COVERAGE",
    # taxonomy
    "taxonomy": "TAXONOMY_TOOL",
    "nr_db": "NR_DMND",
    "megan_map": "MEGAN_MAP",
    "max_target_seqs": "DIAMOND_MAX_TARGET_SEQS",
    "taxa_filter": "TAXA_FILTER",
    "kraken2_db": "KRAKEN2_DB",
    # function
    "function": "FUNCTION_TOOL",
    "eggnog_db": "EGGNOG_DATA_DIR",
    "eggnog_shm": "EGGNOG_SHM",
    "eggnog.prot_min_len": "EGGNOG_PROT_MIN_LEN",
    "kegg.module_def": "KEGG_MODULE_DEF",
    "kegg.module_name": "KEGG_MODULE_NAME",
    "kegg.pathway_def": "KEGG_PATHWAY_DEF",
    "kegg.complete_threshold": "KEGG_COMPLETE_THRESHOLD",
    # binning / MAGs
    "binning": "BINNING_TOOL",
    "metawrap_reads_mode": "METAWRAP_READS_MODE",
    "binners": "MAG_BINNERS",
    "binning_refine": "RUN_BINNING_REFINE",
    "binning_reassemble": "RUN_BINNING_REASSEMBLE",
    "run_drep": "RUN_DREP",
    "drep_ignore_quality": "DREP_IGNORE_QUALITY",
    "mag_filter": "MAG_FILTER",
    "mag_min_completeness": "MAG_MIN_COMPLETENESS",
    "mag_max_contamination": "MAG_MAX_CONTAMINATION",
    "checkm2_db": "CHECKM2_DB",
    "checkm2_threads": "CHECKM2_THREADS",
    # MAG downstream annotation
    "mag_annotate": "MAG_ANNOTATE",
    "mag_quant": "MAG_QUANT",
    "mag_quant_methods": "MAG_QUANT_METHODS",
    "gtdbtk_db": "GTDBTK_DATA_PATH",
    "gtdbtk_pplacer_cpus": "GTDBTK_PPLACER_CPUS",
    "kofam_profile": "KOFAM_PROFILE",
    "kofam_ko_list": "KOFAM_KO_LIST",
    # conda environments
    "conda.conda_sh": "CONDA_SH",
    "conda.conda_module": "CONDA_MODULE",
    "conda.qc_env": "ENV_QC",
    "conda.assembly_env": "ENV_ASSEMBLY",
    "conda.gene_env": "ENV_GENE",
    "conda.mmseqs_env": "ENV_CLUSTER_MMSEQS",
    "conda.cdhit_env": "ENV_CLUSTER_CDHIT",
    "conda.salmon_env": "ENV_SALMON",
    "conda.bwa_env": "ENV_BWA",
    "conda.diamond_env": "ENV_DIAMOND",
    "conda.megan_env": "ENV_MEGAN",
    "conda.kraken2_env": "ENV_KRAKEN2",
    "conda.eggnog_env": "ENV_EGGNOG",
    "conda.metawrap_env": "ENV_METAWRAP",
    "conda.checkm2_env": "ENV_CHECKM2",
    "conda.drep_env": "ENV_DREP",
    "conda.gtdbtk_env": "ENV_GTDBTK",
    "conda.coverm_env": "ENV_COVERM",
    "conda.kofam_env": "ENV_KOFAM",
    "conda.mag_prodigal_env": "ENV_MAG_PRODIGAL",
    # resources
    "resources.threads": "THREADS",
    "resources.jobs": "CONCURRENT_JOBS",
    "resources.memory_gb": "MEMORY_GB",
    # runtime
    "runtime.resume": "RESUME",
}

MAPPINGS = {"16s": MAP_16S, "metagenome": MAP_METAGENOME}

# variables that are propagated together when `threads` is given
THREAD_PROPAGATION = {
    "16s": ("DADA2_THREADS", "CUTADAPT_THREADS", "CLASSIFIER_JOBS", "PHYLOGENY_THREADS"),
    "metagenome": ("THREADS",),
}

SCALAR_RE = re.compile(r"^(?P<indent>[ \t]*)(?P<key>[A-Za-z0-9_.-]+):[ \t]*(?P<value>.*)$")
LIST_RE = re.compile(r"^\[(.*)\]$")


def parse_value(raw):
    """Return the string value for a YAML scalar, with quote/list handling."""
    raw = raw.strip()
    if not raw:
        return ""
    if raw.startswith('"') and raw.endswith('"') and len(raw) >= 2:
        return raw[1:-1]
    if raw.startswith("'") and raw.endswith("'") and len(raw) >= 2:
        return raw[1:-1]
    m = LIST_RE.match(raw)
    if m:
        items = [x.strip().strip("'\"") for x in m.group(1).split(",")]
        return ",".join(x for x in items if x)
    # strip trailing inline comment (only if preceded by whitespace)
    raw = re.sub(r"\s+#.*$", "", raw).strip()
    return raw


def parse_yaml_lines(lines):
    """Parse the supported YAML subset into {dotted.key: value}."""
    out = {}
    pending = None  # key of an open nested block
    pending_indent = 0
    for lineno, line in enumerate(lines, 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.lstrip().startswith("- "):
            sys.stderr.write("yaml2env: WARNING line %d: list items at top level not supported; ignored\n" % lineno)
            continue
        m = SCALAR_RE.match(line)
        if not m:
            sys.stderr.write("yaml2env: WARNING line %d: unparsable line, ignored: %r\n" % (lineno, line))
            continue
        indent = len(m.group("indent"))
        key = m.group("key")
        value = m.group("value")
        if value.strip() == "":
            if indent == 0:
                # start of a nested block
                pending = key
                pending_indent = indent
            else:
                # indented key with empty value inside the current block
                out["%s.%s" % (pending, key)] = ""
            continue
        if indent > 0 and pending is not None:
            out["%s.%s" % (pending, key)] = parse_value(value)
        else:
            if pending is not None and indent <= pending_indent:
                pending = None
            out[key] = parse_value(value)
    return out


def convert(workflow, config_path, out=sys.stdout, err=sys.stderr):
    if workflow not in MAPPINGS:
        err.write("yaml2env: unknown workflow %r (use: %s)\n" % (workflow, ", ".join(sorted(MAPPINGS))))
        return 1
    mapping = MAPPINGS[workflow]
    try:
        with open(config_path, "r", encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except OSError as exc:
        err.write("yaml2env: cannot read %s: %s\n" % (config_path, exc))
        return 1

    parsed = parse_yaml_lines(lines)
    emitted = set()
    for ykey in sorted(parsed):
        if ykey not in mapping:
            err.write("yaml2env: WARNING unknown key %r (ignored; see docs/PARAMETERS.md)\n" % ykey)
            continue
        var = mapping[ykey]
        val = parsed[ykey]
        if var == "" and val == "":
            continue
        # threads propagation
        if var in THREAD_PROPAGATION[workflow]:
            for v2 in THREAD_PROPAGATION[workflow]:
                out.write("export %s=%s\n" % (v2, shlex.quote(val)))
                emitted.add(v2)
            continue
        out.write("export %s=%s\n" % (var, shlex.quote(val)))
        emitted.add(var)
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("workflow", choices=sorted(MAPPINGS), help="16s or metagenome")
    ap.add_argument("config", help="path to the YAML config file")
    args = ap.parse_args()
    sys.exit(convert(args.workflow, args.config))


if __name__ == "__main__":
    main()
