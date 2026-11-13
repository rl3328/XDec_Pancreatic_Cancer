#!/usr/bin/env bash
# Manual-track counterpart to xdec_autotuned_n150/run_pipeline.sh's "stage12" phase.
# Runs xdec.py stage1 (with refs) + stage2 at k=13,16,17, using the exact same
# inputs as the existing manual k=9 Run D run in 03_paper_style_reference_processing.ipynb
# (stage1_with_refs_k9_n150_paperGenes_pseudobulkRaw): n=150 bulk, paper's 282-gene
# Table S3 list, Run D raw pseudobulk reference. Output directories follow that
# same "_n150_paperGenes_pseudobulkRaw" naming convention, just with k swapped in,
# so this track lives alongside the existing k=9 manual run in data/deconvolution/xdec/.
#
# Checkpointed per k (skip if output already exists) -- same lesson as
# xdec_autotuned_n150/run_pipeline.sh after repeated kills of long single-shot runs.
#
# Usage, from any directory:
#   paper_duplication/run_manual_k_candidates.sh 13 16 17

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRESS_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROGRESS_DIR"

PYTHON_BIN=python3
XDEC_SCRIPT="tools/XDec_SM/python/xdec.py"
XDEC_DIR="data/deconvolution/xdec"

BULK="$XDEC_DIR/TCGA-PAAD_counts_raw_n150.tsv"
PROBES="$XDEC_DIR/gene_lists/xdec_chi_table_s3_genes.txt"
REFS="$XDEC_DIR/paper_style_ref/refs_pseudobulk_raw.tsv"
REF_METADATA="$XDEC_DIR/paper_style_ref/ref_metadata_pseudobulk_raw.tsv"

mkdir -p logs

K_VALUES=("$@")
if [[ ${#K_VALUES[@]} -eq 0 ]]; then
    echo "Usage: $0 k1 [k2 ...]" >&2
    exit 1
fi

for k in "${K_VALUES[@]}"; do
    s1_dir="$XDEC_DIR/stage1_with_refs_k${k}_n150_paperGenes_pseudobulkRaw"
    s2_dir="$XDEC_DIR/stage2_with_refs_k${k}_n150_paperGenes_pseudobulkRaw"
    mkdir -p "$s1_dir" "$s2_dir"

    if [[ ! -f "$s1_dir/cell_type_profiles.tsv" ]]; then
        echo "[k=$k] stage1 (with refs, manual track) ..."
        "$PYTHON_BIN" "$XDEC_SCRIPT" stage1 \
            --bulk "$BULK" --probes "$PROBES" \
            --refs "$REFS" --ref-metadata "$REF_METADATA" \
            --k "$k" --outdir "$s1_dir" \
            > "logs/manual_stage1_k${k}_n150_paperGenes_pseudobulkRaw.log" 2>&1
    else
        echo "[k=$k] stage1 output already exists, skipping."
    fi

    if [[ ! -f "$s2_dir/stage2_means.tsv" ]]; then
        echo "[k=$k] stage2 ..."
        "$PYTHON_BIN" "$XDEC_SCRIPT" stage2 \
            --bulk-counts "$BULK" \
            --proportions "$s1_dir/proportions.tsv" \
            --outdir "$s2_dir" \
            > "logs/manual_stage2_k${k}_n150_paperGenes_pseudobulkRaw.log" 2>&1
    else
        echo "[k=$k] stage2 output already exists, skipping."
    fi
done
