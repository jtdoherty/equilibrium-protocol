# EQM Emission Model — the "XP-S Curve"

A three-phase hybrid emission schedule for the **65,000,000 EQM** emissions
pool (the 50% liquidity-mining + 15% YieldBasis-incentive buckets from
[tokenomics.md](tokenomics.md)). The goal: a strong but capped ignition, a
sustained growth window aligned with integrations, and a controlled multi-year
taper.

## Parameters

- Total supply: 100,000,000 EQM
- Emissions pool (LM + YB incentives): 65,000,000 EQM
- Timeline: 4 years = 208 weeks (weeks 0–207)

| Phase | Weeks | Shape | Target | EQM |
|---|---|---|---|---|
| **A — Ignition** | 0–11 (12 wk) | Exponential, half-life 9 wk, capped at 15% of pool | 15% | 9,750,000 |
| **B — Growth** | 12–99 (88 wk) | Logistic (S-curve) | 52% | 33,800,000 |
| **C — Taper** | 100–207 (108 wk) | Linear taper to zero | 33% | 21,450,000 |

These sum to 65,000,000 EQM exactly. A **tail** (optional ~1–2%/yr, revenue-
funded, for `veEQM` distribution post-4yr) is *not* drawn from this pool.

## Resulting metrics

- **Total emitted (4 yr):** 65,000,000 EQM
- **Weeks to 50% of pool:** 64 (~1.2 yr)
- **Weeks to 80% of pool:** 123 (~2.36 yr)
- **Front-load, first 12 weeks:** 15.00% (the explicit Phase-A cap)
- **Front-load, first 26 weeks:** ~17.21%

### Interpretation

- **Healthy ignition without reckless dilution.** 15% of emissions in the first
  12 weeks bootstraps liquidity and attention, but is capped so the majority of
  the pool isn't handed out immediately.
- **Sustained growth window.** Phase B's 52% over weeks 12–99 deploys the
  heaviest incentives as integrations, retention, and bribe markets come online.
- **Controlled taper.** Phase C's 33% gently reduces emissions to zero over the
  final ~2 years, allowing a transition to revenue- and bribe-driven incentives.
- **Half the pool by ~week 64** — somewhat front-loaded, favoring market
  dominance in the first 12–18 months while preserving a multi-year runway.

> **Tuning knob — peak location.** With these parameters the largest weekly
> emission lands near the start. To make the visible peak occur during Phase B
> (so peak incentives align with integrations), move the logistic midpoint later
> (e.g. global week ~70 instead of ~44) or increase the logistic steepness.

## Reference simulation

The schedule was modeled in Python (NumPy/pandas). Reproduced here for
reference.

```python
# Hybrid "XP-S Curve" emission schedule for EQM
TOTAL_SUPPLY = 100_000_000
EMISSIONS_POOL = 65_000_000   # 50% + 15% combined
WEEKS_TOTAL = 208             # 4 years (weeks 0..207)

import numpy as np
import pandas as pd

weeks = np.arange(WEEKS_TOTAL)

# Phase boundaries
A_start, A_end = 0, 11
B_start, B_end = 12, 99
C_start, C_end = 100, 207
weeks_A = A_end - A_start + 1
weeks_B = B_end - B_start + 1
weeks_C = C_end - C_start + 1

# Targets
A_cap_amount = EMISSIONS_POOL * 0.15            # 15% of pool
B_target_amount = EMISSIONS_POOL * 0.52         # 52% of pool
remaining_after_AB = EMISSIONS_POOL - (A_cap_amount + B_target_amount)
if remaining_after_AB < 0:
    B_target_amount = EMISSIONS_POOL - A_cap_amount
    remaining_after_AB = 0

# Phase A: exponential, half-life 9 weeks, scaled so the phase sums to the cap
rA = 0.5 ** (1.0 / 9.0)
raw_A = rA ** np.arange(weeks_A)
em_A = raw_A * (A_cap_amount / raw_A.sum())

# Phase B: logistic cumulative across the phase, scaled to the target
k = 0.09                       # steepness
t0 = (weeks_B - 1) / 2.0       # midpoint (phase-local)
tB_local = np.arange(weeks_B)
C_raw = 1.0 / (1.0 + np.exp(-k * (tB_local - t0)))
C_raw = (C_raw - C_raw[0]) / (C_raw[-1] - C_raw[0])
em_B = np.diff(np.concatenate([[0.0], C_raw])) * B_target_amount

# Phase C: linear taper to zero, triangle sums to the remainder
e0_C = 2 * remaining_after_AB / weeks_C
tC = np.arange(weeks_C)
em_C = e0_C * (1 - tC / weeks_C)

# Assemble + correct rounding so the pool matches exactly
emissions = np.zeros(WEEKS_TOTAL)
emissions[A_start:A_end+1] = em_A
emissions[B_start:B_end+1] = em_B
emissions[C_start:C_end+1] = em_C
emissions[-1] += EMISSIONS_POOL - emissions.sum()

df = pd.DataFrame({"Week": weeks, "Emission_EQM": emissions})
df["Cumulative_EQM"] = df["Emission_EQM"].cumsum()
df["Cumulative_of_Pool_pct"] = df["Cumulative_EQM"] / EMISSIONS_POOL * 100
```

## Next steps to finalize

- **Move the logistic midpoint** if the peak should sit in Phase B.
- **Tune the Phase-A cap** for risk appetite (15% is aggressive; 10% pushes the
  50% mark further out and reduces mercenary exposure).
- **Anti-dump mechanics** — consider time-vested claimable rewards for non-
  locked wallets.
- **Governance control** — let `veEQM` adjust weekly emission parameters within
  bounded ranges.
- **Tail funding** — build buyback/revenue mechanisms early so the optional
  post-4yr tail is sustainable.
- **On-chain parameters** — export the weekly emission array to a contract-ready
  form for deployment.
