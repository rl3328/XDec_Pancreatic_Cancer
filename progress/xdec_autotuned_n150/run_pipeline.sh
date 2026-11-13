#!/usr/bin/env bash
# Fresh end-to-end XDec run: n=150 PanCanAtlas cohort, Run D pseudobulk
# reference (refs_pseudobulk_raw.tsv -- methodologically-sound pseudobulk,
# raw/untransformed, letting xdec.py do its own joint quantile normalization +
# Equation-1 transform), paper's 282-gene Table S3 probe list.
#
# Two phases, run separately on purpose:
#   1. stage0 stability sweep across the full paper-discussed k range (3..20)
#      to get a real optimal_k recommendation instead of assuming k=9.
#   2. stage1 (with refs) + stage2, run only at the k value(s) chosen after
#      inspecting phase 1's output -- NOT blindly across the whole k-range --
#      because the "with refs" step is the expensive one (a prior k=10..20
#      sweep of this step alone took ~8.5h) and a previous attempt at a
#      single long-running multi-k stage0 call silently lost all output on
#      crash. Each stage1/stage2 call below is checkpointed independently by
#      output-file existence, same pattern as large_k_EDA_paperGenes/.
#
# Usage, from any directory:
#   xdec_autotuned_n150/run_pipeline.sh stage0           # phase 1 only
#   xdec_autotuned_n150/run_pipeline.sh stage12 9 12 15   # phase 2, at these k's

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRESS_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROGRESS_DIR"

PYTHON_BIN=python3
XDEC_SCRIPT="tools/XDec_SM/python/xdec.py"
OUTROOT="xdec_autotuned_n150"

BULK="data/deconvolution/xdec/TCGA-PAAD_counts_raw_n150.tsv"
PROBES="data/deconvolution/xdec/gene_lists/xdec_chi_table_s3_genes.txt"
REFS="data/deconvolution/xdec/paper_style_ref/refs_pseudobulk_raw.tsv"
REF_METADATA="data/deconvolution/xdec/paper_style_ref/ref_metadata_pseudobulk_raw.tsv"

mkdir -p "$OUTROOT/logs"

phase="${1:-}"

if [[ "$phase" == "stage0" ]]; then
    # Per-k checkpointing: cmd_stage0() only writes stability_scores.tsv /
    # optimal_k.txt after its *entire* --k-range loop finishes, so a single
    # call spanning k=3..20 loses all progress if killed partway through
    # (this happened twice: a 2026-11-08 crash, and this run killed mid-k=7).
    # Instead, call stage0 once per k, each into its own stage0/k_XX/ dir,
    # skipped if that dir's stability_scores.tsv already exists -- then
    # aggregate all k's into a single stage0/stability_scores.tsv +
    # optimal_k.txt at the end, matching what downstream phase2 expects.
    mkdir -p "$OUTROOT/stage0"
    K_VALUES=(3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20)

    for k in "${K_VALUES[@]}"; do
        kdir="$OUTROOT/stage0/k_$(printf '%02d' "$k")"
        mkdir -p "$kdir"
        if [[ -f "$kdir/stability_scores.tsv" ]]; then
            echo "[stage0 k=$k] already done, skipping."
            continue
        fi
        echo "[stage0 k=$k] stability estimation (n=150, Table S3 genes) ..."
        "$PYTHON_BIN" "$XDEC_SCRIPT" stage0 \
            --bulk "$BULK" \
            --probes "$PROBES" \
            --k-range "$k" \
            --subset-prop 0.8 --num-subsets 1 --reps 2 \
            --outdir "$kdir" \
            > "$OUTROOT/logs/stage0_k${k}.log" 2>&1
        echo "[stage0 k=$k] done."
    done

    # Aggregate per-k results into a single stability_scores.tsv + optimal_k.txt
    "$PYTHON_BIN" - "$OUTROOT/stage0" "${K_VALUES[@]}" <<'PYEOF'
import sys, os
outdir = sys.argv[1]
k_values = sys.argv[2:]
rows = []
for k in k_values:
    kdir = os.path.join(outdir, f"k_{int(k):02d}")
    path = os.path.join(kdir, "stability_scores.tsv")
    with open(path) as fh:
        next(fh)  # header
        _, score = next(fh).strip().split("\t")
    rows.append((int(k), float(score)))
rows.sort()
with open(os.path.join(outdir, "stability_scores.tsv"), "w") as fh:
    fh.write("k\tstability_score\n")
    for k, score in rows:
        fh.write(f"{k}\t{score}\n")
best_k, best_score = max(rows, key=lambda r: r[1])
with open(os.path.join(outdir, "optimal_k.txt"), "w") as fh:
    fh.write(f"{best_k}\n")
print(f"Recommended k = {best_k}  (stability={best_score:.4f})")
PYEOF
    cat "$OUTROOT/stage0/optimal_k.txt"

elif [[ "$phase" == "stage12" ]]; then
    shift
    K_VALUES=("$@")
    if [[ ${#K_VALUES[@]} -eq 0 ]]; then
        echo "Usage: $0 stage12 k1 [k2 ...]" >&2
        exit 1
    fi
    for k in "${K_VALUES[@]}"; do
        s1_dir="$OUTROOT/stage1_k${k}"
        s2_dir="$OUTROOT/stage2_k${k}"
        mkdir -p "$s1_dir" "$s2_dir"

        if [[ ! -f "$s1_dir/cell_type_profiles.tsv" ]]; then
            echo "[k=$k] stage1 (with refs) ..."
            "$PYTHON_BIN" "$XDEC_SCRIPT" stage1 \
                --bulk "$BULK" --probes "$PROBES" \
                --refs "$REFS" --ref-metadata "$REF_METADATA" \
                --k "$k" --outdir "$s1_dir" \
                > "$OUTROOT/logs/stage1_k${k}.log" 2>&1
        else
            echo "[k=$k] stage1 output already exists, skipping."
        fi

        if [[ ! -f "$s2_dir/stage2_means.tsv" ]]; then
            echo "[k=$k] stage2 ..."
            "$PYTHON_BIN" "$XDEC_SCRIPT" stage2 \
                --bulk-counts "$BULK" \
                --proportions "$s1_dir/proportions.tsv" \
                --outdir "$s2_dir" \
                > "$OUTROOT/logs/stage2_k${k}.log" 2>&1
        else
            echo "[k=$k] stage2 output already exists, skipping."
        fi
    done

else
    echo "Usage: $0 stage0 | stage12 k1 [k2 ...]" >&2
    exit 1
fi
