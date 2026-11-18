# CoinOS: trackable Lightning-address payments (LNURL-pay → BOLT 11 → POST /payments)

| Field | Value |
| ---- | ---- |
| Status | In progress — S0–S6 done; S7 (live tests) waits for the test accounts, S8 (release) is the maintainer's |
| Branch | `feature/coinos-safe-lnaddress-payment` |
| Owner | Igor (maintainer) / Claude Code Opus 5.5 |
| Created | 2026-11-18 |
| Last update | 2026-11-18 |
| Origin | External feature request from a library user (Delphi server paying Lightning addresses from a CoinOS account), received by the maintainer on 2026-11-18. |

## 1. Goal

Today the only practical way to pay a Lightning address with the library is `TAPICoinOS.PostPaymentLnAddress`, which calls CoinOS `POST /send/:lnaddress/:amount`. CoinOS resolves the address, fetches an invoice and pays it in one call; the caller never sees the invoice before money moves. If the HTTP call dies mid-way the caller cannot ask what happened and cannot retry without risking a double payment.

The library will let the caller run the three steps itself and keep the invoice in between:

1. Resolve the Lightning address (LUD-16 → LUD-06) and fetch an invoice for an exact amount.
2. Decode the invoice (BOLT 11) to check amount, network and expiry, and store it.
3. Pay that exact invoice with `POST /payments`; after any doubt, ask `GET /payments/<invoice>` what happened. Retrying with the **same** invoice is safe under the conditions in §6.

Everything added to the library must also be shown in the CoinOS demo (maintainer rule).

## 2. Sources checked (2026-11-18)

| Source | How | Result |
| ---- | ---- | ---- |
| Local repo vs Bitbucket | `git fetch --prune origin`, `git rev-list --left-right --count master...origin/master` | `0 0` — local `master` (`6c5424f`) equals `origin/master`. Bitbucket has **no tags**. |
| GitHub mirror `igorbastosib/ideal-library` | GitHub REST API + raw files | Separate history. Tags `0.0.0`…`0.0.6`; `0.0.6` = `main` = `b26f839` (2026-07-05). `Api/IdeaL.Lib.Api.pas`, `Api/Bitcoin/IdeaL.Lib.Api.Bitcoin.CoinOS.pas` and `boss.json` at `0.0.6` are byte-identical (ignoring CR) to local `master`. So "version 0.0.6" in the request = our current code. `boss.json` says `0.0.5` in both. |
| CoinOS server | Raw files from `https://git.coinos.io/coinos-server.git/plain/<path>?h=master`: `index.ts`, `routes/payments.ts`, `lib/payments.ts`, `lib/utils.ts`, `lib/db.ts`, `lib/auth.ts` | Branch `master` HEAD is still `c0a0f5c`, the commit the requester read. |
| `github.com/coinos/coinos-server` | HTTP | `404`, as the requester said. |
| CoinOS live API | `GET https://coinos.io/api/payments/<BOLT 11 spec test invoice>` (public, no auth, invoice from the spec, not a real one) and `GET /api/decode/<same>` | See fact 5 below. |
| Specs | `lightning/bolts` `11-payment-encoding.md`, `lnurl/luds` `06.md`, `12.md`, `16.md` (raw GitHub, master) | Used for §3/§4. |
| Delphi RTL | `C:\Program Files (x86)\Embarcadero\Studio\23.0\source\rtl\net\*.pas` (Delphi 12, compiler 36.0) | Timeout defaults, redirect defaults, DNS lookup API. |
| Baseline build | `dcc32` console project using `IdeaL.Lib.Api` + `IdeaL.Lib.Api.Bitcoin.CoinOS` | Compiles; warnings W1010 (`Post`/`Get` hide the virtual base methods), hint H2164 (`LInt64` unused in `GetRo`). |

Line numbers below refer to coinos-server `c0a0f5c` and to this repository at `6c5424f`.

## 3. Verification of the requester's "facts from CoinOS's code"

