# Future publishing bridge (outline only)

This file outlines a future, optional publishing path from repo-root `knowledge/` into the marketing site’s static docs. **This is an outline only**: no sync is wired into builds yet.

## Target (current website layout)

- Website docs are served from: `web/src/public/docs/`
- Current Ignitus AI docs live at: `web/src/public/docs/ignitus/`
- Current website `llms.txt` lives at: `web/src/public/llms.txt`

## Recommended future approach

### 1) Keep `knowledge/` as the authoring source-of-truth

- `knowledge/ignitus-core/**` remains the authoritative Ignitus-specific corpus.
- `knowledge/encyclopedia/**` remains generic and does not mention Ignitus.

### 2) Add a *selective* sync script (when you’re ready to publish)

Create a script (example name): `scripts/sync-knowledge-to-web.mjs` that:

- Copies `knowledge/ignitus-core/*.md` → `web/src/public/docs/ignitus/*.md`
- Copies `knowledge/ignitus-core/contracts/*.sol` → `web/src/public/docs/ignitus/*.sol`
- Optionally copies a curated encyclopedia subset to `web/src/public/docs/encyclopedia/**` (only if you want it public)

Key properties:

- Deterministic output (always the same results from same inputs).
- Safe by default (do not publish encyclopedia unless explicitly enabled).
- Does not require network access.

### 3) Extend the website `llms.txt` (when published)

Options:

- Keep `web/src/public/llms.txt` as the canonical public index and add a new section pointing at published encyclopedia pages.
- Or publish `knowledge/llms.txt` (as `web/src/public/knowledge/llms.txt`) and link to it from the public `llms.txt`.

### 4) Keep validation in place

- Continue to run `node knowledge/scripts/validate-knowledge.mjs` in CI.
- If the encyclopedia becomes public, keep the denylist rules strict.

