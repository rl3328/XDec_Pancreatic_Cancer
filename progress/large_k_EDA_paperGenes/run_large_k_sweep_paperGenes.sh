#!/usr/bin/env bash
# Runs the "with refs" Stage 1 (proportions) + Stage 2 (per-cell-type expression)
# step of the XDec CLI for k=10..20, on the full 182-sample TCGA-PAAD cohort and
# the same Peng et al. reference as large_k_EDA/run_large_k_sweep.sh, but against
# XDec-CHI's own 283-gene Table S3 probe list (282 symbols recovered,
# data/deconvolution/xdec/gene_lists/xdec_chi_table_s3_genes.txt) instead of this
# project's 344-gene Stage-0 list.
#
# Calls tools/XDec_SM/python/xdec.py directly (the same CLI workflow/Snakefile
# wraps) rather than through Snakemake: the Snakefile hardcodes its "with refs"
# output paths as data/deconvolution/xdec/stage{1,2}_with_refs_k{k}/, with no
# gene-list-aware naming, so running it with a different probes file at the same
# k would silently overwrite the existing 344-gene k=10..20 results. Each run here
# instead writes to a "_paperGenes"-suffixed sibling directory, matching the
# convention already used for the n=150 paper-gene reruns in
# paper_duplication/01_artifact_diagnosis.ipynb.
#
# Usage, from any directory:
#   large_k_EDA_paperGenes/run_large_k_sweep_paperGenes.sh          # run
#   large_k_EDA_paperGenes/run_large_k_sweep_paperGenes.sh -n       # dry run: print commands only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRESS_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROGRESS_DIR"

PYTHON_BIN="python3"
XDEC_SCRIPT="tools/XDec_SM/python/xdec.py"
XDEC_DIR="data/deconvolution/xdec"

BULK_COUNTS="data/processed/TCGA-PAAD_counts_raw.tsv"
PROBES="$XDEC_DIR/gene_lists/xdec_chi_table_s3_genes.txt"
REFS="$XDEC_DIR/refs.tsv"
REF_METADATA="$XDEC_DIR/ref_metadata.tsv"

K_VALUES=(10 11 12 13 14 15 16 17 18 19 20)

DRY_RUN=false
if [[ "${1:-}" == "-n" ]]; then
    DRY_RUN=true
fi

mkdir -p logs

for k in "${K_VALUES[@]}"; do
    s1_dir="$XDEC_DIR/stage1_with_refs_k${k}_paperGenes"
    s2_dir="$XDEC_DIR/stage2_with_refs_k${k}_paperGenes"

    s1_cmd=("$PYTHON_BIN" "$XDEC_SCRIPT" stage1 --bulk "$BULK_COUNTS" \
        --probes "$PROBES" --refs "$REFS" --ref-metadata "$REF_METADATA" \
        --k "$k" --outdir "$s1_dir")
    s2_cmd=("$PYTHON_BIN" "$XDEC_SCRIPT" stage2 --bulk-counts "$BULK_COUNTS" \
        --proportions "$s1_dir/proportions.tsv" --outdir "$s2_dir")

    if $DRY_RUN; then
        printf '%q ' "${s1_cmd[@]}"; echo
        printf '%q ' "${s2_cmd[@]}"; echo
        continue
    fi

    mkdir -p "$s1_dir" "$s2_dir"

    if [[ ! -f "$s1_dir/cell_type_profiles.tsv" ]]; then
        echo "[k=$k] Stage 1 (with refs, Table S3 genes) ..."
        "${s1_cmd[@]}" > "logs/stage1_with_refs_k${k}_paperGenes.log" 2>&1
    else
        echo "[k=$k] Stage 1 output already exists, skipping."
    fi

    if [[ ! -f "$s2_dir/stage2_means.tsv" ]]; then
        echo "[k=$k] Stage 2 (with refs, Table S3 genes) ..."
        "${s2_cmd[@]}" > "logs/stage2_with_refs_k${k}_paperGenes.log" 2>&1
    else
        echo "[k=$k] Stage 2 output already exists, skipping."
    fi
done
