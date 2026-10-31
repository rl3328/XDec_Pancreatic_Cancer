#!/usr/bin/env python
"""Export Peng et al. 2019 (Zenodo 3969339) single-cell reference to XDec's --refs/--ref-metadata TSVs.

adata.raw.X is natural-log-normalized (ln(x+1)), not log2(x+1), so it needs
expm1() here rather than XDec's --log2-refs (which inverts log2(x+1)
specifically); run XDec on the resulting TSV without --log2-refs.
"""
import argparse

import numpy as np
import pandas as pd
import scanpy as sc


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--h5ad", required=True)
    p.add_argument("--class-col", default="celltype1")
    p.add_argument("--max-cells-per-class", type=int, default=300)
    p.add_argument("--seed", type=int, default=1)
    p.add_argument("--refs-out", required=True)
    p.add_argument("--meta-out", required=True)
    args = p.parse_args()

    adata = sc.read_h5ad(args.h5ad)
    rng = np.random.default_rng(args.seed)

    classes = adata.obs[args.class_col].astype(str)
    keep_names = []
    for cls, names in classes.groupby(classes).groups.items():
        names = np.array(names)  # cell barcodes (obs_names), not positional indices
        n = min(args.max_cells_per_class, len(names))
        keep_names.extend(rng.choice(names, size=n, replace=False))

    sub_raw = adata.raw[keep_names]
    counts_like = np.expm1(sub_raw.X)
    try:
        counts_like = counts_like.toarray()
    except AttributeError:
        pass
    counts_like = np.asarray(counts_like)
    counts_like[counts_like < 0] = 0.0  # guard against floating-point noise below zero

    cells = pd.Index(keep_names)
    refs_df = pd.DataFrame(counts_like.T, index=sub_raw.var_names, columns=cells)
    refs_df.index.name = "Genes"
    refs_df.to_csv(args.refs_out, sep="\t")

    meta_df = pd.DataFrame({"Sample_ID": cells, "Cell_Type": classes.loc[cells].values})
    meta_df.to_csv(args.meta_out, sep="\t", index=False)

    print(f"Wrote {refs_df.shape[0]} genes x {refs_df.shape[1]} cells -> {args.refs_out}")
    print(meta_df["Cell_Type"].value_counts().to_string())


if __name__ == "__main__":
    main()