| # | Claim (short) | Verdict | Evidence / nuance | Impact on the plan |
| ---- | ---- | ---- | ---- | ---- |
| 1 | Routes `POST /payments` (auth), `GET /payments` (auth), `GET /payments/:hash` (no auth), `POST /send/:lnaddress/:amount` (auth) | ✅ True | `index.ts:78-80, 90`. Also present and useful: `GET /decode/:bolt11` (no auth, server-side decode, `index.ts:93`), `POST /lightning/quote` (auth, routing + platform fee quote, `index.ts:95-106`). | Optional extras in §5.2. |
| 2 | `POST /payments` reads `{amount, hash, fee, fund, memo, payreq}`, strips whitespace and lowercases `payreq`; CoinOS-owned invoice → internal, other → Lightning; answers the payment record | ✅ True | `routes/payments.ts:58, 73, 85-94, 111`. Extra: `amount` is used for **amountless** invoices; internal detection is `getInvoice(payreq)` (an invoice issued by CoinOS); paying your own invoice fails with "Cannot send to self". | `PostPayment` keeps optional `AAmount` out of scope (LNURL invoices always carry an amount); documented. |
| 3 | Fee field is `fee`, not `maxfee`; a cap below the quoted routing fee fails before any debit | ✅ True, with more | `lib/payments.ts:1051-1058`: explicit `fee` < quoted → `"Routing fee of ⚡️X required, max fee is ⚡️Y"` before `debit()`. **Also**: `fee` omitted → CoinOS uses its own quote (`:1044`, `:1057-1058`); `fee` < 0 → error; `fee` > `max(1000, 5% of amount)` → `"Routing fee … exceeds the … limit"` (`checkRoutingFee`, `:837-840`, called at `:1065`). An explicit `fee: 0` counts as a cap of 0 (see finding F2). | Send `fee` only when > 0; document the upper limit. |
| 4 | Both routes call `requirePin({body, user})`; an account with a PIN must send `pin` | ✅ True | `routes/payments.ts:81` and `:789`; `lib/auth.ts:25-27`: `if (user.pin && user.pin !== body.pin) fail("Invalid pin")`. Also `POST /bitcoin/send` (`:728`). | Add `APin` to `PostPayment` and `PostPaymentLnAddress`. |
| 5 | `GET /payments/:hash` → `getPayment(hash)`, no lowercasing; no record → `res.send(undefined)` = **HTTP 200 with empty body**; errors via `bail()` = HTTP 500 | ⚠️ Partly wrong | Code: `routes/payments.ts:208-222`, `lib/utils.ts:66-70` (`getPayment` follows the `payment:<id>` pointer), `lib/utils.ts:23` (`bail` = `res.code(500).send(msg)`). **Live API on 2026-11-18**: no record → `HTTP/1.1 200 OK`, `Content-Type: application/json; charset=utf-8`, `Content-Length: 4`, body **`null`** (same for lower- and uppercase invoice). Not an empty body. | `GetPayment` must treat both an empty body **and** the JSON literal `null` as "no record". |
| 6 | For an internal invoice, `GET /payments/<invoice>` returns the **recipient's** record (positive amount, confirmed, type internal, with `with`) | ✅ True | `debit()` writes `payment:<invoice>` → payer's id (`lib/payments.ts:319`); `credit()` overwrites the same key with the recipient's id and also archives it (`:486-487`); `get` adds `with` for internal and fund types (`routes/payments.ts:214-216`), then `res.send(p)` (`:217`). | State helper must not rely on the amount sign; documented. |
| 7 | Paying the same invoice twice is refused: "Invoice has already been paid", "Payment is already underway", "Previous attempt is still settling" (Lightning); "Invoice already paid" (internal) | ✅ True, **but the guard is not atomic** | Lightning: `lib/payments.ts:1067-1083` (`listpays` complete/pending + `sIsMember("pending", pr)`), then `debit()` (`:1085`), then `sAdd("pending", pr)` (`:1096`). Internal: `:204-205` (`invoice.received >= amount`). Check-then-act: two **concurrent** requests with the same invoice can both pass the guards and both be debited; the second normally fails at the node and is reversed, but this is not a guarantee the library should lean on. | Safe retry = **sequential** retry after the previous call has ended and after a grace period (§6). Never two in-flight calls for one invoice. |
| 8 | No record = never debited or reversed; `confirmed:false` = in flight; `confirmed:true` = paid | ✅ True, with nuances | `confirmed: ![lightning, bolt12].includes(type)` at debit (`lib/payments.ts:310`); `reverse()` deletes `payment:<id>` and `payment:<hash>` (`:1593-1617`). Nuances: (a) "pending" can last **hours or days** for hold invoices (comment at `:305-308`); (b) "no record" also covers "request never reached CoinOS" and "rejected before debit" (PIN, fee cap, balance, quote) — all safe to retry; (c) "no record" can be **transient**: between the arrival of `POST /payments` and `debit()` CoinOS spends time on the route quote and `listpays`, so a status check made right after a client-side timeout can read `null` while the first request is still about to debit. `gf()` falls back to an archive store (`lib/db.ts:156-164`); Lightning debits are not archived, so a reversal really clears the pointer. | §6 grace period; `psPending` must be treated as "wait", never as "failed". |
| 9 | Lightning sends use `xpay` with `retry_for: 60`; a payment call may take ~60 s | ✅ True (lower bound) | `lib/payments.ts:1105-1124`. Before that: a route quote (`:1044`) and `listpays` (`:1067`). So 60 s is the minimum CoinOS may hold the call, not the maximum. | Payment timeout must be well above 60 s (90 s recommended, configurable). |
| 10 | `POST /send/:lnaddress/:amount` reads only `fee`, fetches `/.well-known/lnurlp/<user>`, checks min/max, calls the callback, pays `pr`; no amount check; memo from metadata; never returns the invoice before paying | ✅ True, with nuances | `routes/payments.ts:780-817`. Reads `fee` (`:786`) and `pin` (via `requirePin`, `:789`). Callback is built as `${callback}?amount=…` (`:800`) — breaks callbacks that already have a query string. Memo is `metadata["text/plain"]` (`:796`), but LUD-06 `metadata` is a JSON-encoded **string**, so this is `undefined` and the memo ends up `""`. After a **successful** call the returned record does contain the invoice (`hash`), so the problem is exactly the failure case. | Confirms the need for the three-step path. |

## 4. Verification of the "issues found in the library (0.0.6)"

