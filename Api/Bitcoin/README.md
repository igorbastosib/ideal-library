# [Bitcoin](https://bitcoin.org/bitcoin.pdf)

Integrations related with Bitcoin environment.<br />
You can find the examples on folder Demos/Api/Bitcoin.<br />

⚠️The units and the demonstration projects all full of source code commentaries, please feel free to read them all.

## [Alby](https://getalby.com/)

[Alby API official doc](https://guides.getalby.com/developer-guide/v/alby-wallet-api)

The current implementation is compatible with fixed token you create on your Alby account management screen.<br />
Feel free to use the Demo/Api/Bitcoin/Alby project, which also has a step-by-step tutorial of how to create your Access Token.<br />

## CoinOS

[CoinOS API official doc](https://coinos.io/docs)

Feel free to use the Demo/Api/Bitcoin/CoinOS project.<br />
There is also a video demonstration on [Youtube](https://www.youtube.com/watch?v=l4bSgcR4Z5c) (subtitles available).<br />
Awesome CoinOS, list of implemented solutions: [link](https://github.com/igorbastosib/awesome-coinos)<br />
CoinOS server source (the live API): [git.coinos.io/coinos-server.git](https://git.coinos.io/coinos-server.git)<br />

**Login through the API needs a captcha.** `PostLogin` is answered with HTTP 401 "failed captcha" unless the request carries a reCAPTCHA token, an `x-api-key` registered by the CoinOS team (set it with `HeaderArray`), or the account is allowlisted by CoinOS. For your own integrations, log in on coinos.io, copy the token (see `Demos/Api/Bitcoin/CoinOS/AuthToken.jpg`) and use it with `AuthToken`.

### Paying a Lightning address safely (trackable)

`TAPICoinOS.PostPaymentLnAddress` pays a Lightning address in one call (`POST /send/:lnaddress/:amount`): CoinOS resolves the address, fetches the invoice and pays it, and you never see the invoice before money moves. If that call dies without an answer (timeout, restart, network), you cannot find out whether it paid, and calling it again may pay twice.

When a payment must be tracked or retried, do the three steps yourself and keep the invoice:

1. `TLnurlPay.Resolve(address)` then `TLnurlPay.FetchInvoice(request, amountMsat)` (unit `IdeaL.Lib.Api.Bitcoin.LnurlPay`). `FetchInvoice` refuses an invoice whose amount differs from the one you asked for.
2. `TBolt11Decoder.Decode(invoice)` (unit `IdeaL.Lib.Bitcoin.Bolt11`): check `AmountMsat`, `Network = bnMainnet` and `IsExpired(now, margin)`. **Store the invoice** before paying.
3. `TAPICoinOS.PostPayment(invoice, feeCap, memo, pin)`.
4. After any doubt: `TAPICoinOS.GetPaymentState(invoice, record)`:
   - `psPaid` → done.
   - `psPending` → in flight (can take long with hold invoices); check again later, never pay again.
   - `psNone` → no record: retry `PostPayment` with the **same** invoice while it has not expired.

How to read errors of `PostPayment`:

- `EIdeaLApiError` (has `StatusCode` and `ResponseBody`): CoinOS answered with an error ("Invalid pin", "Routing fee of X required", "Insufficient funds", "Invoice has already been paid"…). Nothing was debited by that attempt; fix the cause and retry with the same invoice.
- Any exception for which `TIdeaLApi.IsTransportError(E)` is True: there was no answer. The payment may or may not have happened. Wait a couple of minutes (CoinOS itself can hold a payment call about 60 s), then call `GetPaymentState` before doing anything else.

Why the same invoice is the safe retry: CoinOS refuses to pay an invoice that is already paid, being paid or still settling ("Invoice has already been paid", "Payment is already underway", "Previous attempt is still settling", "Invoice already paid"), and `GET /payments/:invoice` answers by invoice. A new invoice is a new payment that none of these protections cover: fetch a new one only after the old one has **expired** and `GetPaymentState` still says `psNone`.

Rules of thumb:

- Never run two `PostPayment` calls for the same invoice at the same time (CoinOS checks for duplicates before debiting, but not atomically).
- `PostPayment` uses `PaymentTimeout` (default 90 s), above CoinOS's own ~60 s payment window.
- `AFee` is a cap for the routing fee in sats; 0 lets CoinOS use its own quote. A cap below the quote, or above max(1000 sats, 5% of the amount), is refused before any debit. `PostLightningQuote` returns the quote.
- `GET /payments/:invoice` is public: anyone holding the invoice can read the record. For an invoice of another CoinOS user it returns the **recipient's** record (positive amount, type `internal`), which still proves the payment.
- `TLnurlPay` only talks to `https` hosts that resolve to public addresses and does not follow redirects (protection against SSRF); see the unit header for the details and limits.

The demo `Demos/Api/Bitcoin/CoinOS` has a "Pay LN Address - 3 steps (trackable)" box that walks through this flow.

## [DePIX](https://docs.eulen.app/)

The Pix2Depix RESTful HTTP API connects Brazil's PIX payment system with DePix, a Liquid Network & Lightning Network (via Taproot Assets) asset managed by Eulen. It enables seamless conversion of Brazilian Real (BRL) to DePix (and vice-versa) for secure and efficient decentralized finance operations.

## [DIGPIX](https://vempradig.com/digpix)

[VemPraDig API official doc](https://vempradig.com/digpix/api-doc)

DIGPIX is a brazilian bitcoin P2P, that works selling bitcoin over the [DePIX](https://www.depix.info/) framework.<br />
⚠️Please, do not mistake DePIX with Brazilian PIX payment method. Read DePIX official documentation for more info!<br />

Using VemPraDig API implementation you will be able to receive in BTC while your customer pays you in R$ (Brazilian currency).<br />
⚠️VemPraDig API official doc is only accessable after creating an account, please, be in touch with their [support](https://vempradig.com/dig/#contato).<br />

## Exchange

This file provides integration with many public Bitcoin API platforms and services.<br />
Initially built for rate and price check.<br />

## Compatibility Table

Last verified on 2026-11-19 with Delphi 12 (dcc32/dcc64) and FPC 3.2.2 (i386-win32) by compiling each unit on its own; "tested" means the unit has automated tests under `Tests/` that pass on that compiler.

| File | Delphi | Free Pascal / Lazarus |
| ---- | ---- | ---- |
| IdeaL.Lib.Api (base) | ✔️ compiles, tested | ✔️ compiles, tested |
| CoinOS | ✔️ compiles, tested | ✔️ compiles, tested |
| LnurlPay | ✔️ compiles, tested (Linux64: compiles) | ✔️ Windows compiles, tested; Unix branch not compiled |
| Bolt11 | ✔️ compiles, tested | ✔️ compiles, tested |
| Alby | ✔️ compiles, tested | ✔️ compiles, tested (since 0.0.7) |
| DePIX | ✔️ compiles, tested | ✔️ compiles, tested (since 0.0.7) |
| DIGPIX | ✔️ compiles, tested | ✔️ compiles, tested (since 0.0.7) |
| Exchange | ✔️ compiles, tested (since 0.0.7) | ✔️ compiles, tested |

Alby, DePIX, DIGPIX and Exchange are tested against a local server only (requests and answer handling); no call to the real services was made. Their FPC branches send the same requests as the Delphi ones (fpjson writes the same JSON with extra spaces) and, since 0.0.7, report errors with the same message ("<code> <text>", plus " - <body>" where the Delphi branch adds it). The Exchange `Post` no longer sends an `Authorization` header (it referred to a token the class never had).

The Lazarus demo (`Demos/Api/Bitcoin/CoinOS/FPC`) has not been rebuilt: Lazarus is not installed on the maintainer's machine.

## ⚠️ License

This repository and all it's source code are free and open-source software licensed under the [MIT License](https://bitbucket.org/idealtecd/ideal-library/src/master/LICENSE).
