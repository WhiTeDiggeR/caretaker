# Git LFS for binary assets

Issue #140. New binary assets (textures, models, audio, video) are stored in Git LFS: git keeps a small pointer and
the file itself lives in GitHub LFS storage. Files committed before LFS was switched on stay ordinary git blobs —
history is never rewritten (`AGENTS.md`), so there is no migration.

## What goes to LFS

`.gitattributes` routes these extensions to LFS: `png jpg jpeg tga tif tiff webp exr hdr psd glb bin fbx blend sbsar
wav ogg mp3 flac mp4 webm ogv`. Text formats (`.gltf`, `.obj`, `.tscn`, `.tres`, `.import`, `.json`, `.svg`) stay in
git.

The generated section at the end of `.gitattributes` lists every matching file that existed on any `origin` branch
when LFS was switched on (673 files). Those paths keep the LFS filter off, so they stay regular blobs, produce no
"should have been pointers" warnings and do not show up as modified. Editing such a file keeps it a regular blob.

## Setup (once per machine)

- Windows: Git for Windows ships Git LFS. Run `git lfs install` once.
- Linux/macOS: install the `git-lfs` package, then `git lfs install`.
- An existing clone: after `git lfs install`, run `git lfs pull` to replace pointers with real files.
- Claude Code cloud sessions skip LFS downloads on checkout (`smudge --skip`): run `git lfs pull` at the start of a
  session before opening the project in Godot. Pushing uploads objects to S3 and then confirms each one with a
  verify request to `lfs.github.com`; the environment's network access must allow that host (issue #157), otherwise
  the pre-push hook fails and nothing is pushed.
- GitHub Actions: `actions/checkout` uses `lfs: true` in both workflows.

Without Git LFS, Godot sees text pointers instead of images and models and the import fails for those files.

## The check

`python tools/ci/lfs_check.py` (part of `tools/ci/run_checks.sh`) fails when a file that matches an LFS rule was
committed as a regular blob, for example from a machine without Git LFS. Fix:

```
git lfs install
git add --renormalize path/to/file.png
git commit
```

A branch started before #140 that adds binaries is caught by the same check after it syncs with `team/integration`;
renormalize its new files the same way. `python tools/ci/lfs_check.py --write-legacy` regenerates the exemption list
from all `origin` branches; use it only when the team decides to exempt files again, not to bypass LFS.

## Quotas

GitHub Free and Pro include 10 GiB of LFS storage and 10 GiB of download bandwidth per month (metered billing; with a
$0 budget LFS is blocked for the rest of the month once a quota is spent). Every CI run downloads all LFS files, so
watch the bandwidth as LFS content grows; caching `.git/lfs` in the workflow is the next step if it gets close.
