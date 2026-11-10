#!/usr/bin/env bash
# Runs the "with refs" Stage 1 (proportions) + Stage 2 (per-cell-type expression)
# branch of workflow/Snakefile for k=8..20, on the full 182-sample TCGA-PAAD
# cohort against the 344-gene Stage-0 probe list (see large_k_EDA/config.yaml).
#
# Only the specific k=8..20 "with refs" output files are requested as targets
# (not `snakemake ... ` with no target, which resolves to `rule all` and would
# also try to build the unrelated main Stage-0 stability sweep / non-refs
# Stage 1/2). k=8 and k=9 already exist from scripts/04_xdec_deconvolution.ipynb
# and are left untouched by Snakemake's up-to-date check; k=10..20 are new.
#
# Usage, from any directory:
#   large_k_EDA/run_large_k_sweep.sh [--cores N] [extra snakemake args...]
#   large_k_EDA/run_large_k_sweep.sh -n   # dry run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRESS_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROGRESS_DIR"

K_VALUES=(8 9 10 11 12 13 14 15 16 17 18 19 20)

TARGETS=()
for k in "${K_VALUES[@]}"; do
    TARGETS+=("data/deconvolution/xdec/stage1_with_refs_k${k}/proportions.tsv")
    TARGETS+=("data/deconvolution/xdec/stage2_with_refs_k${k}/stage2_means.tsv")
done

CORES_ARGS=(--cores 4)
if [[ "${1:-}" == "--cores" ]]; then
    CORES_ARGS=(--cores "$2")
    shift 2
fi

snakemake --snakefile workflow/Snakefile \
    --configfile large_k_EDA/config.yaml \
    "${CORES_ARGS[@]}" \
    "$@" \
    "${TARGETS[@]}"
