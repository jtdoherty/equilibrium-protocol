# Equilibrium Protocol — Whitepaper

## Abstract

The Equilibrium Protocol is a yield-optimization and governance-aggregation
layer built on top of YieldBasis. It introduces a "meta-vault" that
automatically shifts user deposits between the two primary yield strategies
available on YieldBasis: direct trading-fee accrual and `YB` token emission
farming. By pooling user assets, Equilibrium accumulates a dominant `veYB`
position, allowing it to boost its own rewards and create a self-reinforcing
yield flywheel. For the user, Equilibrium offers a single liquid asset,
`m-ybBTC`, that provides optimal, hands-free, auto-compounding yield on BTC.

## 1. The YieldBasis dilemma

- YieldBasis offers IL-free liquidity pools and a `ybBTC` BTC position.
- The core user decision is **staking vs. not staking `ybBTC`**:
  - **Staked** → earn `YB` token emissions.
  - **Unstaked** → earn a share of trading fees.
- The optimal choice shifts continuously with the *percentage of `ybBTC`
  staked* across the whole market — a reflexive, game-theoretic moving target.
- **Problem:** the average user is not equipped to monitor this and frequently
  switch strategies to maximize returns.

## 2. The Equilibrium solution: a dual-strategy super-vault

Equilibrium is a hands-free layer for optimal yield, built on two pillars:

- **Pillar 1 — the Convex model:** aggregate `veYB` power by max-locking all
  farmed `YB` to perpetually boost rewards.
- **Pillar 2 — the Yearn model:** an automated "AMM for yield strategies" that
  intelligently switches the entire pool between staking and fee accrual.

The user benefit: a single, liquid deposit token (`m-ybBTC`) representing a
share in this dynamically managed, high-yield pool.

## 3. Core architecture

- **EquilibriumVault** — the primary user-facing contract for `ybBTC` deposits
  and the heart of the strategy-switching mechanism.
- **YBLocker** — the governance engine; accumulates and deploys `veYB` power.
- **StrategyManager** — the on-chain "brain" with the math comparing the APR of
  staking vs. fee accrual:
  - Staked APR formula based on `YB` emissions and price.
  - Unstaked APR formula based on a trailing average of trading fees.
- **RewardDistributor** — the treasury; collects yield and distributes it to
  participants (via the Booster).

## 4. The maximized assets (m-assets)

- **`m-ybBTC`** — the liquid derivative for `ybBTC`. Accrues value from the
  underlying strategies (auto-compounded fees + emissions).
- **The exit ramp** — users withdraw at any time by swapping `m-ybBTC` for
  `ybBTC` in a dedicated Curve/Uniswap liquidity pool.
- **`m-YB`** — the liquid derivative for `YB` locked in the protocol.

## 5. Tokenomics: the EQM token

`EQM` is an incentive and governance token. Its primary functions are to
bootstrap protocol TVL and decentralize control. A large portion of supply is
allocated to `m-ybBTC` stakers to incentivize deposits. Value derives from
governance power over Equilibrium's `veYB` holdings and control over the
treasury. Full details: [tokenomics.md](tokenomics.md).

## 6. Governance: path to decentralization

- **Phase 1 — multi-sig control:** initial launch managed by a core-team
  multi-sig for security and agility.
- **Phase 2 — DAO governance:** transition all protocol controls to `EQM`
  (`veEQM`) holders.

## 7. Fee structure

A performance fee (planned 15%) is taken on all generated yield, used to fund
operations, development, and the DAO treasury. Allocation breakdown in
[tokenomics.md](tokenomics.md#performance-fee-15).

## 8. Security

- Commitment to multiple independent smart-contract audits.
- Multi-signature wallet for all administrative functions.
- A public bug-bounty program.

## 9. Roadmap

Future plans include vaults for other YieldBasis assets (e.g. `ybETH`) and
expanding the utility of `EQM`.

---

## Appendix: development phases

**Phase 1 — Core contracts (vaults & tokens).** `EquilibriumVault`,
`YBLocker`, `m_ybBTC`, `m_YB`. State-switching functions and StrategyManager
permissioning; VotingEscrow integration for max-locking.

**Phase 2 — Control system (controls & automation).** `StrategyManager` with
`getStakedAPR()` / `getUnstakedAPR()` views and `switchStrategy()` execution
with a hysteresis buffer; a trailing-average fee accumulator. Off-chain keeper
bots:

- *StrategyKeeper* — monitors APRs and calls `switchStrategy()` when profitable.
- *HarvestKeeper* — periodically harvests all yield and routes it to the
  RewardDistributor.
- *VoteKeeper* — casts the protocol's weekly vote on the YieldBasis
  GaugeController.

**Phase 3 — Economic engine (tokenomics & rewards).** `EQM` with a defined
emission schedule, `RewardDistributor` treasury, and `Booster` staking for
`EQM` emissions.

**Phase 4 — User experience (frontend/UI).** A "set-and-forget" interface:
deposit page, stake page, dashboard (balance, vault APR, current strategy,
pending `EQM`), and a liquidity-pool page for entering/exiting `m-ybBTC`.

**Phase 5 — Launch & decentralization.** Audits and bug bounty; deploy and
configure; multi-sig (e.g. 3-of-5 Gnosis Safe) as initial owner; bootstrap
event via the Booster; progressive transition to DAO governance.
