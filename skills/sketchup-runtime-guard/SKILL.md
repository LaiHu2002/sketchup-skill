---
name: sketchup-runtime-guard
description: Use when launching, validating, debugging, or handing off SketchUp plugin sessions where stale SketchUp processes, shared plugin directories, bridge port collisions, cached HtmlDialog assets, or native runtime binaries could make test evidence untrustworthy. This skill helps create isolated lanes, prove the live plugin/runtime identity, and separate file sync from GUI-ready validation.
---

# SketchUp Runtime Guard

Use this skill before claiming that a SketchUp plugin build is deployed, loaded, or ready for visual QA.

## Core Rule

Bridge connectivity and visible SketchUp windows are not proof. A run is trustworthy only after the live SketchUp session reports the expected plugin directory, model, bridge port, runtime path, and runtime hash.

## Boundary First

Before launching or modifying anything, write down:

- The one plugin behavior or visual result being validated.
- The source checkout or package that should be under test.
- The plugin files allowed to be copied into the lane.
- The SketchUp processes, runtime processes, ports, model files, and temp directories owned by this lane.
- The user-visible acceptance signal, such as a dialog opening, a model operation succeeding, or a screenshot being ready for review.

Everything outside that boundary is read-only.

## Session Ledger

Create or update a lane ledger before validation starts. Track at least:

- `lane_id`
- `owner`
- `status`
- `source_root`
- `source_commit`
- `plugin_dir`
- `model_path`
- `bridge_host`
- `bridge_port`
- `sketchup_pid`
- `runtime_pid`
- `runtime_path`
- `runtime_actual_sha256`
- `runtime_expected_sha256`
- `artifacts_root`
- `started_at`
- `updated_at`

Use status values such as `planned`, `files_synced`, `runtime_identity_proven`, `gui_ready_for_visual_qa`, `failed_identity_check`, and `cleaned_up`.

## macOS Isolated Launch

Prefer launching the SketchUp executable directly with an isolated user home:

```bash
CFFIXED_USER_HOME="$RUN_ROOT/home" \
HOME="$RUN_ROOT/home" \
APPDATA="$RUN_ROOT/home" \
TMPDIR="$RUN_ROOT/tmp" \
PLUGIN_GUARD_BRIDGE_PORT="$PORT" \
"/Applications/SketchUp 2026/SketchUp.app/Contents/MacOS/SketchUp" \
"$RUN_ROOT/models/validation.skp"
```

The lane should contain:

- `$RUN_ROOT/home`
- `$RUN_ROOT/tmp`
- `$RUN_ROOT/models`
- `$RUN_ROOT/artifacts`
- an isolated `SketchUp/Plugins` tree
- the plugin entrypoint
- the plugin directory under test
- a bridge or probe configuration using the lane port

Do not treat `open -n SketchUp.app` as isolation proof. If `open` is used as a fallback, verify the resulting process environment and plugin directory from inside SketchUp before trusting the run.

## Windows Validation

For Windows, use a dedicated test lane or a cleanly restarted target SketchUp session. A task scheduler success, a process named `SketchUp.exe`, or a listening bridge port is not enough.

Require all of these before GUI evidence is accepted:

- the desktop session is usable for visual checks
- SketchUp is in a real model session, not only a welcome page
- the plugin probe log is fresh for this launch
- the bridge responds after several retries
- the live plugin path matches the lane or deployment directory
- the runtime path and hash match the expected manifest

If Windows desktop, graphics, lock screen, or bridge startup is unstable, record the failure as environment instability. Do not reinterpret it as a plugin failure without runtime identity evidence.

## Runtime Identity Probe

From inside live SketchUp Ruby, collect:

- `Process.pid`
- SketchUp version
- plugin root and plugin directory constants or equivalent values
- relevant environment variables
- active model path and model SHA256
- bridge host and port
- runtime client config, if one exists
- runtime binary path
- runtime actual SHA256
- runtime expected SHA256 from release or stage manifest
- manifest path and source/build digest, if available

Identity passes only when:

- live plugin directory equals the expected lane plugin directory
- active model path equals the expected lane model path
- bridge port equals the lane port
- runtime path is inside the lane plugin directory or intended deployment directory
- runtime actual hash is present
- runtime expected hash is present
- runtime actual hash equals runtime expected hash

If the expected hash is missing, fail closed unless the user explicitly requested an unverified local development run.

If this repository's helper scripts are available, use `scripts/probe_sketchup_identity.rb` to emit a normalized identity report and `scripts/validate_runtime_identity.rb` to check it against the lane ledger. Treat those scripts as evidence helpers, not as a SketchUp launcher.

## Result Levels

Report results with precise language:

- `files_synced`: files were copied. This does not prove SketchUp is using them.
- `runtime_identity_proven`: live SketchUp reported the expected plugin and runtime identity.
- `gui_ready_for_visual_qa`: identity is proven and the target model/dialog/view is open.
- `visual_qa_passed`: a human or visual automation confirmed the requested result.

Avoid saying "deployed" or "fixed in SketchUp" when only file copying or bridge pinging has happened.

## Failure Handling

Stop and mark the run invalid if:

- the plugin directory points to a global user plugin directory instead of the lane
- the runtime path is outside the lane or intended deployment directory
- the actual runtime hash differs from the manifest hash
- the manifest is present but invalid
- the bridge responds from a port that cannot be tied to the lane SketchUp PID
- SketchUp opens a welcome page or a different model
- the model hash does not match the expected model

Do not stack patches on a dirty runtime. Clean up the lane and relaunch from a smaller boundary.

## Cleanup

Only stop processes and remove files recorded in the ledger for the current lane. Never run an unscoped global SketchUp kill command unless the user explicitly asked to take over that exact environment and the target processes have been recorded.

At cleanup, record:

- stopped SketchUp PID
- stopped runtime PID
- released bridge port
- retained artifact paths
- final status
