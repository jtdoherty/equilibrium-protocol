# Equilibrium Protocol — Tokenomics

A Convex-inspired model designed to bootstrap TVL, accumulate `veYB`
governance power, and align users, governance participants, and the DAO.

> Design target, not yet implemented on-chain. The contracts today mint a flat
> `eqmPerPeriod`; the schedule below is the intended end state.

## 1. EQM — native governance token

**Objective:** a clear max supply, distribution, and utility that drives value
to the protocol and its stakeholders, similar to Convex's CVX.

### Max supply and allocations

**Max supply: 100,000,000 EQM** — significant but finite, for long-term
incentive alignment and clear scarcity.

| Allocation | % | EQM | Purpose |
|---|---|---|---|
| Liquidity mining (`m-ybBTC` stakers) | 50% | 50,000,000 | Bootstrap `ybBTC` deposits; diminishing multi-year schedule. |
| YieldBasis incentives / YB Locker (`m-YB`) | 15% | 15,000,000 | Reward `YB` lockers to build a dominant `veYB` position. |
| DEX liquidity & bootstrap | 10% | 10,000,000 | Seed `EQM` pools; strategic/OTC sales. See [design-decisions](design-decisions.md#dex-liquidity-strategy-for-the-10-eqm-allocation). |
| Team | 15% | 15,000,000 | 4-year linear vest, 6–12 month cliff. |
| Treasury / ecosystem fund | 10% | 10,000,000 | DAO-managed: development, grants, audits, partnerships. |

The 50% + 15% (= 65M) form the **emissions pool** modeled in
[emissions.md](emissions.md). The other 35M are vested/locked/treasury amounts
not subject to the emission schedule.

> **Open risk:** 50% to liquidity mining and 25% combined team+treasury are both
> on the heavy side for a new protocol. See
> [design-decisions.md](design-decisions.md#risks--areas-to-refine).

### veEQM — staking & governance

Lock `EQM` for `veEQM` (model after veCRV / vlCVX); longer locks → more
`veEQM`. Proposed lock range: 1 week up to 4 years, linearly scaled.

`veEQM` holders receive:

- **Governance voting power** over: `EQM` emission rates and distribution, the
  performance-fee allocation, protocol upgrades, treasury allocation, and the
  direction of Equilibrium's aggregated `veYB` voting power.
- **Boosted emissions** on their own `m-ybBTC` and `m-YB` farming rewards.
- **Protocol revenue share** via performance-fee buybacks/distribution.
- **YieldBasis governance influence** — indirectly directing Equilibrium's
  `veYB` power and earning bribes.

> **Open risk:** a 1-week-to-4-year range tends to make everyone lock short.
> Convex used a fixed 16-week `vlCVX` lock; consider a stricter model.

### Emission rate (`eqmPerPeriod`)

- High initial schedule at launch (for the 50% + 15% buckets), tapering over
  time. Concrete shape: [emissions.md](emissions.md).
- Once the DAO is active, `veEQM` holders vote on adjustments (ideally within
  bounded ranges, e.g. ±10% per proposal, to avoid shocks).
- Always constrained by the 100M max supply, with a clear end date for primary
  emissions.

## 2. m-YB — liquid wrapper for locked YB

A liquid representation of `YB` locked by the protocol (the `cvxCRV` analogue).

- **Represents locked YB:** minted when users deposit `YB` into the `YBLocker`,
  which locks it as `veYB` for the maximum duration to secure the highest boost.
- **Access to boosted rewards:** holders benefit from Equilibrium's aggregated
  `veYB` position (boosted `YB` emissions) plus a share of `EQM` incentives.
- **Liquid exit:** tradeable on a DEX, so holders can exit without waiting for
  the lock to expire (at a possible discount/premium).
- **Relationship with EQM:** `EQM` incentives reward `YB` locking; `veEQM`
  holders direct the underlying `veYB` voting power.

## 3. m-ybBTC — value accrual for vault stakers

A liquid, auto-compounding derivative of `ybBTC`. Beyond `EQM` emissions,
`m-ybBTC` stakers accrue:

- **`ybBTC` trading fees** — the vault actively switches strategies to maximize
  them.
- **`YB` emission distribution** — a portion of farmed `YB` flows to stakers.
- **Auto-compounding** — rewards are reinvested, so `m-ybBTC` appreciates
  against `ybBTC` over time.
- **`EQM` emissions** — `m-ybBTC` stakers are the primary liquidity-mining
  recipients.

## Performance fee (15%)

A 15% performance fee on all generated yield, allocated to:

| Use | Share | Detail |
|---|---|---|
| `EQM` buybacks → `veEQM` holders | 5% | Buy `EQM` on market, distribute to governance; creates buy pressure. |
| DAO treasury / ecosystem fund | 5% | Funds development, marketing, grants, strategic initiatives. |
| Protocol operations / keeper bots | 3% | Gas for HarvestKeeper and other bots, Chainlink Automation, infra. |
| Bug bounty / security fund | 2% | Audits and bounties. |

## Benefits to YieldBasis

Equilibrium is designed to be a value-add layer for the protocol it sits on:

- **Aggregated liquidity & TVL** — drives significant TVL to YieldBasis.
- **Dominant `veYB` position** — concentrates governance, can direct `YB`
  emissions to strategically important pools.
- **Increased trading volume** — active strategy switching can increase pool
  volume and fees.
- **User stickiness** — a "set-and-forget" layer broadens YieldBasis's user
  base.
- **Bribe-market amplification** — `veYB` voting power increases demand for `YB`
  and `veYB` via the bribe market.
