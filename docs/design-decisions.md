# Design Decisions

Open design questions and the reasoning behind the current direction.

## Reward routing: Convex-style vs. Yearn-style

The central fork: does harvested yield concentrate in the vault product
(Yearn) or split across both deposit lanes (Convex)?

### Option A — concentrate rewards into `m-ybBTC` (Yearn-style)

- All trading fees from unstaked `ybBTC` → auto-compounded into the vault →
  raises `m-ybBTC` NAV.
- All `YB` emissions → locked in `YBLocker` → boosts vault APR indirectly.
- `EQM` incentives → `m-ybBTC` stakers in the Booster.
- `m-YB` holders get only YieldBasis's native `veYB` fee revenue (no direct
  slice of vault profits).

**Pros:** simple for users (BTC depositors are the clear winners); clean
narrative ("deposit BTC → highest boosted yield"); strong TVL magnet for the
hardest asset to attract; less yield dilution.

**Cons:** weaker `YB` aggregation (little reason to bring `YB` to `YBLocker`);
slower `veYB` flywheel; more BTC-centric and less of the governance-aggregator
model that made Convex powerful.

### Option B — split rewards between `m-ybBTC` and `m-YB` (Convex-style)

- Trading fees → partly auto-compounded into `m-ybBTC`, partly to the
  RewardDistributor for `m-YB` stakers.
- `YB` emissions → locked in `YBLocker`; `veYB` boosts vault APR.
- `EQM` incentives → both `m-ybBTC` and `m-YB` stakers, in tunable proportions.

**Pros:** dual incentives for both BTC depositors and `YB` holders; maximum
`YB` absorption → faster governance accumulation; stronger flywheel
(more `veYB` → higher APR → more TVL → more emissions to lock); the
Convex-proven model.

**Cons:** dilutes vault yield (some fees diverted from `m-ybBTC`); more complex
UX (two tracks); requires deep `m-YB`/`YB` liquidity early or `m-YB` trades at a
heavy discount.

### Decision — hybrid, phased

1. **Launch with Option A** — all rewards to `m-ybBTC`, to make the vault
   product maximally attractive at genesis and keep UX simple.
2. **Transition toward Option B** once there's traction — gradually route a %
   of rewards to `m-YB` holders, ideally **governance-controlled** (`veEQM`
   voters set the vault-vs-locker split).

Early stage hyper-focuses on vault growth and TVL; later stage deepens the
governance moat by incentivizing `YB` lockers. `EQM` governance dynamically
tunes the balance.

## DEX liquidity strategy for the 10% EQM allocation

Three models for deploying the 10M `EQM` DEX/bootstrap allocation:

1. **Protocol-Owned Liquidity (POL)** — pair `EQM` with treasury ETH/USDC/`YB`
   to seed LPs the protocol owns. Permanent liquidity, no mercenary dumping, DAO
   earns fees. (cf. Olympus Pro, Frax POL.)
2. **Liquidity Bootstrapping Pool (LBP)** — a Balancer LBP (price starts high,
   decays). Attracts buyers gradually, discourages whale sniping, raises
   stables/ETH for treasury. (cf. Perpetual Protocol, Pendle.)
3. **Partner / OTC deals** — sell a slice (e.g. 2–3M `EQM`) at a discount to
   strategic partners who must LP with it (e.g. `EQM`/`YB`). Strengthens
   integrations and early buy-in. (cf. Convex's early Yearn/Alchemix/StakeDAO
   backers.)

**Recommended hybrid:**

- **~5% `EQM`** + matching ETH/USDC → POL (seed `EQM`/ETH and `EQM`/USDC).
- **~3% `EQM`** → Balancer-style LBP / bootstrap auction (treasury runway).
- **~2% `EQM`** → strategic partners who lock + LP (`EQM`/`YB`).

This yields a permanent liquidity floor (POL), capital runway (LBP), and allies
seeded in `EQM`/`YB` liquidity.

## Risks & areas to refine

Honest critique of the current tokenomics, to address before launch.

- **50% liquidity mining may be too heavy.** Convex could afford 50% because
  Curve was already a liquidity giant; for a new protocol this risks mercenary
  farm-and-dump. Consider a decaying model (e.g. ~30% over 4 years with a
  revenue-funded tail) instead of handing out 50%.
- **Emission curve shape matters.** Too aggressive → short-term TVL that
  collapses when rewards fall; too slow → uncompetitive. Prefer an S-curve (fast
  growth, long tail) over linear decline. See [emissions.md](emissions.md).
- **Team + treasury = 25% is a lot of control tokens early.** For
  "community-owned" optics in a Curve-Wars-style meta, consider ~10–12% team and
  ~5–10% treasury.
- **Bribe & governance market is the real moat.** Convex won by dominating the
  bribe market (cheaper to bribe `vlCVX` than to buy CRV). The docs must
  explicitly describe how `veEQM` + `m-YB` aggregation attracts external
  protocols to bribe `EQM` holders, or `EQM` won't become a "governance
  blackhole."
- **Post-emissions value accrual.** Users will ask what `EQM` is worth once
  emissions end. Need a clear narrative: buybacks from protocol fees, governance
  rights over integrations, bribe-market share.
- **Lock flexibility.** A 1-week-to-4-year `veEQM` range tends to make everyone
  lock short, diluting the boost model. Convex solved this with a fixed 16-week
  `vlCVX`; consider a stricter lock.

### Verdict

The foundation is sound — `veEQM` + liquid wrappers (`m-YB`, `m-ybBTC`) +
bribe-market play is the right combination. The refinements needed are on
emission pacing, team/treasury sizing, governance-lock mechanics, and an
explicit bribe-market strategy.
