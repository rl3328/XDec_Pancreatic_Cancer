# TCGA-PAAD sample filtering: why XDec-CHI used n=149 and this repo's raw cohort is n=182

## Source of the discrepancy

This repo's `data/processed/TCGA-PAAD_counts_raw.tsv` (built in `scripts/02_build_expression_matrix.ipynb`)
is the **full, unfiltered** set of TCGA-PAAD RNA-seq cases available from GDC: **182 samples**.

XDec-CHI (LaPlante et al. 2022, iScience) ran XDec on **n=149** TCGA-PAAD samples. Its STAR Methods
("Processing RNA-seq datasets") states:

> "TCGA PAAD level 3 RNA-seq dataset was downloaded from UCSC Xena (Goldman et al., 2019) for samples not
> flagged during review (Raphael et al., 2017)."

"Raphael et al., 2017" is the TCGA PanCanAtlas PAAD marker paper — *Integrated Genomic Characterization of
Pancreatic Ductal Adenocarcinoma*, Cancer Cell 32(2):185-203.e13, [doi:10.1016/j.ccell.2017.07.007](https://doi.org/10.1016/j.ccell.2017.07.007)
(PMID 28810144, PMC5964983). That paper's own pathology/molecular QC pipeline is the actual origin of the
"flagged during review" filter — it is a generic TCGA PanCanAtlas QC step, not something PDAC- or
XDec-specific.

## The filtering chain (from Raphael et al. 2017 Methods)

**410 submitted cases → 185 "qualified" for genomic analysis → 150 "evaluable primary tumors"**

### Step 1: 410 → 185 (225 excluded)

| Reason | Count |
|---|---|
| Disqualified prior to processing | 25 |
| Failed pathology screening | 16 |
| — absence of tumor cells | (12 of the 16) |
| — necrosis | (1 of the 16) |
| — contaminating tumor DNA in matched germline/normal control | (3 of the 16) |
| Failed molecular QC | 175 |
| — RNA integrity score < 7.0 | (143 of the 175) |
| — insufficient DNA/RNA yield | (32 of the 175) |
| Genotype mismatch (sample-swap/contamination check) | 9 |

### Step 2: 185 → 150 (35 excluded)

Confirmed in the paper: **9 samples were held out for < 1% neoplastic cellularity** on central pathology
re-review (final cohort's cellularity ranges 0-53%, median 18%). The remaining ~26 of the 35-sample gap are
not itemized in the main text available to us — they are most likely broken out in that paper's
Supplementary Table S1 (sample-level QC flags), which we have not pulled. **Do not assume a specific reason
(e.g. "non-ductal histology") for those ~26 without checking that table — this doc intentionally does not
guess.**

### XDec-CHI's n=149 vs. the marker paper's n=150

XDec-CHI's n=149 is one less than the marker paper's 150-sample QC'd cohort. The paper does not explain the
extra exclusion; the most likely explanation is a single sample missing from the specific UCSC Xena Level-3
RNA-seq pull (a data-source availability gap), not an additional described QC step.

## Operational definition used in this repo

Rather than re-deriving the Raphael et al. QC criteria from raw GDC data (which would require re-running
their pathology/RNA-QC pipeline), this repo uses the **molecular subtype table that paper itself published**
as the operational definition of "the 150": it is pulled via `TCGAbiolinks::TCGAquery_subtype(tumor = "paad")`,
which ships (offline, no network call) a curated copy of each TCGA marker paper's supplementary subtype
table. For PAAD this is exactly the Raphael et al. 2017 table — confirmed by the function's own printed
citation, `doi:10.1016/j.ccell.2017.07.007`.

* Script: `data/deconvolution/xdec/subtypes/pull_paad_subtypes.R` (run via the `r-base` pixi env's `Rscript`)
* Output: `data/deconvolution/xdec/subtypes/paad_panCanAtlas_subtypes.tsv` — 150 rows, columns
  `tumor_sample_id, moffitt_cluster (Basal/Classical), bailey_cluster (Squamous/Immunogenic/Progenitor/ADEX),
  collisson_cluster (Classical/Exocrine/QM), absolute_purity, purity_class`.
* Barcode matching: `tumor_sample_id` is a 16-character barcode (`TCGA-XX-XXXX-XXX`, participant + sample/vial,
  no portion/plate/center suffix). This repo's cohort barcodes (e.g.
  `TCGA-IB-7888-01A-11R-2156-07`) are truncated to their first 16 characters before matching.
* Verified overlap: **150/150** of this table's barcodes are present in this repo's 182-sample raw cohort
  (truncated-barcode match) — i.e. the marker-paper's QC'd cohort is a strict subset of this repo's raw
  185 download; the 32 extra samples in this repo (182 - 150) are exactly the ones Raphael et al. flagged out
  (or occasionally added later to GDC without having gone through the same 2017-era QC) but are still present
  in a generic, unfiltered GDC query.

## Follow-up: Profile_7 artifact check (n=150/k=9)

`01_restrict_to_panCanAtlas_cohort_k9.ipynb`'s Step 5 re-checks, directly on this n=150/k=9 run, the three
signals notebook 07 used to flag Profile_7 (at the original n=182/k=8) as an NNLS boundary-solution artifact
rather than a real cell type: near-zero prevalence, broad (non-specific) reference correlation, and zero-floor
DE genes in a confusable partner profile. Two of three signals replicate essentially unchanged; the third
replicates the same *mechanism* but with different specific genes (epithelial/secretory + glycolytic
housekeeping here vs. ribosomal proteins in the original run) - see that notebook for the full breakdown.

## What this is used for

`restrict_to_panCanAtlas_cohort_k9.ipynb` in this folder uses `tumor_sample_id` to subset the bulk counts
matrix down to these 150 samples, then reruns XDec Stage 1 (with refs) and Stage 2 at k=9 — the same k the
paper's own stability procedure selected for TCGA — to check whether removing the 32 QC-flagged samples
changes whether the cancer-epithelial compartment resolves into two separate profiles (Classical vs.
Basal-like), as it did in the paper, rather than the single ambiguous profile seen on the full n=182 cohort.
XDec outputs from this rerun are saved alongside the existing n=182 runs in `data/deconvolution/xdec/`
(`stage1_with_refs_k9_n150/`, `stage2_with_refs_k9_n150/`), not duplicated into this folder.
