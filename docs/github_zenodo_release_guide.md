# GitHub + Zenodo Release Guide

This document walks you through publishing this repository on GitHub and
minting a citable DOI through Zenodo. Follow Section 1 first, then
Section 2.

---

## Prerequisites

- A GitHub account (free): <https://github.com/join>
- A Zenodo account (free, sign in with GitHub or ORCID): <https://zenodo.org/signup>
- Git installed locally: <https://git-scm.com/downloads>
- (Optional) GitHub CLI: <https://cli.github.com/>

Verify Git is configured with your name and email:

```bash
git config --global user.name  "Gyobeom Kim"
git config --global user.email "asaph0301@gmail.com"
```

---

## Section 1 — Publishing the Repository on GitHub

### 1.1 Final pre-flight check (local)

This repository is structured so that restricted data lives **outside**
the repo, in a sibling folder `../data_local/`. The expected layout is:

```
260506_JEMA/
├── Code_Data_for_GitHub/   ← THIS folder is what gets pushed to GitHub
│   ├── README.md, LICENSE, R_session_info.txt, .gitignore
│   ├── scripts/
│   ├── data_examples/
│   └── docs/
└── data_local/             ← Restricted CSVs — never pushed
    ├── ND2024_catch.csv
    ├── ND2024_raw.csv
    └── ...
```

From `Code_Data_for_GitHub/`, verify the structure and that no
restricted data will be uploaded:

```bash
cd "F:/Work/250901_Ch.3_AEHI_2023/260506_JEMA/Code_Data_for_GitHub"
ls -la
```

Expected to ship:
- `README.md`, `LICENSE`, `R_session_info.txt`, `.gitignore`
- `scripts/` (7 R scripts)
- `data_examples/` (3 files: dictionary, classification criteria, template)
- `docs/` (3 markdown guides)

Expected to be ignored by `.gitignore` (will not appear in the repo):
- `data/`, `data_local/` (defensive — restricted data lives in a sibling folder)
- `TDI_*`, `BMI_*`, `FAI_*`, `Table*_*.csv`, `Rplots.pdf` (script outputs)
- `test_outputs/`

Sanity check before pushing — these commands must return EMPTY output:

```bash
git ls-files | grep -iE "ND2024|data_sem|landuse_data_with_pc"
git ls-files | grep -E "^data/|^data_local/"
```

If either returns any file, **stop** and add it to `.gitignore` before
committing.

### 1.2 Initialize the local repository

```bash
git init -b main
git add .
git status        # confirm only intended files are staged
git commit -m "Initial release: code accompanying JEMA submission"
```

If `git status` shows any unintended file (e.g., `data/ND2024_*.csv`),
stop and add it to `.gitignore` before committing.

### 1.3 Create the remote repository

Two options — pick one.

#### Option A: GitHub web UI

1. Open <https://github.com/new>.
2. Repository name: `JEMA-SEM-RF-watershed` (or your preference)
3. Description: `Code for "Hierarchical Landscape-Water Quality-Biota
   Pathways: A Hybrid SEM-Random Forest Framework for Watershed
   Management Target Derivation" (JEMA, 2026)`
4. Public
5. Do NOT initialize with README/LICENSE/.gitignore (already in local).
6. Click `Create repository`.

Then push from local:

```bash
git remote add origin https://github.com/<your-username>/JEMA-SEM-RF-watershed.git
git push -u origin main
```

#### Option B: GitHub CLI (one command)

```bash
gh repo create JEMA-SEM-RF-watershed \
  --public \
  --source . \
  --description "Code for the JEMA 2026 SEM-RF watershed management framework" \
  --push
```

### 1.4 Polish the repository page

Once pushed, visit `https://github.com/<your-username>/JEMA-SEM-RF-watershed`
and:

1. About section (right sidebar, gear icon):
   - Add description (same as 1.3 step 3)
   - Add topics: `random-forest`, `sem`, `watershed-management`,
     `aquatic-ecology`, `landscape-ecology`, `r`, `non-point-source-pollution`
