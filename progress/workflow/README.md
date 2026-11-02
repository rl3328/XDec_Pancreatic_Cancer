# XDec deconvolution workflow

A Snakemake workflow for bulk-expression deconvolution with
[XDec-SM](https://github.com/BRL-BCM/XDec_SM): optional informative-gene selection,
cell-type-number stability sweep, Stage 1 proportion estimation, and Stage 2
cell-type expression estimation. Pre-exported references are optional.

## Prerequisites

* Python 3.10 or newer.
* Snakemake.
* Python packages `numpy`, `pandas`, and `scipy` in the environment used to run XDec.
* Optional: `quadprog` for XDec's quadratic-programming solver; XDec uses a SciPy
  fallback when it is unavailable.
* Git and network access if the XDec repository needs to be cloned. Alternatively,
  provide an existing checkout through `xdec_repo`.
* A nonnegative, linear-scale bulk-expression TSV with genes as rows and sample
  identifiers as columns. Select expression units appropriate to the analysis;
  this workflow passes the supplied matrix directly to XDec.
* An informative-gene list, or pre-exported reference expression and metadata TSVs
  from which informative genes can be selected.

The workflow does not install Python packages or export references. The optional
standalone reference-export helper additionally requires `scanpy`.

## Layout

```text
workflow/
  Snakefile
  config/config.yaml
  scripts/aggregate_stability.py
```

## Configuration

Set input paths in `workflow/config/config.yaml` or supply a separate YAML file.
The default input paths are placeholders and must point to prepared input files.
Relative paths are resolved from the working directory where Snakemake is run.

```yaml
bulk_counts: data/bulk_expression.tsv
probes_file: data/informative_genes.txt
refs: null
ref_metadata: null
python_bin: python3
xdec_repo: tools/XDec_SM
```

`python_bin` can be an executable on `PATH` or a path to a Python interpreter
containing the required packages. It is used for XDec and workflow helper calls.
`bulk_counts` is the input path used for both Stage 0/1 and Stage 2.

Reference-free execution requires an existing `probes_file`, with one gene
identifier per line matching the bulk-expression row identifiers.

## Running

Run from the directory containing `workflow/` and the configured relative inputs:

```bash
snakemake --snakefile workflow/Snakefile --cores 6 -n
snakemake --snakefile workflow/Snakefile --cores 6
```

Use a separate configuration file:

```bash
snakemake --snakefile workflow/Snakefile --configfile analysis.yaml --cores 6 -n
```

Target one stability result:

```bash
snakemake --snakefile workflow/Snakefile --cores 2 \
    data/deconvolution/xdec/full_sweep/k_09/stability_scores.tsv
```

## Optional references

References must be prepared outside Snakemake. No rule exports references or
requires an H5AD file.

Enable reference-labeled Stage 1/2 runs by configuring both files:

```yaml
refs: data/reference_expression.tsv
ref_metadata: data/reference_metadata.tsv
refs_k_values: [3, 8]
```

The expression TSV has genes as rows and reference samples/cells as columns. The
metadata TSV contains `Sample_ID` and `Cell_Type` columns, with identifiers matching
the reference columns. Reference values must use the linear scale expected by XDec.

With `refs: null`, reference-labeled rules and targets are omitted. When references
are supplied, these additional Stage-1 runs pass XDec's `--refs` and
`--ref-metadata` arguments. The main Stage-1 branch remains reference-free.
`legacy_alias_k` selects which reference-labeled result is also copied to the
unsuffixed `stage1_with_refs/` output directory.

To select informative genes from the references instead of providing a list:

```yaml
refs: data/reference_expression.tsv
ref_metadata: data/reference_metadata.tsv
probes_file: null
```

Both reference files are required for this gene-selection mode. Without references,
an existing informative-gene list is required; all genes are never silently used
as a substitute. Missing required inputs produce an error when their jobs are built.

## Outputs

Results are written under `data/deconvolution/xdec/`:

* `stage0/selected_probes.txt`: generated informative genes, when gene selection is enabled.
* `full_sweep/`: per-k and combined stability scores, plus `optimal_k.txt`.
* `stage1/`: main proportions and normalized profiles.
* `stage2/`: main expression means and standard errors.
* `stage1_with_refs_k*/` and `stage2_with_refs_k*/`: optional reference-labeled results.
* `stage1_with_refs/`: compatibility copy of the configured reference-labeled result.

Per-job logs are written to `logs/`; timing and memory benchmarks are written to
`logs/benchmarks/` for rules with benchmark directives. Snakemake tracks execution
metadata in `.snakemake/`.

## Parallelism

The stability sweep creates one job per k in `k_range`. `--cores N` and
`threads_per_k` determine how many jobs can be scheduled together. For example,
`--cores 6` with `threads_per_k: 2` permits up to three simultaneous sweep jobs.
Actual CPU use depends on the numerical libraries and their thread settings.

Override list settings using YAML/JSON list syntax:

```bash
snakemake --snakefile workflow/Snakefile --cores 6 \
    --config k_range='[3,4,5]' refs_k_values='[3,8,9]'
```

Each per-k subprocess starts with XDec's default random seed. Its random-number
sequence differs from running the complete k range in one subprocess, so the
partitioned and combined sweeps need not produce identical scores.

## Resuming and existing outputs

Use `--rerun-incomplete` to rerun interrupted jobs and `--keep-going` to allow
independent jobs to continue after a failure. Inspect a dry-run before execution,
especially after changing inputs or parameters: existing output paths can be reused
and scheduled for recomputation.

If adopting outputs generated elsewhere, verify their inputs, parameters and tool
versions before registering them with Snakemake. File existence alone does not
establish that results belong to the configured analysis.

## Cluster execution

Install the appropriate Snakemake executor plugin and configure its resources or
profile. For example, a Slurm installation can use `--executor slurm --jobs 50`.
All compute nodes need access to the configured interpreter, dependencies, inputs,
XDec checkout and output locations.
