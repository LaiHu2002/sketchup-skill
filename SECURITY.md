# Security

SketchUp Runtime Guard is designed to keep validation evidence useful without leaking private project details.

## Do Not Publish

Before sharing logs, reports, screenshots, or generated artifacts, remove:

- Real customer model paths and model files.
- Private plugin names if the repository is meant to stay vendor-neutral.
- Usernames, home directories, workstation names, VM names, and internal network paths.
- SSH hosts, remote desktop details, bridge tokens, API keys, passwords, signing keys, and cloud credentials.
- Internal release worktree paths, package storage paths, object storage bucket names, and deployment scripts.
- Proprietary native runtime binaries and manifests unless they are already intended for public release.

## Diagnostic Bundle Guidance

Prefer publishing structured, minimal identity records:

- `sketchup_pid`
- `plugin_dir`
- `model_sha256`
- `bridge_port`
- `runtime_path`
- `runtime_actual_sha256`
- `runtime_expected_sha256`
- `lane_id`
- `checked_at`

Use placeholders for paths whenever possible. A hash is usually enough to prove identity without revealing the original file.

## Reporting Security Issues

If this repository is used as the basis for a public project, configure a private vulnerability reporting channel in the GitHub repository settings before accepting external reports.
