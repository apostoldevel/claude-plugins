<!-- Reference of the /apostol-project skill: read on demand via the routing table in SKILL.md. -->
## Step 10 — Frontend Integration

### Cookie-Based Auth (the only correct way)

AuthServer implements the **Token Handler** pattern. The browser SPA never touches tokens directly.

**Two cookie pairs coexist:**

| Context | Cookies | Set on | Used for |
|---------|---------|--------|---------|
| **User** | `__Secure-AT`, `__Secure-RT`, `__Host-SID` | password / authorization_code / refresh_token / jwt-bearer grants | authorized user operations |
| **Service** | `__Secure-SAT`, `__Secure-SRT` | client_credentials grant | **legacy** — public/guest operations minted *in the browser*; see the callout below, do not build new front-ends on it |

`__Secure-*` cookies: `HttpOnly; Secure; SameSite=None`; `__Host-SID`: `SameSite=Lax`. The browser sends them automatically.

> **The session cookie is `__Host-SID`** since 2026-08-24 (upstream `module-AuthServer` /
> `module-AppServer`). The prefix is not cosmetic: without it an unprefixed cookie set from a
> neighbouring subdomain over http **overrides the cryptographically verified `__Secure-AT`**,
> because the session cookie is read first. Older code and older docs say `SID`.

> **Cookies are host-only — `Domain=` is not set**, so subdomains do **not** share a session; the
> identity travels between portals as an authorization code, not as a cookie. **In development the
> behaviour looks opposite**: both apps run on `localhost` and a cookie does not distinguish ports,
> so signing into one appears to sign you into the other. Confusing the two reads as "the session
> is sometimes there and sometimes not".

> **`grant_type=password` is the legacy path**, not the one to build a new front-end on — prefer
> authorization code + PKCE where the project allows it.

> **No service session in the browser (2026-09).** The older recipe — the SPA calls
> `/oauth2/token` with `grant_type=client_credentials` and then sends `X-Auth-Context: service` — makes a
> *public* client hold a service session. RFC 6749 §4.4: `client_credentials` is for **confidential**
> clients only; a service token handed to a browser is a public token with the rights of a service user.
> The target is the **BFF / token
> handler** shape (OAuth 2.0 for Browser-Based Apps): AuthServer refuses `client_credentials` to public
> clients (`client_credentials_by_origin: false`), and **AppServer executes the listed guest routes itself
> with its own confidential token** (`guest_routes`: sign-up, password recovery, …); the browser calls those
> routes **anonymously** — no `X-Auth-Context`, and `credentials: 'omit'` (a stale `__Secure-AT` would turn
> the guest call into a 401). Two consequences the redesign found: (1) a platform rate limiter that
> **revokes the calling session** now hits the one shared guest session — limits must key on the client
> address, not the session; (2) password recovery (`ticket`) and external sign-in (`jwt-bearer` →
> `daemon.login`) need the ACL bit `substitute`, which public audiences had only through `system` — give it
> by a dedicated group, not by leaving them in `system`. **Before relying on the two keys, check that your
> pinned `module-AuthServer`/`module-AppServer` carry them** (`grep -r guest_routes src/modules`), and move
> off the browser service session if your project still uses it.

### Three traps that cost a front-end a day each

**1. `/<entity>/get` on a foreign or non-existent object answers `200` with a row of all-`null`
fields — not `404`.** A branch on `err.status === 404` is dead code, and the null row travels on as
"we have data", rendering a card of dashes with an empty title: not a wrong message, but the
absence of any message. **The emptiness test is `id` in the response, not the HTTP code.** And
because RLS deliberately does not distinguish "no such object" from "no rights", the message must
not claim the record does not exist.

**2. A state transition is requested by method identifier, not by action code.** A method is the
triple *class + state + action*, and the same code means different things in different states
(`enable` from `created` is "Activate", from `laid_up` is "Return to service"). Canonical route is
`/method/run {id, method}`. **The labels come from the server already localised and depend on the
state** — a local dictionary keyed by action code will write the wrong word, confidently. `sequence`
defines button order.

**3. The field set of `Object<X>` is what the entity *can* expose, not what it *does*.** `api.<entity>`
selects columns explicitly one level below, so a type built from the view can be wider than the
wire and diverge in silence. **Verify a contract against the wire, not against the compiler** —
take a live `/<entity>/list` row and compare its key set with the declared type: no field on the
wire undeclared, none declared but absent, except those marked optional with a reason. This has
caught a real divergence even where the hand-written contract matched field for field.

**Nullability comes from the schema, not from the data.** Deriving it from a seed teaches you what
one person happened to fill in. The reliable sources are `NOT NULL` in the table **and the join
kind** in the view: anything arriving through a `LEFT JOIN` to a `*_text` table is nullable by
construction — including the display name itself.

