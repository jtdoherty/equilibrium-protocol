# Equilibrium Protocol

> A yield-optimization and governance-aggregation layer built on top of [YieldBasis](https://www.yieldbasis.com/).

Deposit `ybBTC`, receive `m-ybBTC`, and earn hands-free, auto-compounding yield. Equilibrium automatically moves the pool's capital between YieldBasis's two yield sources — **staking for `YB` emissions** and **holding liquid for trading fees** — while perpetually locking the `YB` it farms to build a dominant `veYB` governance position. Think "Convex + Yearn, for YieldBasis."

> **Status:** working prototype. All external YieldBasis dependencies are mocked, and APY/emission math is still placeholder-grade. Not audited, not production-ready. See [Status & limitations](#status--limitations).

## How it works

1. A user deposits `ybBTC` into the **EquilibriumVault** and receives `m-ybBTC` shares priced on the vault's net asset value.
2. The **StrategyManager** ("the brain") continuously computes the split between staked and unstaked `ybBTC` that maximizes blended APY, and commands the vault to rebalance when the gain clears a threshold.
3. A Chainlink-Automation–driven **HarvestKeeper** periodically runs the full cycle: claim `YB` emissions, re-optimize the strategy, auto-compound `ybBTC` fees, lock farmed `YB` into `veYB` (minting liquid `m-YB`), and distribute `EQM` incentives.
4. Users can stake their `m-ybBTC` in the **Booster** to earn `EQM`, the protocol's incentive/governance token.

For the full design, economics, and rationale, see [`docs/`](docs/).

## Contracts

| Contract | Role |
|---|---|
| `EquilibriumVault.sol` | Core vault. Mints/burns `m-ybBTC`, holds the staked/unstaked allocation, executes rebalances. |
| `StrategyManager.sol` | "Brain." Computes optimal allocation from staked vs. unstaked APY and commands rebalances. |
| `YBLocker.sol` | Locks farmed `YB` as `veYB` (max 4-year lock, auto-extending); mints liquid `m-YB`. |
| `Booster.sol` | Synthetix-style staking: stake `m-ybBTC`, earn `EQM`. |
| `RewardDistributor.sol` | Sole minter of `EQM`; funds the Booster's reward cycles. |
| `HarvestKeeper.sol` | Chainlink Automation orchestrator that drives the whole cycle. Owns the other contracts. |
| `EQM.sol` | Protocol incentive/governance token (ERC20). |
| `m_ybBTC.sol` / `m_YB.sol` | Liquid derivative tokens for vault shares and locked `YB`. |

Interfaces live in `src/interfaces/`; mocked YieldBasis/Chainlink dependencies in `src/mocks/`.

## Quick start

This is a [Foundry](https://book.getfoundry.sh/) project — no Go toolchain required.

```bash
forge build                                          # compile
forge test                                           # run all tests
forge test --match-path test/EquilibriumEndToEnd.t.sol -vvv   # watch the full flywheel
```

Deploy the full system locally (wires up the entire "ownership dance" with mocked dependencies):

```bash
cp .env.example .env        # then fill in PRIVATE_KEY and an RPC URL
forge script script/DeployFlywheel.s.sol --rpc-url <url> --broadcast
```

## Status & limitations

- **Mocked dependencies.** YieldBasis's gauge, voting escrow, gauge controller, and the Chainlink feed are all stubs in `src/mocks/`.
- **Placeholder economics.** `StrategyManager.getStakedAPY` uses a stand-in emissions calculation, and "total staked by others" is mocked via `balanceOf(address(0))`. These need real YieldBasis integration before the optimizer is meaningful.
- **No audit / no fee logic yet.** The 15% performance fee and `veEQM` governance described in the docs are designed but not implemented.

## Repository layout

```
src/            protocol contracts, interfaces, and mocks
test/           Foundry tests (per-contract + EquilibriumEndToEnd integration)
script/         DeployFlywheel deployment script
docs/           whitepaper, tokenomics, emission model, and design decisions
lib/            Foundry dependencies (git submodules)
```

## Documentation

Deeper design material lives in [`docs/`](docs/):

- [Whitepaper](docs/whitepaper.md) — vision, the problem, the solution, architecture, roadmap
- [Tokenomics](docs/tokenomics.md) — `EQM`, `m-ybBTC`, `m-YB`, `veEQM`, performance fee, benefits to YieldBasis
- [Emission model](docs/emissions.md) — the "XP-S curve" `EQM` emission schedule and simulation
- [Design decisions](docs/design-decisions.md) — reward-routing (Convex vs. Yearn), DEX liquidity strategy, open risks
