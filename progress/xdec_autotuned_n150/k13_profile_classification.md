# XDec k=13 profile classification by reference-correlation shape

Source data: `stage1_k13/correlation.tsv` (Spearman r between each XDec profile and the 10 Run D reference cell types) and `stage1_k13/proportions.tsv` (per-sample profile proportions, n=150).

## 1. Cleanly classified to one cell type
Single dominant hit, correlation with everything else near zero.

| Profile | Match | r (top / runner-up) | Mean prop. | Max prop. | % samples >10% |
|---|---|---|---|---|---|
| Profile_9 | pancreatic ductal cell | 0.37 / 0.15 | 10.0% | 60.3% | 38.7% |
| Profile_2 | myeloid leukocyte | 0.34 / 0.17 | 3.9% | 21.7% | 4.7% |

## 2. Correlates with multiple (but not all) cell types
Ambiguous among a small handful, usually one lineage family — can't be assigned a single label.

| Profile | Candidates (r) | Mean prop. | Max prop. | % samples >10% |
|---|---|---|---|---|
| Profile_1 | fibroblast 0.40, stellate 0.32 (stromal duo) | 6.7% | 27.6% | 21.3% |
| Profile_5 | B lineage 0.34, T cell 0.32, myeloid 0.24 (lymphoid/myeloid) | 7.0% | 55.9% | 23.3% |

## 3. Correlates with nearly all cell types (broad smear, no discriminating power)

| Profile | # of 10 types r>0.1 | Top hit (r) | Mean prop. | Max prop. | % samples >10% |
|---|---|---|---|---|---|
| Profile_6 | 10/10 | ductal 0.37 | 7.1% | 45.6% | 26.0% |
| Profile_7 | 10/10 | ductal 0.35 | 8.0% | 48.9% | 29.3% |
| Profile_3 | 9/10 | fibroblast 0.38 | 2.1% | 14.6% | 3.3% |
| Profile_11 | 8/10 | myeloid 0.21 | 2.6% | 17.7% | 4.0% |
| Profile_13 | 7/10 | ductal 0.44 (highest r in whole matrix, but not discriminating) | 7.3% | 46.9% | 26.0% |

## 4. Negatively correlated with nearly all cell types

Two distinct sub-patterns here, not one — only Profile_12 is a true "ghost" with zero positive correlation anywhere. Profile_4, 8, and 10 each carry one real (if weak) positive hit sitting on a negative background; a milder failure mode.

### 4a. True ghost — no positive correlation with any reference type

| Profile | r range | Mean prop. | Max prop. | % samples >10% |
|---|---|---|---|---|
| Profile_12 | -0.18 (fibroblast) to -0.40 (T cell), **all 10 negative** | **29.9%** | **70.4%** | **86.7%** |

### 4b. Weak single-type anchor on a negative background

| Profile | Positive anchor (r) | Rest of row | Mean prop. | Max prop. | % samples >10% |
|---|---|---|---|---|---|
| Profile_10 | acinar +0.21 | 1 near-zero (enteroendocrine -0.00), 8 negative (-0.15 to -0.38) | 6.6% | 34.8% | 30.0% |
| Profile_8 | enteroendocrine +0.16 | 9 negative (-0.13 to -0.33) | 4.4% | 24.9% | 12.0% |
| Profile_4 | acinar +0.19, ductal +0.19 (tied) | 2 near-zero, 5 negative (-0.10 to -0.20) | 4.3% | 21.4% | 13.3% |

## Key takeaway

Of 13 profiles: 2 cleanly classified, 2 ambiguous within a lineage family, 5 broadly (weakly) positive across nearly all types, 3 with a single weak positive anchor on a negative background, and **only 1 true ghost (Profile_12) with no positive correlation to any reference type at all**.

**Profile_12 — the only true ghost profile in the run — is also the single largest component of the deconvolution**, averaging ~30% of sample composition and exceeding 10% in 87% of samples (vs. ~5–40% for everything else). The model's biggest signal doesn't match any reference cell type.

## Cross-validation

Unsupervised hierarchical clustering (`09_cibersortx_vs_xdec_k13_comparison.ipynb`, Figure 1) and by-eye inspection (`08_k_candidates_profile_reference_heatmaps.ipynb`) both group Profile_4, 8, 10, and 12 together as a "near-flat" / "dead profile" cluster with no label information given — consistent with the correlation data above, though that coarser grouping doesn't distinguish the true ghost (12, zero positive anywhere) from the weak single-anchor profiles (4, 8, 10, each with one real if modest positive hit). This failure mode worsens (not improves) as k increases past the reference's 10-cell-type floor.
