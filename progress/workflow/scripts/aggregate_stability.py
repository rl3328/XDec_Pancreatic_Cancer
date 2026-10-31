#!/usr/bin/env python
"""Combine per-k stability_scores.tsv files from the partitioned stage0 sweep
into one table, and pick optimal_k by argmax stability_score."""
import argparse

import pandas as pd


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--stab-files", nargs="+", required=True)
    p.add_argument("--combined-out", required=True)
    p.add_argument("--optimal-k-out", required=True)
    args = p.parse_args()

    all_stab = pd.concat([pd.read_csv(f, sep="\t") for f in args.stab_files], ignore_index=True)
    all_stab = all_stab.sort_values("k").reset_index(drop=True)
    all_stab.to_csv(args.combined_out, sep="\t", index=False)

    optimal_k = int(all_stab.loc[all_stab["stability_score"].idxmax(), "k"])
    with open(args.optimal_k_out, "w") as fh:
        fh.write(str(optimal_k) + "\n")

    print(f"Recommended k = {optimal_k} (stability = {all_stab['stability_score'].max():.4f})")
    print(all_stab.to_string(index=False))


if __name__ == "__main__":
    main()
