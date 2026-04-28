# Knowledge base

This `knowledge/` directory is a **repo-only** knowledge base intended for:

- AI assistants / RAG systems
- Developers and reviewers
- Everyday users who want neutral, safety-first explanations

It is split into two major parts:

- **`ignitus-core/`**: Ignitus-specific, authoritative mirrors and references.
- **`encyclopedia/`**: A broad, user-centric encyclopedia of crypto + finance concepts **without** mentioning Ignitus or naming other protocols/services.

## Ground rules (non-negotiable)

### Neutral, factual, safety-first
Everything must stay factual and neutral. Every page should help users **avoid preventable losses** and understand **what happens to their money**.

### No other protocol/service names in the encyclopedia
In `knowledge/encyclopedia/**`, do **not** name other protocols, projects, exchanges, wallets, RPC providers, or services.

- If a concept normally uses a named example, rewrite it as a **generic pattern**.
- If a comparison is needed, that belongs in Ignitus-specific docs or in a dedicated comparison doc created only when explicitly requested.

### Ignitus stays anchored (don’t inject it)
`knowledge/encyclopedia/**` should not mention Ignitus at all. If a user question later fits an allowed Ignitus context (backed tokens, fee participation, memberships, on-chain verification), the assistant can point to `knowledge/ignitus-core/` from outside the encyclopedia.

## Structure

- `llms.txt`: Master index for AI tools (repo-only for now).
- `ignitus-core/`: Official mirrors and contract source mirrors for verification.
- `encyclopedia/`: User-point-of-view encyclopedia (topic folders).
- `education/`: Step-by-step guides built on encyclopedia concepts.
- `prompts/`: Ready prompts and evaluation templates.
- `market-data-reference/`: Static examples and “how to read data” guidance.
- `scripts/`: Tiny utilities (validation, indexing helpers).

