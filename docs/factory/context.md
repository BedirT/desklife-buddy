# Context compilation and budgets

The factory exposes and hashes everything it controls without pretending to
reveal a vendor-owned system prompt.

For each invocation, the context packet records ordered repository prompt text,
included file paths and SHA-256 values, combined context hash, Git SHA and clean
state, issue/plan/contract/product decisions, changed-file map, nearest module
instructions, relevant failure evidence, client/provider/model and version,
tool/permission policy, byte/token estimate, and excluded-context summary.

The launch manifest inventories the isolated user/config root, automatically
discovered instructions, selected skill projection, hooks/extensions/MCPs,
environment overlays, exact prompt injection, source/network policy, sandbox,
timeout, output schema, retry rule, minimum version, and fallback identity.
Secrets and proprietary inputs are represented only by a safe hash when
allowed, redacted summary, provenance class, retention rule, and explicit role
authorization.

`scripts/factory context compile` rejects dirty input, duplicate paths,
unselected skill content, unknown environment keys, over-budget packets, and
any mismatch between prompt, file, skill, client, or output-schema digests.
Codex, Claude Code, and Pi then receive the same invocation hash through thin
versioned adapters. Their actual differences remain explicit:

- Codex receives a verified schema file path and supports new/resume sessions;
- Claude Code receives the verified canonical schema inline and supports
  new/resume/fork sessions;
- Pi receives downstream schema validation and supports new/resume/fork sessions.

The harness never advertises unsupported fork behavior, inherits API keys, or
uses provider output without normalizing its terminal JSON stream. Exactly one
correction-only retry may repair invalid result structure; it cannot perform new
work or extend the role budget.

## Initial ceilings

| Risk tier | Context per role | Role calls | Repair rounds | Wall time | Command timeout |
|---|---:|---:|---:|---:|---:|
| `low` | 131072 bytes | 4 | 1 | 45 min | 10 min |
| `medium` | 262144 bytes | 10 | 2 | 3 hr | 20 min |
| `high` | 262144 bytes | 20 | 3 | 8 hr | 30 min |
| `control-plane` | 262144 bytes | 20 | 3 | 8 hr | 30 min |

`policy.json` is the machine-readable authority. A contract may tighten but not
weaken its tier. Crossing twice the expected file/line scope pauses for contract
re-evaluation.

## Progressive disclosure

Always-loaded law and role metadata stay compact. The router first considers
registry metadata, then projects only deterministically selected active skills
into the client's isolated discovery root. Reading a skill body, reference,
script, or asset is separately recorded. Unselected metadata and content are
not present in a qualifying projection.

Every skill declares independent metadata, body, reference, and resource byte
ceilings plus allowed one-level disclosure paths. Context growth must be earned
by a contract dependency. Legacy skills are available only to manual bootstrap
sessions and cannot contribute qualifying evidence.