**Give the UI library its locale** (`ConfigProvider` for Ant Design). Otherwise its own strings stay
English inside a localised interface — "No data", "20 / page" — and it reads as part of the library
rather than as a defect. Easy to look at for a week without seeing.

**Frontend code rule of thumb:**

```javascript
// 1–2. Guest route (sign-up, recovery, identifier) — anonymous; AppServer runs it with its own
//      confidential token (`guest_routes`). No client_credentials and no X-Auth-Context in the browser.
await fetch('/api/v1/sign/up', {
  method: 'POST',
  credentials: 'omit',
  body: JSON.stringify({ ... })
});

// 3. User login
await fetch('/oauth2/token', {
  method: 'POST',
  credentials: 'include',
  body: 'grant_type=password&username=USER&password=PASS&...'
});

// 4. User API call (default context)
await fetch('/api/v1/whoami', { credentials: 'include' });
// Behind AppServer (/api/v1) or GatewayAPI (/api/v2) token refresh is server-side: you get a 200 unless the session is fully expired.

// 5. On 401 → session fully expired → redirect to login
```

**Anti-patterns:**
- `localStorage`/`sessionStorage` for tokens (XSS-exposable; cookies are HttpOnly).
- Tracking `expires_in` and scheduling refresh in JS (AppServer / GatewayAPI do it server-side; only a SPA with neither behind it refreshes itself, on 403).
- Sending `Authorization: Bearer` from the browser when cookies are available.
- Minting a service session in the browser (`grant_type=client_credentials`, `X-Auth-Context: service`) — a
  public client cannot keep a secret; guest routes are executed server-side (see the service-session callout above).

### WebSocket

Connection URL: `wss://[ws.]<host>/session/<code>[/<identity>]` (session code = 40 chars, identity multiplexes connections).

JSON-RPC frame: `{t, u, a, c, m, p}` — t=type (0=OPEN, 1=CLOSE, 2=CALL, 3=CALLRESULT, 4=CALLERROR), u=UUID, a=action, c=errorCode, m=errorMessage, p=payload.

Subscribe to events:

```json
{"t":2, "u":"<uuid>", "a":"/observer/subscribe",
 "p":{"publisher":"notify",
      "filter":{"classes":["bridge_entry"], "actions":["create"]},
      "params":{"type":"object"}}}
```

7 registered publishers: `notify`, `notice`, `message`, `replication`, `log`, `geo`, `file` (the last is accepted but never delivers). 4 delivery types: `notify` (raw), `object` (full via `api.get_*()`), `mixed`, `hook` (server-side `api.run`).

### Hooks for Server-Side Automation

```json
{"params": {"type": "hook",
            "hook": {"method": "POST",
                     "path": "/api/v1/replication/enqueue_critical",
                     "payload": {}}}}
```

Server runs the hook on every event match. Powerful for event-driven workflows without external pollers.

---

### Hiding is not refusing — the client mirrors the server's decision

A client predicate — a menu item, a route layout, a button, a money action — is a copy of a server gate, never a decision
of its own. Find the server function that decides (the route gate, `CheckObjectAccess`, the function that classifies a
debt) and mirror its terms from what the server returns (`whoami`), not from raw fields: `balance < 0` is a ledger fact,
not "may pay". A section usually has two gates — the menu item and the route layout — and both call one predicate, made
once in a shared component. A screen fed by sources behind different gates hides per source, loads with `allSettled` and
names the missing half. `/<entity>/method` lists methods to roles that are refused on run (`access-control.md`). Write
where the server refusal is measured (a test, `file:line`) and where it is only inferred.

Test traps of a particular front-end (clocks, `waitFor`, mocks, its build) live in that project's wiki, not here.

### Who refreshes, and signing out without AppServer

- **Refresh** happens where the cookie is checked: AppServer for `/api/v1` (`check_auth` → `token_refresh_and_fetch`,
  `Workers/AppServer/AppServer.cpp:393–411`); `GatewayAPI` for `/api/v2` — it *is* an AppServer and inherits `check_auth`
  (`Workers/GatewayAPI/GatewayAPI.hpp:52`); a SPA served by a process without either (e.g. a device console) refreshes
  itself on 403, and then every 403 costs it a `/oauth2/token` round-trip.
- **Sign-out without AppServer**: `POST /oauth2/revoke` on AuthServer (`AuthServer.cpp` `do_revoke`, contract in the
  comment above it). The browser form needs `__Host-SID` (SameSite=Lax — proves the request came from this site) and
  `Sec-Fetch-Site: same-origin` or `none`; refused, the cookies are left alone. Send it **without a body** — a body,
  even `{}`, switches to the token-in-body form, where an empty `token` is a 400. 503 — cookies erased, the
  session in the base still open (RFC 7009 §2.2.1).