| # | Claim | Verdict | Evidence | Note |
| ---- | ---- | ---- | ---- | ---- |
| a | `PostPayment` sends `maxfee`; ignored by CoinOS; FPC always adds it, Delphi only when > 0 | ✅ True | `CoinOS.pas:562` (FPC, always) and `:573-574` (Delphi, `> 0`). | With `maxfee` ignored, CoinOS used its own quote, so callers never had a cap. Switching to `fee` **enforces** caps that were ignored before: payments that worked with a too-low or too-high `AMaxFee` will now fail. Release note needed. |
| b | No memo, no pin, no invoice normalisation | ✅ True | `CoinOS.pas:143, 548-581`. | — |
| c | No call for `GET /payments/:hash`; `GetInvoice` is the receive side | ✅ True | `CoinOS.pas:283-289` calls `/invoice/:id` (`index.ts:50`, `invoices.get`). | — |
| d | Delphi `Post` raises on anything but 200, `Get` accepts 2xx | ✅ True | `IdeaL.Lib.Api.pas:134` vs `:194`. FPC: both check `<> 200` (`:112`, `:177`) and the FPC message has no body. `TAPICoinOS.GetRo` and `GetPayments` bypass the base class with their own `<> 200` checks (`CoinOS.pas:245`, `:391`). | — |
| e | No response timeout on Delphi `THTTPClient`; on Linux "effectively unbounded" | ⚠️ Not accurate for Delphi 12 | Delphi 12 `TURLClient` defaults: `DefaultConnectionTimeout = 60000`, `DefaultSendTimeout = 60000`, `DefaultResponseTimeout = 60000` (`System.Net.URLClient.pas:628-630, 2161-2163`), applied on Windows (`WinHttpSetTimeouts`, `System.Net.HttpClient.Win.pas:1985`) and Linux (`CURLOPT_CONNECTTIMEOUT_MS` / `CURLOPT_TIMEOUT_MS`, `System.Net.HttpClient.Curl.pas:270-285`). Older Delphi versions not checked. FPC `TFPHttpClient`: the library sets only `ConnectTimeout` (30 s in `Post`, 20 s in `GetRo`/`GetPayments`, nothing in `Get`); `IOTimeout` is left at its default, which to our knowledge is 0 = no timeout (to be verified when FPC is available). | The request is still right for a different reason: a **60 s** client default is about the same as CoinOS's own `retry_for: 60` window, so a slow payment times out on the client right when CoinOS answers — the exact "doubt" case. Make timeouts settable; use 90 s for payments. |
| f | Error text `"<status> <status text> - <body>"`; want a typed exception with `StatusCode`/`ResponseBody`; never the URL in the message | ✅ True | `IdeaL.Lib.Api.pas:145` (Post), `:195` (Get, without body). URL is not in the message today; keep it that way. | — |
| g | `TAPICoinOS.Get` ignores `HeaderArray`; `Post` uses it but has no per-call headers | ✅ True | `CoinOS.pas:262-274` vs `:397-422`. | Also: both hide the virtual base methods (W1010). |
| h | Doc comment problems | ✅ True | `CoinOS.pas:103-109` (stray `</param>`, "Satothis", `ASecret` described as an endpoint), `:150` ("paymento"), `:141-156` (no word about the hidden invoice). Also `CoinOS.pas:33-35` points to the dead GitHub URL. | — |

## 5. Additional findings (not in the request)

| ID | Finding | Evidence | Proposal |
| ---- | ---- | ---- | ---- |
| F1 | The **FPC build is very likely broken** since `47749c9` (2025-11-19): `IdeaL.Lib.Api.pas` declares `Post`/`Get` with `TNetHeaders` (Delphi-only type) for both compilers, and the whole `TIdeaLApi.Post` implementation sits inside the Delphi-only `{$ELSE}` block (`:72-152`), so FPC would see an unresolved forward declaration. `IdeaL.Lib.Api.Bitcoin.CoinOS.pas` uses inline `var` outside `{$IFDEF}` (`Get`, `Post`, `GetCredits`, …), which FPC does not support. The FPC demo was last changed 2025-02. `Api/Bitcoin/README.md` still marks CoinOS ✔ for Lazarus. | Code reading; **not compiled** (no FPC on this machine). | Request item 5 ("keep both branches the same") requires fixing this first. Needs FPC/Lazarus to verify — see question Q3. |
| F2 | `PostPaymentLnAddress` with the default `AMaxFee = 0` sends `{"fee":0}`. CoinOS treats `0` as an explicit cap (`Number.isFinite(0)`), so any external payment with a non-zero quoted routing fee fails with "Routing fee of ⚡️X required, max fee is ⚡️0". | `CoinOS.pas:590`; `lib/payments.ts:1051-1055`. | Send `fee` only when > 0 (same rule as `PostPayment`). |
| F3 | `PostPaymentToUser` is documented as "Send an internal payment to another CoinOS user" but only **creates an invoice** for that user (`POST /invoice` with `user.username`); it does not move money. | `CoinOS.pas:593-621`. | Out of scope; fix the doc comment only (says what it does) and mention in the CHANGELOG. |
| F4 | LUD-06 **no longer** asks the wallet to check `h = sha256(metadata)`: step 7 now only says "verifies that amount in provided invoice equals the amount previously specified". `commentAllowed` comes from LUD-12, not LUD-06. LUD-16: username limited to `a-z0-9-_.` (and `+` for tags); `.onion` domains use `http://`; `@domain` may mean `_@domain`. | `lud06.md` step 7; `lud12.md`; `lud16.md`. | Provide the description-hash check as an **opt-in** helper (many services send `d` instead of `h`), make the **amount check mandatory** inside `FetchInvoice`. |
| F5 | BOLT 11 (current text) is stricter than the request: `s` (payment secret) is mandatory; readers **must fail** when `p`, `h`, `s`, `n` have a wrong length, when there is not exactly one `p` and one `s`, when both or neither of `d`/`h` exist, when `d` is not valid UTF-8, on unknown **even** feature bits, and must check the signature. Unknown tags and unknown `f` versions are skipped. | `bolt11.md` "Requirements" of tagged fields; invalid-invoice vectors. | Decoder follows the spec except signature verification (needs secp256k1). Document that `Decode` is "parse and sanity-check", not "authenticate"; the paying node (CoinOS/CLN) verifies the signature. Signature-only invalid vectors are listed as known limitations in the tests. |
| F6 | `THTTPClient.HandleRedirects` defaults to `True` (max 5) and `TIPAddress.LookupName` is IPv4-only. | `System.Net.HttpClient.pas:1036-1037`; `System.Net.Socket.pas:86, 881`. | The SSRF guard must disable redirects for LNURL calls (or validate each hop) and resolve with `getaddrinfo` (IPv4 + IPv6). |
| F7 | Release mechanics: tags exist only on the GitHub mirror, which has a separate history; `boss.json` version is stale (`0.0.5`). | §2. | Maintainer bumps `boss.json` to `0.0.7` in the release commit and tags where Boss users pull from. Agents do not push. |

