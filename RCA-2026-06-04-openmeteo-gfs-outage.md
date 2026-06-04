# RCA: Precipi Outage — Open-Meteo GFS 502
**Date:** 2026-06-04
**Duration:** ~30 minutes (time of user report to fix deploy)
**Severity:** Full outage — app completely unusable

---

## Summary

Precipi was unavailable due to a 502 Bad Gateway error returned by the Open-Meteo API for the GFS model endpoint. Because the app fetched both weather models in a `Promise.all()` with no error handling, a single model failure caused the entire data load to throw, triggering the "Could not load weather data" error screen.

---

## Timeline

| Time | Event |
|------|-------|
| ~T+0 | User reports app showing error screen on load |
| T+2m | Confirmed HTTP 200 from Cloudflare — hosting not the issue |
| T+3m | Direct curl to Open-Meteo GFS endpoint returns `502 Bad Gateway` |
| T+4m | ECMWF endpoint confirmed healthy |
| T+10m | Fix deployed: GFS failure now caught, app falls back to ECMWF |
| T+40s | App restored via Cloudflare auto-deploy |

---

## Root Cause

Open-Meteo's GFS (`gfs_seamless`) model endpoint went down with a 502. The app's `loadData()` function used `Promise.all()` to fetch both GFS and ECMWF simultaneously:

```js
// Before fix — one failure kills both
const [gfs, ecmwf] = await Promise.all([
  fetchModel('gfs_seamless'),
  fetchModel('ecmwf_ifs025'),
]);
```

`Promise.all()` rejects immediately if any promise rejects. The outer `refresh()` function caught this as a generic error and showed the failure screen, with no ability to degrade gracefully.

---

## Fix Applied

GFS fetch is now wrapped in `.catch(() => null)`. If it fails, the app falls back to ECMWF for all 7 days:

```js
// After fix — GFS failure is non-fatal
const [gfsResult, ecmwf] = await Promise.all([
  fetchModel('gfs_seamless').catch(() => null),
  fetchModel('ecmwf_ifs025'),
]);
const gfs = gfsResult ?? ecmwf; // fall back to ECMWF if GFS is down
```

Commit: `6592e93`

---

## Impact

- **User-facing:** App showed error screen and was fully unusable for the outage duration
- **Data quality during fallback:** Minimal — ECMWF is a high-quality global model. Days 1-2 lose the slight short-range accuracy edge GFS has for US forecasts, but the difference is marginal in practice

---

## Contributing Factors

- **Single API provider:** All weather data (both models) comes through Open-Meteo. There is no secondary data source
- **No model-level resilience:** The original `Promise.all()` design had no tolerance for partial failures
- **No alerting:** No monitoring exists to detect when the app is returning errors

---

## Future Considerations

| Item | Priority | Notes |
|------|----------|-------|
| Add ECMWF fallback for GFS (done) | ✅ Complete | Deployed 2026-06-04 |
| Add fallback if ECMWF also fails | Low | Could try a third provider like Tomorrow.io or NWS |
| Uptime monitoring | Low | Simple cron ping (e.g. UptimeRobot) would catch this faster |
| Surface model source in UI | Low | App already tracks GFS vs ECMWF per day — could show "using backup model" banner |
