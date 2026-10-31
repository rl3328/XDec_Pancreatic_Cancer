# XDec deconvolution workflow (Snakemake)

Reproducible, standalone pipeline for the XDec (`BRL-BCM/XDec_SM`) deconvolution of the
TCGA-PAAD cohort: reference export -> Stage 0 gene selection -> k-stability sweep ->
Stage 1 (proportions) -> Stage 2 (per-cell-type expression), optionally repeated
with reference-labeling at several `k` values.

This directory is self-contained and has no dependency on any notebook - everything
here is runnable from a plain terminal. `04_xdec_deconvolution.ipynb`
(in `../scripts/rnaseq_download/`) documents the original, pre-Snakemake hand-run of
the same pipeline for historical record.

## Layout

```
workflow/
  Snakefile              rules: export_reference, stage0_probes, stage0_stability_k,
                         aggregate_stability, stage1_main, stage2_main,
                         stage1_with_refs, stage1_with_refs_legacy_alias, stage2_with_refs
  config/config.yaml     every tunable parameter (paths, k_range, refs_k_values, seeds)
  scripts/
    export_peng_reference.py   Peng et al. 2019 reference export (Stage 0 input)
    aggregate_stability.py     combines per-k stability_scores.tsv -> optimal_k.txt
```

## Prerequisites

* `snakemake` on `PATH` (already installed via pixi for this project).
* The pixi `python` global env (`~/.pixi/envs/python/bin/python` - matches
  `config.yaml`'s `python_bin`), which has pandas/numpy/scanpy. Every `xdec.py` and
  `workflow/scripts/*.py` call runs under this interpreter, not Snakemake's own.
* `tools/XDec_SM` is cloned automatically on first run if absent.

## Running it

Always run from the `progress/` directory (this pipeline's root - matches every
notebook's own working directory and all the relative paths in `config.yaml`):

```bash
cd progress
snakemake --snakefile workflow/Snakefile --cores 6
```

Preview what would run, without doing anything:

```bash
snakemake --snakefile workflow/Snakefile --cores 6 -n
```

Target a single output directly (e.g. backfill just one k instead of the whole sweep):

```bash
snakemake --snakefile workflow/Snakefile --cores 2 \
    data/deconvolution/xdec/full_sweep/k_09/stability_scores.tsv
```

## Partitioning and parallelism

**Partition axis:** one job per individual `k` in `config["k_range"]` for the Stage 0
stability sweep (`k=3..12` by default) - each its own subprocess, because
`xdec.py stage0`'s combined multi-k mode only writes `stability_scores.tsv` once the
*entire* k-range loop finishes. Partitioning means a kill loses at most the k's in
flight, not the whole sweep.

**Parallelism, controlled entirely outside this repo's code:** `--cores N` together
with `threads_per_k` in `config.yaml` (default 2, matching ~1.3 cores/worker observed
on the reference run) sets how many k's run at once:

```bash
snakemake --snakefile workflow/Snakefile --cores 6    # 3 concurrent k's
snakemake --snakefile workflow/Snakefile --cores 2    # mostly sequential
snakemake --snakefile workflow/Snakefile --cores 20   # fully parallel (all 10 k's at once)
```

Override any other config value the same way, without editing `config.yaml`:

```bash
snakemake --snakefile workflow/Snakefile --cores 6 \
    --config k_range="3,4,5" refs_k_values="3,8,9"
```

**Documented side effect of partitioning, unchanged regardless of concurrency:**
`xdec.py`'s stability-estimation RNG resets to the same `--seed` at the start of every
single-k subprocess, so each k-partition draws the same first segment of its random
sample-subsets rather than the segment it would get inside one combined
`--k-range 3,...,12` call. Stability scores from a partitioned sweep are close to, but
not bit-identical with, a single combined run - independent of how many k's run
concurrently.

## Resilience for multi-hour unattended runs

The original hand-run sweep took ~11 hours overnight and survived two interruptions
(a confirmed macOS idle-sleep kill, and one unresolved kill despite `caffeinate -i`).
This workflow replaces that run's manual try/except + hand-written `timing_log.tsv`
with:

* **Every rule's output file is itself the checkpoint.** Rerunning the same command
  after a kill only redoes what's missing - no separate resume logic.
* `--rerun-incomplete` - clean up and redo anything left half-written by a kill.
* `--keep-going` - let independent jobs (other k's) keep running past one failure
  instead of stopping everything.
* `benchmark:` directives write per-job elapsed time + peak memory automatically to
  `logs/benchmarks/*.tsv` (e.g. `logs/benchmarks/stage0_stability_k09.tsv`).
* Per-rule logs land in `logs/*.log` (stdout+stderr of the underlying `xdec.py` call).

Both `logs/` and Snakemake's own `.snakemake/` metadata cache are gitignored -
regenerate them by rerunning, don't expect them to survive a `git clone`.

### Adopting this workflow onto outputs that already exist

If `data/deconvolution/xdec/` already has outputs from before this workflow existed
(true for this repo - see `04_xdec_deconvolution.ipynb`), Snakemake's file-modification-time
checks may not match its DAG and it will want to redo everything. Register the
existing outputs as up to date once, instead of rerunning them:

```bash
snakemake --snakefile workflow/Snakefile --cores 6 --touch
```

## Scaling beyond one machine

No Snakefile changes needed: install a `snakemake-executor-plugin-<slurm/...>` and add
`--executor slurm --jobs 50` (or an equivalent `--profile` directory) to the command
line. The k-partitioned Stage 0 sweep is the embarrassingly-parallel step that
benefits most from this.
