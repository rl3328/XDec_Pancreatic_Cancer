# Code and analysis review — 2026-10-31

## Assessment
The directory organization is understandable, but the current downstream findings should be treated as exploratory. The code and saved outputs do not establish independent biological replication or calibrated differential-expression significance. No analysis code or existing results were changed during this review.

## Scope and structure
Reviewed notebooks 00–07, archived notebooks, the Snakemake workflow/config/helper scripts, the comparison script, and the relevant XDec/TIMER implementation paths. Checked saved proportions, DE tables, sample matching, stability scores and raw-count library sizes. This was not a full audit of every unrelated GUI/reference module in the vendored XDec application, nor a rerun of downloads or the multi-hour factorization.

- `progress/scripts/rnaseq_download/`: acquisition, matrix building, QC, three tools, downstream EDA. The nested `progress/` root is intentional.
- `progress/workflow/`: automated XDec reference export and stages 0–2. It does not automate acquisition, TIMER, CIBERSORTx or the full EDA.
- `progress/data/`: inputs, derived matrices, QC and outputs; raw/processed directories are ignored.
- `progress/tools/`: nested third-party repositories; currently untracked in the parent repository, with a modified TIMER `utils.r`.
- Root README is only a title; CLAUDE.md incorrectly says progress itself is untracked and all notebooks use R. Actual notebooks/workflow are tracked, and 04/05/07 use Python.

## Findings, ordered by importance

### 1. High — gene-level significance has no multiple-testing correction
Location: notebook 07, cells 19, 28 and 35.
All three DE analyses select `pval < 0.05` plus a fivefold pseudocount-based effect threshold, across tens of thousands of genes. No gene-level BH/FDR adjustment is performed. GO/KEGG BH adjustment does not correct this earlier selection. Large effect sizes do not themselves establish controlled FDR. Save complete tested-gene tables, calculate adjusted p-values over the full valid test set, and recompute DE/enrichment. Adjusting only the saved significant-gene tables would be incorrect.

### 2. High — Stage 2 fits unnormalized sequencing counts
Locations: notebook 04 cells 16/20; notebook 07 cell 19; workflow rules stage2_main/stage2_with_refs; `tools/XDec_SM/python/xdec.py` run_stage2, lines 1103–1135.
The pipeline passes STAR unstranded raw counts. Stage 2 fits B = P M with no library-size factor or offset. Checked library sizes span 19,381,044–85,532,339 reads, about 4.4-fold. Consequently estimated expression can absorb sequencing depth. The source also describes inverse-log RPKM as counts, so input-unit terminology is unreliable. Establish a justified linear expression scale for this deconvolution step and compare results under appropriate normalization. Conventional count-based DE models should receive raw counts and handle depth internally; do not feed normalized noninteger expression to a model that expects counts.

### 3. High — same-data agreement is described as independent replication
Location: notebook 07 opening conclusions and Section 5.
All scores derive from the same bulk cohort, and genes from that same expression matrix are then tested after grouping by those scores. This creates selection dependence; expected immune-marker enrichment is evidence of internal consistency, not independent validation. XDec Stage 0 also uses the reference that supports subsequent identity interpretation. Different algorithms do not make the biological evidence independent. Use held-out genes/donors, another cohort, pathology or orthogonal measurements to support stronger validation claims. The claimed explanation of 584 → 158 → 37 genes as progressively greater dilution is not demonstrated: scores, groups, expression units and test models differ.

### 4. High — notebook 07 is not executable end to end
Location: cells 27–29 and 34–36.
Notebook metadata specifies a Python kernel, but these six code cells contain plain R with no execution bridge. Python syntax parsing fails for all six. Switching kernels loses Python state and makes later Python cells fail; TIMER R cells additionally reference `score_path` and `timer_outdir` without defining them in this notebook. Saved outputs were pasted from external executions according to the notebook text. Move the R sections to an R notebook or explicitly run self-contained R scripts/cells through a bridge, then validate in a fresh kernel.

### 5. High — narrative contradicts saved results
Location: notebook 07, final markdown cell 41 and summary text.
Confirmed actual XDec Profile_5 DE table: 584 genes = 276 up-high + 308 up-low. Section 5 instead describes XDec up-low as a clean zero. TIMER is 158 = 152 + 6; CIBERSORTx is 37 = 36 + 1. The summary chart hardcodes these counts, so it can silently become stale after changes. Derive counts and prose from saved current results and remove unsupported statements about the low side.

### 6. Medium/high — XDec uncertainty is conditional and approximate
Locations: notebook 07 cell 19; xdec.py run_stage2.
The normal z-test uses OLS-style errors from an NNLS fit as if Stage-1 proportions and the chosen high/low grouping were known. It does not propagate uncertainty in estimated proportions, selection or boundary-constrained coefficients. The low-tertile designs are less well-conditioned: condition numbers are about 30/36/55 for Profiles 2/5/8, versus 17/15/21 in high tertiles. This is not proof of failure, but makes uncertainty/sensitivity important. Bootstrap the full fitting/grouping procedure and check stability before treating these p-values as calibrated.

