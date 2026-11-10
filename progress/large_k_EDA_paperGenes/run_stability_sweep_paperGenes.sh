#!/usr/bin/env bash
# Runs XDec's stability analysis (stage0, no refs) for k=10..20 on the Table S3
# gene list, to get a stability-score-based recommendation for k alongside the
# reference-anchored correlation/coverage diagnostics in
# 02_visualization_large_k_paperGenes.ipynb.
#
# At default settings (3 subsets x 3 reps = 9 Stage-1 reruns per k) this would
# cost roughly 9x the ~8.5h total wall-clock the k=10..20 "with refs" sweep
# (run_large_k_sweep_paperGenes.sh) already took -- multiple days. Per the
# user's choice, this instead uses --num-subsets 1 --reps 2 (2 reruns per k,
# ~4.5x cheaper) as a reduced-but-real stability signal.
#
# Writes to data/deconvolution/xdec/full_sweep_paperGenes/ (separate from the
# existing 344-gene full_sweep/ directory).
#
# Usage, from any directory:
#   large_k_EDA_paperGenes/run_stability_sweep_paperGenes.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRESS_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROGRESS_DIR"

PYTHON_BIN="python3"
XDEC_SCRIPT="tools/XDec_SM/python/xdec.py"
XDEC_DIR="data/deconvolution/xdec"

BULK_COUNTS="data/processed/TCGA-PAAD_counts_raw.tsv"
PROBES="$XDEC_DIR/gene_lists/xdec_chi_table_s3_genes.txt"
OUTDIR="$XDEC_DIR/full_sweep_paperGenes"

mkdir -p logs "$OUTDIR"

"$PYTHON_BIN" "$XDEC_SCRIPT" stage0 \
    --bulk "$BULK_COUNTS" \
    --probes "$PROBES" \
    --k-range "10,11,12,13,14,15,16,17,18,19,20" \
    --subset-prop 0.8 \
    --num-subsets 1 \
    --reps 2 \
    --outdir "$OUTDIR" \
    > logs/stage0_stability_paperGenes.log 2>&1

echo "Done. See $OUTDIR/stability_scores.tsv and $OUTDIR/optimal_k.txt"