## 6. The retry rule (to document in code and README)

1. Resolve, fetch the invoice, decode it, check amount/network/expiry, **store it** (with the intended amount and the time) before calling `PostPayment`.
2. Call `PostPayment(invoice)` with a response timeout above CoinOS's own window (default 90 s).
3. If the call returns a record: `confirmed = true` → paid; `confirmed = false` → in flight, poll `GetPayment` later.
4. If the call raised a **typed HTTP error** (`EIdeaLApiError`, CoinOS answered 500 with a reason such as "Invalid pin", "Routing fee … required", "Insufficient funds"): nothing was debited for that attempt; fix the cause and retry with the same invoice.
5. If the call failed **without an answer** (timeout, connection reset, process restart): do not retry immediately. Wait a grace period (recommended ≥ 2 minutes, configurable), then `GetPayment(invoice)`:
   - `psPaid` → done.
   - `psPending` → wait and check again later (may take long for hold invoices). Never pay again while pending.
   - `psNone` → retry `PostPayment` with the **same** invoice while it has not expired (keep a safety margin, e.g. 60 s, before `ExpiresAt`).
6. Only fetch a **new** invoice after the old one has expired **and** `GetPayment(old)` still reports no record. Two invoices are two independent payments; CoinOS cannot de-duplicate them.
7. Never have two `PostPayment` calls for the same invoice in flight at the same time (CoinOS's duplicate guard is check-then-act, fact 7). Serialise per invoice in the caller.

Why the same invoice is the safe retry: CoinOS refuses a second payment of an invoice that is paid, being paid or still settling (fact 7), the BOLT 11 payment hash binds the payment to one preimage, and `GetPayment` answers by invoice. A new invoice has a new hash, so none of those protections apply.

## 7. Design

### 7.1 Base class `TIdeaLApi` (`Api/IdeaL.Lib.Api.pas`)

```pascal
type
  // FPC only: minimal stand-ins so shared code compiles on both compilers
  {$IFDEF FPC}
  TNameValuePair = record
    Name, Value: string;
    class function Create(const AName, AValue: string): TNameValuePair; static;
  end;
  TNetHeaders = array of TNameValuePair;
  {$ENDIF}

  EIdeaLApiError = class(Exception)
  private
    FStatusCode: Integer;
    FStatusText: string;
    FResponseBody: string;
  public
    constructor Create(AStatusCode: Integer; const AStatusText, AResponseBody: string);
    property StatusCode: Integer read FStatusCode;
    property StatusText: string read FStatusText;
    property ResponseBody: string read FResponseBody;   // full body
  end;
  // Message = '<code> <text> - <body truncated to ~300 chars>'; never the URL.

  TIdeaLApi = class
  public const
    CDefaultConnectTimeout = 60000;   // ms; same as Delphi 12's own default, so no behaviour change
    CDefaultResponseTimeout = 60000;  // ms; bounds FPC, which had no I/O timeout
  private
    FConnectTimeout: Integer;
    FResponseTimeout: Integer;
    FHandleRedirects: Boolean;        // default True (current behaviour)
  public
    property ConnectTimeout: Integer read FConnectTimeout write FConnectTimeout;
    property ResponseTimeout: Integer read FResponseTimeout write FResponseTimeout;
    property HandleRedirects: Boolean read FHandleRedirects write FHandleRedirects;
    function Post(AUrl, ABody: string; AHeaders: TNetHeaders): string; virtual;
    function Get(AUrl: string; AHeaders: TNetHeaders): string; virtual;
  end;
```

- Both verbs accept any 2xx on both compilers and raise `EIdeaLApiError` otherwise. `EIdeaLApiError` descends from `Exception`, so existing `except on E: Exception` code keeps working.
- Delphi: set `THTTPClient.ConnectionTimeout`, `ResponseTimeout` (and `SendTimeout = ResponseTimeout`), `HandleRedirects`. FPC: `ConnectTimeout`, `IOTimeout` (per read, not total — documented difference), `AllowRedirect`. FPC's `TFPHttpClient.Get(URL, Stream)` may raise `EHTTPClient` on non-200 before our check; use `HTTPMethod` with an empty allowed-codes list and check the status ourselves (verify on FPC).
- Transport errors (timeout, DNS, TLS) keep raising the platform exception (`ENetHTTPClientException` / `ESocketError` / `EHTTPClient`). Callers distinguish "server answered with an error" (`EIdeaLApiError`) from "no answer" (anything else) — this is the distinction §6 needs. Optionally wrap the latter in `EIdeaLApiTransportError` (question Q4).
- Fix the FPC structure (F1): move `Post` out of the Delphi-only block, give the FPC branch the header type above.

### 7.2 `TAPICoinOS` (`Api/Bitcoin/IdeaL.Lib.Api.Bitcoin.CoinOS.pas`)

```pascal
type
  TCoinOSPaymentState = (psNone, psPending, psPaid);

  TAPICoinOS = class(TIdeaLApi)
  public const
    CUrlApi = 'https://coinos.io/api';
    CDefaultPaymentTimeout = 90000;   // ms, above CoinOS's ~60 s xpay window
  public
    property PaymentTimeout: Integer;  // used by PostPayment / PostPaymentLnAddress

    // same first two parameters as before, so old calls still compile
    function PostPayment(AInvoice: string; AFee: Integer = 0;
      AMemo: string = ''; APin: string = ''): string;
    function GetPayment(AInvoice: string): string;          // '' = no record
    function GetPaymentState(AInvoice: string; out ARecord: string): TCoinOSPaymentState;
    class function NormalizeInvoice(const AInvoice: string): string; static; // strip whitespace, 'lightning:' prefix, lowercase

    function PostPaymentLnAddress(AAddress: string; AAmount: Integer;
      AMaxFee: Integer = 0; APin: string = ''): string;      // fee only when > 0 (F2)
  end;
```

- `PostPayment`: body `{"payreq": <normalised>, "fee": n (only > 0), "memo": s (only non-empty), "pin": s (only non-empty)}`; uses `PaymentTimeout`. The old signature `PostPayment(AInvoice; AMaxFee)` is source-compatible with the new one (same positions), so no overload/deprecation is needed; the parameter is renamed `AFee` and the behaviour change (cap now enforced) goes into the release note.
- `GetPayment`: validates that the normalised invoice only contains bech32 characters (`[a-z0-9]`, so nothing can be injected into the path), `GET /payments/<invoice>` with normal headers (auth is harmless), returns `''` when the body is empty **or** `null` (fact 5), the JSON otherwise; non-2xx → `EIdeaLApiError` (message without the URL).
- `GetPaymentState`: `''` → `psNone`; JSON object with `confirmed = true` → `psPaid`; `confirmed = false` → `psPending`; anything else → `EIdeaLApiError`/`EParserError`-style exception. Optional sanity check: record `hash` equals the invoice. XMLDoc explains facts 6 and 8 and that the endpoint is public (anyone with the invoice can read the record).
- Header consistency (g): `Get(AUrl; AHeaders = [])` and `Post(AUrl, ABody; AHeaders = [])` both send default headers + `HeaderArray` + per-call headers; declared `reintroduce` so W1010 disappears. `GetRo` and `GetPayments` call `Get` instead of their own `THTTPClient` (gains 2xx, timeouts, typed errors, `HeaderArray`).
- Doc comments (h): fix tags and typos, point the class remark to `https://git.coinos.io/coinos-server.git` (GitHub link kept as a possible mirror), document every fact next to its method, mark `PostPaymentLnAddress` as "one call, invoice hidden, use the three-step path when you need tracking", and correct `PostPaymentToUser` (F3).
- Out of scope but cheap, optional (question Q5): `GetDecode(AInvoice)` → `GET /decode/:bolt11` as a server-side cross-check, and `PostLightningQuote(AInvoice)` → `POST /lightning/quote` to choose a fee cap.

### 7.3 New unit `Api/Bitcoin/IdeaL.Lib.Bitcoin.Bolt11.pas` (pure, no network)

```pascal
type
  EBolt11Error = class(Exception);
  TBolt11Network = (bnUnknown, bnMainnet, bnTestnet, bnSignet, bnRegtest); // lnbc, lntb, lntbs, lnbcrt

  TBolt11 = record
    Invoice: string;            // normalised (lowercase, no prefix/whitespace)
    Network: TBolt11Network;
    CurrencyPrefix: string;     // 'bc', 'tb', 'tbs', 'bcrt'
    AmountMsat: Int64;          // -1 = amountless
    Timestamp: Int64;           // unix seconds
    PaymentHash: string;        // p, hex
    PaymentSecret: string;      // s, hex
    Description: string;        // d (UTF-8 decoded)
    DescriptionHash: string;    // h, hex ('' if absent)
    Expiry: Int64;              // x, default 3600
    MinFinalCltvExpiry: Integer;// c, default 18
    PayeePubKey: string;        // n, hex ('' if absent — recovering it needs secp256k1)
    Features: string;           // 9, hex of the raw bit field
    Signature: string;          // 65 bytes hex (r || s || recovery id)
    function HasAmount: Boolean;
    function ExpiresAtUtc: TDateTime;
    function IsExpired(ANowUtc: TDateTime; AMarginSec: Integer = 0): Boolean;
    function MatchesMetadata(const AMetadata: string): Boolean; // h = sha256(UTF-8 bytes of metadata)
  end;

  TBolt11Decoder = class
  public
    class function Decode(const AInvoice: string): TBolt11; static;      // raises EBolt11Error
    class function TryDecode(const AInvoice: string; out AResult: TBolt11; out AError: string): Boolean; static;
  end;

function Sha256(const ABytes: TBytes): TBytes;  // small portable implementation, tested against NIST vectors
```

- bech32 (constant 1, not bech32m) with checksum; all-lower or all-upper, mixed case fails; no 90-character limit (BOLT 11 allows longer) but a sane upper bound (e.g. 8 KB) against abuse; accepts and strips a `lightning:` prefix and whitespace.
- HRP: longest prefix first (`lnbcrt` before `lnbc`, `lntbs` before `lntb`); amount digits + optional multiplier `m/u/n/p`; `p` requires the last digit to be 0; overflow-checked conversion to msat (`Int64` holds 21 M BTC in msat).
- Data: 35-bit timestamp, tagged fields (5-bit type, 10-bit length), 104-group signature. Spec MUSTs from F5 enforced; unknown tags skipped.
- Errors never contain the invoice.
- SHA-256 is implemented in the unit (Delphi has `THashSHA2`, but FPC 3.2's support is uncertain; one implementation keeps both compilers identical). Tests compare it with `THashSHA2` on Delphi.

### 7.4 New unit `Api/Bitcoin/IdeaL.Lib.Api.Bitcoin.LnurlPay.pas`

```pascal
type
  ELnurlPayError = class(Exception)   // Reason = server's reason text; never the invoice
  public
    property Reason: string;
  end;

  TLnurlPayRequest = record
    Address, UserName, Domain: string;
    Callback: string;
    MinSendableMsat, MaxSendableMsat: Int64;
    Metadata: string;           // raw string exactly as received (hashed for 'h')
    CommentAllowed: Integer;    // LUD-12, 0 when absent
    Tag: string;
    function Description: string; // 'text/plain' entry of Metadata
  end;

  TLnurlPay = class(TIdeaLApi)
  public
    property RequireHttps: Boolean;        // default True
    property BlockPrivateHosts: Boolean;   // default True (SSRF guard)
    property CheckDescriptionHash: Boolean;// default False (F4)
    function Resolve(const AAddress: string): TLnurlPayRequest;
    function FetchInvoice(const ARequest: TLnurlPayRequest; AAmountMsat: Int64;
      const AComment: string = ''): string;
  end;
```

- `Resolve`: parse `user@domain` (LUD-16 charset; `@domain` → `_`), lowercase the domain, GET `https://<domain>/.well-known/lnurlp/<user>`. Fail on `status = "ERROR"` (with `reason`), on `tag <> "payRequest"`, on missing/invalid `callback`, on `minSendable < 1` or `min > max`.
- `FetchInvoice`: check `min ≤ amount ≤ max`; comment length ≤ `commentAllowed` (URL-encoded, only when non-empty); GET `<callback>?amount=<msat>` or `&amount=` when the callback already has a query; fail on `status = "ERROR"` or missing `pr`; decode `pr` with `TBolt11Decoder` and **fail if its amount differs from the requested amount** (LUD-06 step 7); when `CheckDescriptionHash` is on, fail if `h` is absent or differs from `sha256(metadata)`.
- Safety (on by default, switchable): both URLs must be `https`; the host (literal IP or every address returned by `getaddrinfo`, IPv4 and IPv6) must not be loopback, private (RFC 1918, `100.64/10`, ULA `fc00::/7`), link-local (`169.254/16`, `fe80::/10`), unspecified, multicast or reserved, including IPv4-mapped/NAT64 IPv6 forms; redirects disabled (a 3xx is an error). The callback may be on another host than the address's domain. Limitation documented: DNS can change between our check and the HTTP connection (rebinding); environments that need a hard guarantee should also restrict egress at the firewall. `.onion` addresses are refused while `RequireHttps` is on.
- Timeouts: `ConnectTimeout = 10000`, `ResponseTimeout = 20000` by default.
- DNS resolution: Delphi `Winapi.Winsock2.getaddrinfo` on Windows and `Posix.NetDB` on POSIX; FPC `netdb`/`sockets` (exact API to confirm with FPC available).

### 7.5 Demo (`Demos/Api/Bitcoin/CoinOS`, FMX; and `FPC/` when it compiles)

- New group box **"Pay LN Address — 3 steps (trackable)"**: address, amount (sats), comment, fee cap, PIN; buttons **1. Resolve** (shows min/max, description, `commentAllowed`), **2. Fetch invoice** (shows the invoice and the decoded amount, network, expiry countdown, payment hash, description/hash match), **3. Pay** (`PostPayment`), **4. Check status** (`GetPaymentState`). The pending invoice is saved in `config.json` so the "check after a crash/restart" scenario can be shown. A "simulate timeout" check box sets `PaymentTimeout` to 1 s to show the doubt path.
- Existing **"Pay invoice"** box: "Max fee" → "Fee cap (sats, 0 = CoinOS quote)", new Memo and PIN fields, new **Check payment** button.
- Existing **"Pay LN Address"** box: caption marks it "one call — no tracking", gains a PIN field; keep it.
- `Project1.dpr`/`.dproj`: add the two new units; keep `.fmx` ASCII.
- Same additions in the Lazarus demo only after F1 is fixed and FPC is available.

### 7.6 README

- `Api/Bitcoin/README.md`: new section "Paying a Lightning address safely (CoinOS)" with the flow `TLnurlPay.Resolve → TLnurlPay.FetchInvoice → TBolt11Decoder.Decode (amount, network, expiry) → store the invoice → TAPICoinOS.PostPayment → after any doubt: GetPaymentState`, the retry rule from §6, why the same invoice is the safe retry, and when a new invoice is safe. Add LnurlPay and Bolt11 to the compatibility table, and correct the Lazarus column to what was really verified.
- Short entries for the new units in [docs/agents/INDEX.md](../INDEX.md).

## 8. Open questions for the maintainer

| # | Question | Recommendation |
| ---- | ---- | ---- |
| Q1 | Unit names and folder: `Api/Bitcoin/IdeaL.Lib.Api.Bitcoin.LnurlPay.pas` and `Api/Bitcoin/IdeaL.Lib.Bitcoin.Bolt11.pas`? | Yes. Same folder means Boss users need no new search path; `Bolt11` has no `Api` in its name because it does no network I/O. |
| Q2 | Test framework: DUnitX (Delphi only, ships with RAD Studio 12) or a framework-free console runner that compiles with both `dcc32` and `fpc`? | Framework-free shared runner under `Tests/Bitcoin/` (`.dpr` + `.lpr` on the same test unit): one set of vectors for both compilers, runnable from the command line, no dependency. |
| Q3 | FPC/Lazarus: install it (free) so the FPC branch and the Lazarus demo can be compiled and fixed (F1), or ship 0.0.7 Delphi-verified with the FPC branch "written but not compiled" and the README table saying so? | Install FPC 3.2.2 + Lazarus; otherwise mark FPC as not verified. Do not claim parity we did not compile. |
| Q4 | Wrap transport failures (timeout/DNS/TLS) in a library exception (`EIdeaLApiTransportError`) so callers can tell "no answer" from "error answer" without knowing platform exception classes? | Yes — it is exactly the distinction the retry rule needs, and it hides the Delphi/FPC difference. |
| Q5 | Add the optional `GetDecode` (`/decode/:bolt11`) and `PostLightningQuote` (`/lightning/quote`) helpers now? | `PostLightningQuote` yes (helps choose a valid fee cap); `GetDecode` optional. |
| Q6 | Default timeouts: keep the base default at 60 s/60 s (no behaviour change on Delphi), 90 s for CoinOS payments, 10 s/20 s for LNURL? | Yes. |
| Q7 | Accept the behaviour change of `PostPayment`'s fee (cap now enforced) in 0.0.7 with a release note? | Yes; the old behaviour was a silent bug. |
| Q8 | Real-money tests (§9.3): which accounts/wallets, and the total budget per run? | Two CoinOS test accounts + one external wallet; ≤ 100 sats per payment, ≤ 2 000 sats per run; you approve each run. |
| Q9 | Release: bump `boss.json` to `0.0.7` in the final commit and you tag/push where Boss users pull (GitHub mirror and/or Bitbucket)? | Yes; agents never push. |
| Q10 | Should we answer the requester with the corrections from §3–§5 (fact 5 returns `null`, LUD-06 no longer requires the `h` check, Delphi 12 default timeouts are 60 s, `s` is mandatory in BOLT 11, the `fee: 0` bug in `PostPaymentLnAddress`)? | Yes — a short reply text can be drafted into this folder for you to send. |

### 8.1 Maintainer's answers (2026-11-18)

| # | Decision |
| ---- | ---- |
| Q1, Q5, Q7, Q9 | Recommendations accepted. |
| Q2 | **DUnitX** for the Delphi tests, with isolated characterisation tests of the base class first, so that changes to `TIdeaLApi` cannot regress other projects. FPC side: an `fpcunit` console runner (ships with FPC) for the units that have FPC branches. |
| Q3 | Look for a Delphi-integrated FPC first (the maintainer remembered a German product). Found: **CrossFPC** (Simon Kissel, crossfpc.com) — last release targets Delphi 7 … 10.1 Berlin, unmaintained, not usable with Delphi 12. `fpcfordelphi` (SourceForge) is an unrelated 2014 alpha. No maintained Delphi-IDE FPC plug-in found. Decision: install only the official **FPC 3.2.2** compiler (no Lazarus) at `C:\FPC\3.2.2`; installer verified against the SourceForge SHA1/MD5. Consequence: library units and console tests can be compiled with FPC; the Lazarus demo (LCL) cannot be compiled on this machine. |
| Q4 | Adjusted after the maintainer's regression concern: transport failures keep their **native** exception classes (wrapping them would break existing `except on ENetHTTPClientException` handlers). Instead `TIdeaLApi.IsTransportError(E)` tells "no answer" from "error answer"; `EIdeaLApiError` is only raised when the server answered. |
| Q6 | Timeouts as **overloads**: the existing `Get`/`Post` signatures stay (still `virtual`) and delegate to new overloads that take `AConnectTimeout`/`AResponseTimeout`, passing 60 000 ms (Delphi 12's current default), so there is one implementation and existing behaviour is unchanged. CoinOS payments call the overload with 90 000 ms, LNURL with 10 000/20 000 ms. |
| Q8 | Accepted (≤ 100 sats per payment, ≤ 2 000 sats per run). The maintainer will create the accounts and share them when the live tests start; the token will be stored encrypted by the CoinOS demo, so the agent will have to decrypt it with the library's own routine. |
| Q10 | Reply to the requester drafted **outside the repository** at `C:\Temp` (the original request was never stored in the repository). |

## 9. Implementation steps

Each step is one or more local commits on `feature/coinos-safe-lnaddress-payment`, each with a CHANGELOG entry.

| Step | Content | Files | Done when |
| ---- | ---- | ---- | ---- |
| S0 | Test harness skeleton; decision Q2/Q3 applied | `Tests/Bitcoin/*` | Runner compiles with `dcc32` (and `fpc` if installed) and reports 0 tests. |
| S1 | `Bolt11` unit + SHA-256 + tests (all valid BOLT 11 vectors; invalid ones: checksum, mixed case, no separator, too short, unknown multiplier, sub-msat precision, missing `p`, missing `s`, duplicate `p`/`s`, wrong-length `n`, empty data part; signature-only vectors listed as known limitations) | `Api/Bitcoin/IdeaL.Lib.Bitcoin.Bolt11.pas`, tests | All tests pass on Delphi (and FPC if available). |
| S2 | Base class: header type for FPC, `EIdeaLApiError`, 2xx on both verbs, timeouts, redirects, FPC structure fix (F1) | `Api/IdeaL.Lib.Api.pas` | CoinOS, Alby, DePIX, DIGPIX, Exchange, ImgBB compile on Delphi; FPC compiled or explicitly "not compiled". |
| S3 | CoinOS: `PostPayment`, `GetPayment`, `GetPaymentState`, `NormalizeInvoice`, `PaymentTimeout`, header consistency, `GetRo`/`GetPayments` through `Get`, F2 fix, docs (h, F3), optional Q5 helpers | `Api/Bitcoin/IdeaL.Lib.Api.Bitcoin.CoinOS.pas` | Compiles; unit tests for body building, normalisation and `null`/empty handling (no network). |
| S4 | LnurlPay unit: parsing, URL building, SSRF guard, amount check, tests with canned JSON and an injectable HTTP layer (no network in unit tests) | `Api/Bitcoin/IdeaL.Lib.Api.Bitcoin.LnurlPay.pas`, tests | Tests pass, including private-address cases (`127.0.0.1`, `10.x`, `192.168.x`, `169.254.x`, `[::1]`, `[fd00::1]`, `[::ffff:127.0.0.1]`), `http://` refusal, callback with existing query. |
| S5 | Demo FMX (and Lazarus if FPC available) | `Demos/Api/Bitcoin/CoinOS/*` | Demo compiles; manual run of the read-only paths (resolve, fetch, decode, check). |
| S6 | READMEs, INDEX, CHANGELOG, plan status | `Api/Bitcoin/README.md`, `docs/agents/*` | Docs match the code. |
| S7 | Live tests (§9.3), only with approval | — | Results recorded in §10. |
| S8 | Release prep: `boss.json` → `0.0.7`, release note draft | `boss.json`, `docs/agents/*` | Maintainer tags and pushes. |

### 9.1 Automated tests (no network)

- BOLT 11 vectors from the spec, as listed in S1; SHA-256 NIST vectors (`""`, `"abc"`, 448-bit message) and cross-check with `THashSHA2` on Delphi.
- CoinOS request building: body JSON for every combination of fee/memo/pin; invoice normalisation (spaces, newlines, upper case, `lightning:` prefix); `GetPayment` response mapping (`''`, `'null'`, `' null\r\n'`, JSON confirmed true/false, invalid JSON).
- LNURL: address parsing (valid, uppercase domain, `+tag`, `@domain`, invalid characters), `.well-known` URL, callback URL with/without query, comment encoding and length, min/max checks, `status: ERROR` handling, amount mismatch, description hash on/off, SSRF matrix, redirect refusal.

### 9.2 Read-only live checks (no money; allowed without extra approval, public endpoints only)

- `Resolve` against a few public Lightning addresses (e.g. a CoinOS test account's own address) and `FetchInvoice` for a small amount — creating an invoice moves no money.
- `GetPayment` with an unknown invoice → `psNone` (already observed: body `null`).

### 9.3 Real-money tests (each run approved by the maintainer; ≤ 100 sats per payment)

Accounts: CoinOS **A** (payer, small balance), CoinOS **B** (recipient, internal), external wallet **C** with a Lightning address; optionally A with a PIN.

| ID | Scenario | Expected |
| ---- | ---- | ---- |
| T1 | 3-step payment A → B's address | `PostPayment` record `confirmed:true`; `GetPayment` returns **B's** record (positive amount, type internal, `with`) → `psPaid`. |
| T2 | 3-step payment A → C | Record `confirmed:false` then `true`; `GetPaymentState` goes `psPending` → `psPaid`. |
| T3 | Repeat T1/T2 with the same invoice | Refused ("Invoice already paid" / "Invoice has already been paid"); A's balance unchanged. |
| T4 | Fee cap below the quote | `EIdeaLApiError` 500 "Routing fee … required"; `GetPayment` → `psNone`; balance unchanged; then retry same invoice without cap → paid. |
| T5 | PIN account: without PIN / with PIN | "Invalid pin" / paid. |
| T6 | `PaymentTimeout = 1000` on an external payment | Client exception without an answer; after the grace period `GetPaymentState` → `psPending` or `psPaid`; no second debit. |
| T7 | Expired invoice (B creates one with `PostInvoiceLightning(…, AExpiration = 60)`, wait > 60 s) | Decode shows expired; demo refuses to pay; if forced, CoinOS refuses. |
| T8 | Old `PostPaymentLnAddress` with default fee (F2 regression check) | Works after the fix for an external address. |

## 10. Risks and limitations

- **FPC parity** cannot be verified without FPC (F1). Mitigation: Q3.
- **No signature verification** in `Bolt11` (no secp256k1). `Decode` is for inspection; authenticity is checked by the paying node.
- **DNS rebinding** can bypass the SSRF check between resolution and connection; documented, firewall egress rules recommended for servers.
- **CoinOS behaviour may change**: facts are pinned to `c0a0f5c` and the live check of 2026-11-18. Doc comments say so.
- **Behaviour change** in `PostPayment` fee handling (Q7).
- **Concurrency**: the library cannot stop a caller from running two payments of one invoice in parallel; documented rule §6.7.

## 11. Progress log

- 2026-11-18 — Repository synced check (fetch, 0/0), study of `TIdeaLApi`, `TAPICoinOS`, CoinOS demo (FMX and Lazarus); coinos-server `c0a0f5c` read (routes, payments, utils, db, auth); live probe of `GET /payments/:hash` and `GET /decode/:bolt11`; BOLT 11, LUD-06/12/16 read; Delphi 12 RTL checked; baseline Delphi build OK. Plan written. No library code changed yet.
- 2026-11-18 — Maintainer's answers recorded (§8.1). FPC 3.2.2 compiler installed at `C:\FPC\3.2.2` (no Lazarus). Its installer also added `C:\FPC\3.2.2\bin\i386-Win32` to the machine PATH; the agent had no admin rights to remove it.
- 2026-11-18 — S0 done: DUnitX runner + characterisation tests of the 0.0.6 base class, green on unchanged code (`9c8d1ec`).
- 2026-11-18 — S1+S2 done (`8481b78`): BOLT 11 decoder; base class changes. F1 confirmed by compiling (FPC: `TNetHeaders` unknown) and fixed. New finding: WinHTTP does not always honour `ResponseTimeout` while waiting for headers (first request of a process waited the full server delay, with Indy and with a Python server); the base class now enforces a wall-clock deadline (connect + response timeout) through the async `THTTPClient` API, keeping the original exception classes. New finding F8: `IdeaL.Lib.Api.Bitcoin.Exchange.pas` does not compile on Delphi on `master` (`FAuthToken` undeclared), independent of this work.
- 2026-11-18 — S3 done (`fbc7444`): CoinOS. Deviation from §7.2: `NormalizeInvoice` is implemented inside the CoinOS unit (no dependency on the Bolt11 unit) so that projects listing CoinOS by path do not need a new file. Added `BaseUrl` to make the unit testable.
- 2026-11-18 — S4 done (`9706c9b`): LNURL-pay. Resolver replaceable (`OnResolveHost`) for tests.
- 2026-11-18 — FPC parity tests (`ca24f4b`): 24 fpcunit tests, green.
- 2026-11-18 — S5 done for the FMX demo (`31e723c`); Lazarus demo not updated (no LCL here).
- 2026-11-18 — S6 done: READMEs, INDEX, AGENTS, CHANGELOG. Requester reply drafted at `C:\Temp` (outside the repository). Remaining: S7 live tests (waiting for accounts), S8 release, Lazarus demo.
