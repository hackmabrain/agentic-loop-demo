# Fallback recordings — capture checklist (Wednesday afternoon)

The recovery story in `DEMO_RUNBOOK.md` Section 5 references six
recordings under this folder. They are the parachutes for "everything
broke on stage." Capture them once on Wednesday afternoon. Total
runtime: ~20 minutes.

## Tools

- **macOS**: QuickTime Player → File → New Screen Recording. Or Loom.
- **Windows**: Snipping Tool → Record. Or OBS Studio.

Mute audio on capture (Edit → Remove Audio) — you'll narrate live on
stage if you ever play these.

## Six clips to capture

| Filename                          | Duration | What to show                                           |
|-----------------------------------|----------|--------------------------------------------------------|
| `gh-aw-run.mov`                   | 30 sec   | The Actions tab — clicking "Run workflow", the green check, then the resulting `[repo status]` issue. |
| `cca-pr-ready.mov`                | 60 sec   | The Coding Agent's draft PR going to Ready, CCR's comments arriving inline. |
| `merge-deploy.mov`                | 75 sec   | Clicking Merge, the deploy workflow firing, the manual approval gate, the slot swap landing in Production. |
| `trigger-failure.mov`             | 30 sec   | Terminal: `bash scripts/trigger-failure.sh`. Then a curl to /products returning 500. |
| `sre-agent-investigation.mov`     | 90 sec   | Azure Portal → SRE Agent → the active investigation thread, the steps it took, the filed GitHub issue. |
| **`closed-loop.mov`**             | ~5 min   | A single concatenation of clips #1 – #5 (use QuickTime Edit → Insert Clip After Selection, or use any video editor). This is the master fallback Tab 7 points at. |

## Capture protocol

For each clip:

1. Reset the demo: `bash scripts/reset-demo.sh && bash scripts/restage-demo.sh` (or use the rehearsal resource group).
2. Open the relevant tab.
3. Start screen recording.
4. Run the action (click, type, swap).
5. Stop recording when the artifact is fully rendered on screen.
6. Trim front and back so there is no dead air (QuickTime → Edit → Trim).
7. Save with the filename above into `docs/fallback/`.

## Verification

```bash
ls -la docs/fallback/
# Expect: gh-aw-run.mov, cca-pr-ready.mov, merge-deploy.mov,
#         trigger-failure.mov, sre-agent-investigation.mov,
#         closed-loop.mov, plus this README.
```

If you have all six on disk Wednesday evening, the demo's recovery
story is no longer aspirational.

## Why this lives in a separate file

The demo runbook says *what* to do if the demo collapses; this file
says *how* to produce the artifacts that make recovery possible.
Splitting them keeps `DEMO_RUNBOOK.md` short enough to skim Thursday
morning.
