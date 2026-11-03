# GrindSnore (iOS)

Bruxism (teeth grinding) & snore tracker — record overnight audio on-device, classify events, morning report. Privacy-first: **audio never leaves the device**.

## Status

MVP skeleton (CI verified) — features land per plan:
- [x] CI: Windows dev → GitHub Actions macOS (Xcode 26) build → TestFlight
- [ ] Overnight recording + on-device classification (RMS + band energy)
- [ ] Morning report (counts / time bands / intensity)
- [ ] Trigger correlation (coffee/alcohol/stress × grind timing)
- [ ] 7-day trends, PDF export (one-time unlock)

## Compliance notes (from research)

- Apple 2.5.4 allows background audio recorders; manual start each night + persistent status indicator
- All audio local-only (privacy selling point)
- Wording: track/log only, never diagnose/detect/treat; guide says "bedside table" (never "under pillow" per 2.4.2)

## License

MIT
