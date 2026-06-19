# Equilibrium Protocol — Documentation

Design and economic reference for the Equilibrium Protocol. These are working
design notes captured during development; treat them as the intended design,
not a description of fully-implemented behavior (see the
[root README](../README.md) for current build status).

## Contents

- **[Whitepaper](whitepaper.md)** — mission, the YieldBasis dilemma, the
  dual-strategy solution, core architecture, and roadmap.
- **[Tokenomics](tokenomics.md)** — `EQM` supply and allocations, `veEQM`
  governance, the `m-YB` and `m-ybBTC` liquid wrappers, the performance fee,
  and how Equilibrium benefits YieldBasis.
- **[Emission model](emissions.md)** — the "XP-S curve" `EQM` emission
  schedule, the simulation behind it, and the resulting numbers.
- **[Design decisions](design-decisions.md)** — the Convex-vs-Yearn
  reward-routing fork, the DEX liquidity strategy for the `EQM` allocation,
  and an honest list of open risks to refine.
