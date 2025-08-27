Project Outline: The Equilibrium Protocol Part 1: Whitepaper Outline Title: The Equilibrium Protocol: Maximizing Yield on YieldBasis

Abstract: The Equilibrium Protocol is a yield-optimization and governance-aggregation layer built on top of YieldBasis. It introduces a sophisticated "meta-vault" that automatically shifts user deposits between the two primary yield strategies available on YieldBasis: direct trading fee accrual and YB token emission farming. By pooling user assets, Equilibrium accumulates a dominant veYB position, allowing it to boost its own rewards and create a powerful, self-reinforcing yield flywheel. For the user, Equilibrium offers a single liquid asset, m-ybBTC, that provides the optimal, hands-free, and auto-compounding yield on their BTC holdings.

Introduction: The YieldBasis Dilemma * 1.1. Overview of the YieldBasis Protocol and its IL-free liquidity pools. * 1.2. The Core User Decision: Staking vs. Not Staking ybBTC. * 1.3. Analyzing the Game Theory: How yield opportunities shift based on the percentage of staked ybBTC. * 1.4. The Problem Statement: The average user is not equipped to manually monitor and frequently switch strategies to maximize their returns.

The Equilibrium Solution: A Dual-Strategy Super-Vault * 2.1. Introducing the Equilibrium Protocol: A hands-free layer for optimal yield. * 2.2. The Two Pillars of Equilibrium: * Pillar 1 (Convex Model): Aggregating veYB power by max-locking all farmed YB tokens to perpetually boost rewards. * Pillar 2 (Yearn Model): An automated market maker (AMM) for yield strategies, intelligently switching the entire pool's assets between staking and fee accrual. * 2.3. The User Benefit: A single, liquid deposit token (m-ybBTC) that represents a share in this dynamically managed, high-yield pool.

Core Architecture: How Equilibrium Works * 3.1. The EquilibriumVault: The primary user-facing contract for ybBTC deposits and the heart of the strategy-switching mechanism. * 3.2. The YBLocker: The protocol's governance engine, responsible for accumulating and deploying veYB power. * 3.3. The StrategyManager: The on-chain "brain" containing the mathematical logic for comparing the APR of staking vs. fee accrual. * Formula for Staked APR (based on YB emissions & price) * Formula for Unstaked APR (based on a trailing average of trading fees) * 3.4. The RewardDistributor: The protocol's treasury, collecting all forms of yield and distributing them to participants.

The Maximized Assets (m-Assets) * 4.1. m-ybBTC: The liquid derivative for ybBTC. Explain how it accrues value from the underlying strategies. * 4.2. The Exit Ramp: Detailing how users can withdraw at any time by swapping their m-ybBTC for ybBTC in a dedicated Curve/Uniswap liquidity pool. * 4.3. m-YB: The liquid derivative for YB locked in the protocol.

Tokenomics: The EQM Token * 5.1. Purpose: EQM is an incentive and governance token. Its primary function is to bootstrap protocol TVL and decentralize control. * 5.2. Distribution: Detail the emission schedule. A large portion will be allocated to m-ybBTC stakers to incentivize deposits. * 5.3. Value Proposition: The value of EQM is derived from its governance power over the Equilibrium Protocol's vast veYB holdings and its control over the protocol's treasury and future direction.

Governance: Path to Decentralization * 6.1. Phase 1: Multi-Signature Control: Initial launch will be managed by a core team multi-sig for security and agility. * 6.2. Phase 2: DAO Governance: A roadmap for transitioning all protocol controls to EQM token holders.

Fee Structure * 7.1. Detail the performance fee taken on all yield generated. * 7.2. Explain how this fee revenue will be used to fund operations, development, and build the DAO treasury.

Security * 8.1. Commitment to multiple professional smart contract audits. * 8.2. Use of a multi-signature wallet for all administrative functions. * 8.3. Plans for a public bug bounty program.

Roadmap * 9.1. Outline future plans, such as adding vaults for other YieldBasis assets (e.g., ybETH) or expanding the utility of EQM.

Part 2: Project Development 

Phases Phase 1: Core Contracts (The Vaults & Tokens)

Goal: Build the foundational smart contracts for holding assets and issuing liquid derivatives. Contracts to Build: EquilibriumVault.vy: The main vault for ybBTC. Must include the state-switching functions (_stakePool, _unstakePool) and permissioning for the StrategyManager. YBLocker.vy: The vault for YB. Will interact with YieldBasis's VotingEscrow to max-lock tokens. m_ybBTC.vy: The ERC20 contract for the liquid ybBTC derivative. m_YB.vy: The ERC20 contract for the liquid YB derivative. 

Phase 2: The Control System (Controls & Automation)

Goal: Create the on-chain logic and off-chain infrastructure for automated strategy management. Components to Build: StrategyManager.vy (On-Chain): The "brain" contract. Implement the getStakedAPR() and getUnstakedAPR() view functions. Build the core switchStrategy() execution logic with a configurable hysteresis buffer. Implement a data accumulator for trailing-average fees, updatable by a keeper. Keeper Bots (Off-Chain): StrategyKeeper: The bot that monitors the StrategyManager's APRs and calls switchStrategy() when profitable. HarvestKeeper: The bot that periodically harvests all forms of yield (YB, ybBTC fees) and sends them to the RewardDistributor. VoteKeeper: The bot that casts the protocol's vote on the YieldBasis GaugeController each week. 

Phase 3: The Economic Engine (Tokenomics & Rewards)

Goal: Design and implement the protocol's native token and the system for distributing it. Contracts to Build: EQM.vy: The ERC20 contract for the Equilibrium governance token, with a defined emission schedule. RewardDistributor.vy: The central treasury. It receives all yield and holds it for distribution. Booster.vy: The staking contract where users stake their m-ybBTC (and potentially other assets like LPs) to earn EQM emissions. 

Phase 4: The User Experience (Frontend & UI)

Goal: Create a simple, intuitive interface that hides all the underlying complexity, catering to the "Set-and-Forget" user. Pages/Components to Design: Deposit Page: A single, clear call-to-action: "Deposit your ybBTC (or BTC via a Zap) to get m-ybBTC and start earning." Stake Page: A simple interface for users to stake their m-ybBTC into the Booster to earn EQM rewards. Dashboard: A clean display of key metrics: The user's total balance and its value. The current APR of the EquilibriumVault. The current strategy of the vault (Staked vs. Unstaked). The user's pending EQM rewards. Liquidity Pool Page: A simple link and UI to guide users to the m-ybBTC / ybBTC pool so they can easily enter or exit their position. 

Phase 5: Launch & Decentralization

Goal: Ensure a secure launch and establish a clear path to community ownership. Process: Security: Complete multiple, independent smart contract audits. Launch a bug bounty program. Initial Setup: Deploy all contracts. Configure the StrategyManager. Set up the core team multi-signature wallet (e.g., 3-of-5 Gnosis Safe) as the owner of all contracts. Bootstrap Event: Launch the Booster contract to begin EQM emissions and attract the initial TVL. DAO Transition: Once the protocol is stable and EQM is sufficiently distributed, begin the process of transitioning ownership of the protocol contracts from the multi-sig to on-chain governance controlled by EQM token holders.