2. Confirm the `LICENSE` badge ("MIT") shows correctly.
3. Confirm `README.md` renders properly (citation block, structure tree).

### 1.5 Tagging a release (required before Zenodo archives it)

Wait until you have completed Section 2.1 (Zenodo enablement) before
creating the first tag — Zenodo only archives tags created **after**
the GitHub-Zenodo integration is enabled.

---

## Section 2 — Minting a DOI with Zenodo

Zenodo automatically archives any GitHub Release tagged after the
integration is enabled, and assigns a citable DOI to it.

### 2.1 Enable Zenodo on the repository

1. Sign in to Zenodo (<https://zenodo.org/>) using GitHub or ORCID.
2. Go to <https://zenodo.org/account/settings/github/>.
3. Click `Sync now` (top right) to refresh the list of your GitHub repos.
4. Find `JEMA-SEM-RF-watershed` in the list.
5. Toggle the switch to ON.

That's it — Zenodo will now watch the repository for new releases.

### 2.2 Add `.zenodo.json` (recommended)

This file pre-populates Zenodo metadata so you don't have to fill it in
every release. Create it at the repository root:

```bash
# from the repo root
nano .zenodo.json   # or use any editor
```

Suggested content (edit ORCIDs/affiliations as needed):

```json
{
  "title": "Code for: Hierarchical Landscape-Water Quality-Biota Pathways - A Hybrid SEM-Random Forest Framework for Watershed Management Target Derivation",
  "description": "R analysis code accompanying the manuscript published in Journal of Environmental Management (2026). Implements descriptive statistics, PCA, RDA + variance partitioning, structural equation modeling, and four ML model benchmarks (RF, BRT, SVM, LR) with partial dependence plots for catchment-scale aquatic ecosystem health analysis in the Nakdong River basin.",
  "license": "MIT",
  "upload_type": "software",
  "access_right": "open",
  "keywords": [
    "Random Forest",
    "Structural Equation Modeling",
    "watershed management",
    "aquatic ecosystem health",
    "landscape ecology",
    "non-point source pollution",
    "machine learning",
    "Nakdong River"
  ],
  "creators": [
    {
      "name": "Kim, Gyobeom",
      "affiliation": "Yonsei University",
      "orcid": "0000-0000-0000-0000"
    },
    {
      "name": "Kim, Kyoung-Ho",
      "affiliation": "Korea Environment Institute"
    },
    {
      "name": "Park, Junyu",
      "affiliation": "Yonsei University"
    },
    {
      "name": "Kim, Yeonjoo",
      "affiliation": "Yonsei University"
    }
  ],
  "related_identifiers": [
    {
      "identifier": "10.1016/j.jenvman.2026.XXXXXX",
      "relation": "isSupplementTo",
      "scheme": "doi",
      "resource_type": "publication-article"
    }
  ]
}
```

Replace ORCID IDs with the authors' real ones (find at
<https://orcid.org/>) and update the journal DOI once accepted.

Commit and push:

```bash
git add .zenodo.json
git commit -m "Add Zenodo metadata"
git push
```

### 2.3 Cut a release

Releases are how Zenodo decides what to archive. Use semantic
versioning: `v1.0.0` for first archived release.

#### Web UI

1. Go to your repo on GitHub → `Releases` (right sidebar) → `Create a new release`.
2. Click `Choose a tag` → type `v1.0.0` → `Create new tag: v1.0.0 on publish`.
3. Release title: `v1.0.0 - Initial JEMA submission`
4. Description (suggested):
   ```
   First public release of the analysis code accompanying the JEMA
   submission "Hierarchical Landscape-Water Quality-Biota Pathways:
   A Hybrid SEM-Random Forest Framework for Watershed Management
   Target Derivation".

   Includes 7 R scripts for descriptive statistics, PCA, RDA + VP,
   SEM, and four ML model benchmarks (RF/BRT/SVM/LR) with PDPs.

   Source datasets are restricted by NIER and MOE; see
   docs/data_access_guide.md for procurement instructions.
   ```
5. Click `Publish release`.

#### CLI

```bash
git tag -a v1.0.0 -m "Initial JEMA submission release"
git push origin v1.0.0

gh release create v1.0.0 \
  --title "v1.0.0 - Initial JEMA submission" \
  --notes-file <(cat <<'EOF'
First public release of the analysis code accompanying the JEMA
submission "Hierarchical Landscape-Water Quality-Biota Pathways:
A Hybrid SEM-Random Forest Framework for Watershed Management
Target Derivation".

Source datasets are restricted by NIER and MOE; see
docs/data_access_guide.md for procurement instructions.
EOF
)
```

### 2.4 Confirm Zenodo archived the release

1. Wait 1-3 minutes for the webhook to fire.
2. Open <https://zenodo.org/account/settings/github/>.
3. The repository row should now show a green DOI badge.
4. Click the badge to open the Zenodo record. You will see:
   - A versioned DOI (e.g., `10.5281/zenodo.12345678`)
   - A "concept DOI" that always resolves to the latest version

### 2.5 Add the DOI back to GitHub README

Copy the DOI badge markdown from Zenodo (right sidebar) and add it
near the top of `README.md`:

```markdown
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.12345678.svg)](https://doi.org/10.5281/zenodo.12345678)
```

Update the `Code DOI (Zenodo)` line in README.md:

```markdown
Code DOI (Zenodo): [10.5281/zenodo.12345678](https://doi.org/10.5281/zenodo.12345678)
```

Commit and push:

```bash
git add README.md
git commit -m "Add Zenodo DOI badge"
git push
```

---

## Section 3 — Updating the Submission Materials

### 3.1 In the JEMA cover letter

Add to the data availability statement:

> The R analysis code is openly available on GitHub
> (<https://github.com/{user}/JEMA-SEM-RF-watershed>) and archived on
> Zenodo (DOI: 10.5281/zenodo.XXXXXXXX). Source datasets are restricted
> by the National Institute of Environmental Research (NIER) and the
> Ministry of Environment, South Korea, and are available upon formal
> request through their public portals (procedures in
> docs/data_access_guide.md of the repository).

### 3.2 In the manuscript

Insert a "Code Availability" subsection after Acknowledgements (or in
the Methods footnote, per JEMA preference):

> All R scripts used to perform the analyses, generate figures, and
> derive Table 2 thresholds are openly available
> (DOI: 10.5281/zenodo.XXXXXXXX; MIT License).

---

## Section 4 — Publishing Subsequent Versions

For revisions or post-acceptance updates:

1. Make your changes locally → commit → push.
2. Cut a new release with an incremented tag (`v1.1.0`, `v2.0.0`, ...).
3. Zenodo automatically mints a new versioned DOI.
4. The "concept DOI" continues to resolve to the latest version, so any
   citation using the concept DOI never goes stale.

Versioning convention (Semantic Versioning):
- `v1.0.0` — initial release
- `v1.0.1` — typo fixes, no behavioral change
- `v1.1.0` — added a script or feature, backward-compatible
- `v2.0.0` — breaking change (e.g., script refactor that changes outputs)

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `git push` rejected (large file > 100 MB) | Add the file path to `.gitignore`, then `git rm --cached <file>` and recommit. Zenodo also has a 50 GB record limit — for this repo we are well under both. |
| Release published but Zenodo did not archive it | Confirm the toggle in step 2.1 is ON for *this* repository, then re-fire the webhook by editing the release on GitHub (any tiny edit triggers it). |
| `data/` folder accidentally pushed | Run `git rm -r --cached data/` then commit and push. To purge from history use `git filter-repo` or BFG Repo-Cleaner. |
| Zenodo DOI metadata wrong | Edit the record on Zenodo directly; you can change metadata without affecting the DOI. |

---

## References

- GitHub-Zenodo integration docs: <https://docs.github.com/en/repositories/archiving-a-github-repository/referencing-and-citing-content>
- Zenodo support: <https://help.zenodo.org/>
- Choosing a license: <https://choosealicense.com/> (we chose MIT — see `LICENSE`)
- Semantic Versioning: <https://semver.org/>
