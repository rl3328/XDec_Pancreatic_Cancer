# progress/scripts

Pipeline notebooks for the TCGA-PAAD RNA-seq deconvolution analysis, run in order.

- `00_install_packages.ipynb` — one-time R/Bioconductor environment setup.
- `01_download_tcga_paad_rnaseq.ipynb` — query GDC and download TCGA-PAAD RNA-seq into a `SummarizedExperiment`.
- `02_build_expression_matrix.ipynb` — build flat TPM/counts/metadata matrices from the raw `SummarizedExperiment`.
- `03_qc_expression_matrix.ipynb` — QC the TPM matrix and flag samples for review.
- `04_xdec_deconvolution.ipynb`, `05_cibersortx_deconvolution.ipynb`, `06_timer_deconvolution.ipynb` — run XDec, CIBERSORTx, and TIMER independently to produce three cross-comparable deconvolution estimates.
- `07_three_tool_eda.ipynb` — cross-tool EDA comparing XDec, CIBERSORTx, and TIMER results and downstream biological interpretation.
- `08_count_tpm_sanity_check.ipynb` — sensitivity check of XDec results to raw-counts vs. TPM input.
- `09_cibersortx_reference_sanity_check.ipynb` — sensitivity check of CIBERSORTx results to its signature-matrix choice (default LM22 vs. a custom matrix built from the Peng et al. single-cell reference).
- `11_single_cell_reference_probe_validation.ipynb` — visualizes the Peng et al. single-cell reference restricted to XDec's 344 Stage-0 selected probes (heatmap sorted by cell type) and quantifies (silhouette score, cell-type-mean correlation) how well that probe set distinguishes the reference's 10 cell types.
- `archive/` — superseded/earlier versions of the above notebooks, kept for reference.
- `data/` — notebook outputs (QC tables tracked in git; raw/processed matrices gitignored).

## Sanity checks (08, 09)

Notebooks 08 and 09 are robustness checks on the primary pipeline (04-07) — they do not change it. Both conclude the primary pipeline's choices (XDec on raw counts, CIBERSORTx on LM22) are the right ones to keep.

- **08** — *Aim:* does using TPM or raw counts as XDec's bulk input change its Stage-1 proportions and Stage-2 DE/pathway conclusions? *Conclusion:* yes, input unit matters and is not interchangeable — e.g. the Lymphocyte profile's end-to-end DE signal collapses from 74 to 5 genes (zero overlap) under TPM, while the Enteroendocrine profile stays robust (actually gains genes). XDec continues to run on raw counts (notebook 04).
- **09** — *Aim:* does swapping CIBERSORTx's default LM22 signature matrix for a custom one built from XDec's own Peng single-cell reference improve or change cross-tool agreement? *Conclusion:* no — the Peng-reference run fails to recover its own cell type's expected biology on every axis tested (lymphoid, myeloid, fibroblast/CAF, enteroendocrine), with a specific cross-wired pattern (e.g. its "lymphoid" split recovers a neuroendocrine signature instead). Increasing the reference's cells-per-class cap (300→700) and checking TPM-as-input (via notebook 08) both substantially rule out those as the cause, pointing instead to the custom signature-matrix construction itself. CIBERSORTx continues to run on LM22 (notebook 05, used as primary in notebook 07).