### 7. Medium — caches can silently reuse results from different inputs
Locations: notebook 04 existence guards; notebook 05 cell 3; notebook 06 score-file guard; notebook 07 cells 18/19/28/35.
Results are skipped based solely on file existence, without input hashes or parameters. For example, changing proportions leaves existing tertile metadata and Stage-2 means in place. Notebook 07 may calculate current DE in memory but preserve old DE files, producing inconsistent plots/enrichment. The CIBERSORTx mixture copy similarly stays unchanged if its source changes. Use tracked dependencies or explicit input/parameter manifests and validate every required output, not only the means file. Fail subprocess calls on nonzero exit status.

### 8. Medium — enrichment can hide failures and use inconsistent backgrounds
Location: notebook 07 R enrichment cells 29/36 and plotting helpers.
GO gets a full-matrix symbol universe, including unexpressed/untested rows; KEGG receives no explicit tested-gene universe. Errors are caught and converted to NULL and missing output files are plotted as no significant terms. Thus a network/annotation/computation failure can look like a negative biological result. Distinguish failed, not run and successfully empty results; use the eligible tested universe mapped consistently to each annotation system. The current notebook also plots pre-existing XDec enrichment TSVs without including their generating analysis code, preventing complete regeneration.

### 9. Medium — tool scores answer different questions
Location: comparison script and notebook 07 Section 1.
CIBERSORTx relative LM22 fractions describe composition within modeled immune cells; TIMER scores and XDec fractions/proxies have different denominators and coverage. CIBERSORTx lymphoid and myeloid totals are complements. Lymphoid lists also differ because CIBERSORTx includes NK. These correlations cannot establish absolute cell-fraction accuracy. Section 1 includes four normal samples paired to tumor patients and does not adjust correlations for sample type/site/purity. Report tumor-only sensitivity and matched biological definitions, then directly assess the k=8 lymphocyte profile used in the biological claims.

### 10. Medium — provenance and workflow portability are incomplete
Locations: workflow Snakefile/config/README; notebooks 00/05/06.
Git clones use mutable default branches, dependencies use shared global environments, and the single-cell reference has no enforced checksum/normalization assertion. CIBERSORTx exact settings are explicitly missing. TIMER is locally patched. Record tool commits, package versions, input checksums, web-job parameters and patches. The documented `--config k_range="3,4,5" refs_k_values="3,8,9"` override is incompatible with the Snakefile comprehensions: string values iterate character-by-character and conversion of comma to int fails. Parse strings or document JSON/YAML list syntax. Helper scripts are called in shell strings but not declared as rule inputs, so edits may not invalidate cached results. The recommendation to adopt old outputs using `--touch` requires provenance verification first.

### 11. Medium — batch and cohort interpretation remain unresolved
Location: notebook 03 batch check and later DE models.
The QC report compares unadjusted R-squared across factors with different numbers of levels and a very imbalanced tumor/normal split. This alone does not prove a technical batch effect. Later DE tests do not adjust for site, purity or grade. Confirm histologic eligibility for a PDAC-specific claim rather than assuming every PAAD sample is ductal adenocarcinoma. Assess confounding with an explicit design and sensitivity analyses. The QC prose also equates TPM normalization with the role of quantile normalization; those operations are not equivalent.

## Verified checks
- XDec stage1 outputs each have 182 unique sample IDs, finite nonnegative fractions, and row sums within 2.3e-16 of one.
- Saved merged comparison has 182 unique samples and no missing scores.
- Recomputed CIBERSORTx/TIMER lymphoid Pearson r = 0.5345242, p = 7.73275e-15, consistent with the reported approximate correlation.
- All ten saved k results exist; k=3 stability = 1.0 versus k=8 = 0.999548. Near-equality does not establish k=8 as the unique biological answer.
- Confirmed saved DE counts and the six incompatible notebook cells described above.
- Default Snakemake dry-run successfully built the DAG and reported existing requested outputs up to date; clone_xdec has missing provenance metadata. This validates scheduling against present outputs, not clean execution.
- No full download/factorization/DE rerun was performed; saved numerical consistency does not establish statistical validity.

## Recommended order
1. Repair executable notebook structure and provenance; retain old results with a manifest.
2. Resolve Stage-2 expression units and depth sensitivity.
3. Refit appropriate DE models, save all tests and apply gene-level FDR; define enrichment universes and explicit error states.
4. Replace independent-replication claims with internal concordance pending orthogonal validation; regenerate tables, charts and narrative together.

Statistical references: [Bioconductor RNA-seq workflow](https://www.bioconductor.org/packages/devel/workflows/vignettes/rnaseqGene/inst/doc/rnaseqGene.html), [statsmodels multiple-testing documentation](https://www.statsmodels.org/stable/generated/statsmodels.stats.multitest.multipletests.html).
