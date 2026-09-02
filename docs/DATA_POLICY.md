# Feather Audit Data and Retention Policy

**Contract phase:** A0  
**Status:** Draft decision baseline for team approval  
**Applies to:** `audit_event.v1`

## Policy principles

- Collect the minimum information needed to identify, correlate, and review a significant event.
- Store stable typed identifiers; display-name snapshots are conveniences, not identity authority.
- Never accept credentials, tokens, webhook URLs, unrestricted payloads, or raw database rows.
- Assign sensitivity and retention before persistence.
- Apply redaction on the server before results, exports, or external notifications leave Audit.
- Retention defaults are operational defaults, not legal advice. Operators must review them for their community and jurisdiction.

## Sensitivity classes

Sensitivity is ordered from least to most protected. A caller or destination ceiling permits only that class and lower, subject to field-level rules.

| Class | Intended content | Default access | External delivery |
|---|---|---|---|
| `public` | Information already intentionally public in the server experience | Authorized ordinary Audit views | Allowed through an approved template |
| `internal` | Routine staff/operational facts and stable non-secret identifiers | `staff.audit.search` | Allowed only to destinations with an `internal` ceiling |
| `restricted` | Raw platform identifiers, sensitive economy detail, private moderation context, protected staff actions | `staff.audit.sensitive.view` plus purpose controls | Denied by default in v1; use a separately approved projection |
| `sealed` | Sealed Justice material, break-glass evidence, credential-exposure incident detail, exceptionally protected narratives | Explicit sealed capability and reason; access always recorded | Prohibited in v1 |

An event's class is the minimum protection for the complete stored event. Registered field policy may classify individual fields more strictly. A destination never receives a field above its ceiling even if the event itself is otherwise eligible.

### Prohibited content

The following must be rejected before event persistence, not merely marked `sealed`:

- Passwords, bearer tokens, API keys, private keys, session tokens, and webhook URLs.
- Full authentication headers, cookies, connection strings, or environment dumps.
- Raw request bodies, raw database rows, arbitrary stack/local dumps, or unrestricted serialized objects.
- Payment-card, banking credential, or equivalent real-world financial secrets.
- Binary content or attachments in the canonical event.

Platform license identifiers and network addresses are not categorically prohibited, but they are `restricted`, must have a registered need, and must not appear in `summary`.

## Retention classes

Retention is separate from sensitivity. The initial defaults are conservative starting points and must remain operator-configurable.

| Class | Default active retention | Default archive retention | Intended events |
|---|---:|---:|---|
| `operational` | 30 days | none | Routine diagnostics-worthy events and low-risk denied requests |
| `administrative` | 365 days | 365 additional days | Staff actions, moderation mutations, Audit policy changes |
| `security` | 730 days | 1,825 additional days | Authority changes, break-glass use, integrity and credential incidents |
| `financial` | 2,555 days | none by default | Economy transfers, issuance, destruction, and adjustments |
| `legal` | 2,555 days | none by default | Justice lifecycle and protected access events |

`2,555 days` is approximately seven years. These values do not assert a statutory requirement. A production installation must explicitly accept or override the defaults before retention jobs are enabled.

Access events inherit at least the retention class of the protected operation they record. Redaction-history metadata uses `security`. Notification delivery diagnostics use `operational` unless they document a security incident.

## Event-class defaults

| Event family | Default sensitivity | Default retention |
|---|---|---|
| Routine Admin mutation | `internal` | `administrative` |
| Blocked high-risk Admin action | `restricted` | `security` |
| Authority grant, revoke, policy, or break-glass change | `restricted` | `security` |
| Economy transfer | `internal` | `financial` |
| Economy issuance, destruction, or privileged adjustment | `restricted` | `financial` |
| Privileged Inventory inspection or adjustment | `internal` or `restricted` by schema | `administrative` |
| Justice lifecycle fact | `restricted` | `legal` |
| Sealed Justice access | `sealed` | `legal` |
| Audit sensitive search/export/integrity/redaction | `restricted` | `security` |
| Notification delivery diagnostic | `internal` | `operational` |

An event schema may raise these defaults but must not lower them without an approved policy revision.

## Data minimization and snapshots

- `actor`, `targets`, and `references` use stable IDs and bounded optional display snapshots.
- Display snapshots may include a character or organization name as observed at event time, but must not be used for authorization or identity resolution.
- Economy context records amount, currency, and transaction/reference IDs, not reconstructed balances unless the registered event specifically requires before/after values.
- Moderation events reference the case, warning, or ban record; they do not copy complete case narratives into context.
- Justice events reference authoritative records and use an explicitly registered safe summary. Sealed narrative is not duplicated by default.
- `summary` is safe, bounded display text. It must not contain licenses, network addresses, secrets, or the only copy of a material fact.

## Redaction and deletion

Append-only identity and legitimate privacy remediation must coexist:

- Preserve non-sensitive event identity, producer, type, time, redaction state, and reason for remediation.
- Store sensitive payload fields behind a redaction overlay or separable encryption boundary.
- Propagate authorized redaction to active payloads, indexes, caches, pending exports, and covered archives.
- Record an attributable redaction event without copying the removed value.
- Document the expiry timeline for backups that cannot be rewritten immediately.
- Recalculate or transition integrity metadata in a way that proves the redaction was authorized.

A tombstone without removal of the protected value is not deletion.

## External notification policy

- Audit storage always occurs before notification evaluation.
- Discord and other external systems receive provider-specific safe projections, never raw stored context.
- `sealed` external delivery is prohibited in v1.
- `restricted` delivery is denied by default and requires a future explicitly reviewed projection and destination policy.
- Mentions, identifiers, narratives, and numeric details are allowlisted per template.
- A rule threshold is a review signal, not proof of wrongdoing or authority for automated punishment.

## Logging and diagnostics

Operational logs may include event ID, event type, source resource, result code, and correlation ID. They must not include raw context, protected identifiers, destination secrets, or provider response bodies by default.

Quarantine diagnostics record bounded field paths and stable rejection codes. They must not reproduce a detected secret.

## Production decisions still requiring approval

- Accept or override each default retention duration.
- Define the archive storage location, encryption, and access roles.
- Define who can authorize redaction and sealed access.
- Define backup coverage and maximum persistence after an approved deletion.
- Decide whether any `restricted` external projection is allowed after v1.
