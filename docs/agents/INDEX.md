# Repository index

Map of the repository for agents. Descriptions of units not yet studied by an agent are inferred from their names and marked *(name only)*; replace them with a real description when you work on the unit. Last full survey: 2026-11-18.

## Top level

| Path | What it is |
| ---- | ---- |
| `AGENTS.md`, `CLAUDE.md` | Rules for AI agents (`CLAUDE.md` only imports `AGENTS.md`). |
| `README.md` | Public README (English). Says Bitbucket is the main repo and GitHub a copy. |
| `boss.json` | Boss package manifest. `version` field says `0.0.5` while the latest tag on the GitHub mirror is `0.0.6` (checked 2026-11-18). |
| `LICENSE` | MIT. |
| `IdeaL.Lib.*.pas` (root) | General-purpose FMX/RTL helper units, see below. |
| `Api/` | HTTP integrations deriving from `TIdeaLApi`. |
| `Controller/`, `Model/`, `View/` | Database connection abstractions (FireDAC, Zeos), DropBox models, FMX view helpers. |
| `Demos/` | One demo project per feature/integration, often one sub-folder per Delphi version. |
| `Files/` | Binary dependencies (OpenSSL 1.0.2 libraries per platform, a FMX style book). |
| `Others/` | Third-party code (Kastri parts by Dave Nottage, iPub TipScrollBox + Alcinoe excerpts, FMX patches per Delphi version). Do not edit unless asked; keep original encodings. |
| `docs/agents/` | Agent documentation: this index, the agent CHANGELOG, plans. |

## Api/ — integrations

| Unit | Class | Delphi | FPC | Demo | Notes |
| ---- | ---- | ---- | ---- | ---- | ---- |
| `Api/IdeaL.Lib.Api.pas` | `TIdeaLApi`, `EIdeaLApiError` | ✔ tested | ✔ tested | — | Base class: `Get`/`Post` (old signatures + overloads with connect/response timeouts), any 2xx is success, `EIdeaLApiError` when the server answered with an error, `IsTransportError` for "no answer", `FollowRedirects`. Delphi enforces a wall-clock deadline (WinHTTP ignores `ResponseTimeout` before headers). FPC build fixed in 0.0.7. |
| `Api/Bitcoin/IdeaL.Lib.Api.Bitcoin.CoinOS.pas` | `TAPICoinOS` | ✔ tested | ✔ tested | `Demos/Api/Bitcoin/CoinOS` (FMX, updated) and `.../CoinOS/FPC` (Lazarus, not updated) | CoinOS custodial Lightning wallet API (`https://coinos.io/api`). Server source: `https://git.coinos.io/coinos-server.git`. `PostPayment` (fee/memo/pin), `GetPayment`, `GetPaymentState`, `BaseUrl`, `PaymentTimeout`. See plan `2026-11-18-coinos-safe-lnaddress-payment.md`. |
| `Api/Bitcoin/IdeaL.Lib.Api.Bitcoin.LnurlPay.pas` | `TLnurlPay` | ✔ tested (Linux64 compiles) | ✔ Windows tested; Unix branch not compiled | CoinOS demo, "3 steps" box | LNURL-pay client (LUD-06/12/16) with amount check and SSRF guard (https only, public IPs only, no redirects). Wallet independent. |
| `Api/Bitcoin/IdeaL.Lib.Bitcoin.Bolt11.pas` | `TBolt11Decoder`, `TBolt11` | ✔ tested | ✔ tested | CoinOS demo | Pure BOLT 11 decoder (no network, no signature check) with portable SHA-256. |
| `Api/Bitcoin/IdeaL.Lib.Api.Bitcoin.Alby.pas` | `TAPIAlby` | ✔ | ❌ pre-existing errors | `Demos/Api/Bitcoin/Alby` | Alby wallet API with a fixed access token. |
| `Api/Bitcoin/IdeaL.Lib.Api.Bitcoin.DePIX.pas` | `TAPIDePix` | ✔ | ❌ pre-existing errors | `Demos/Api/Bitcoin/DePIX` | Eulen Pix2DePix API. |
| `Api/Bitcoin/IdeaL.Lib.Api.Bitcoin.DIGPIX.pas` | `TAPIDigPix` | ✔ | ❌ pre-existing errors | `Demos/Api/Bitcoin/DIGPIX` | VemPraDig / DIGPIX. **Encoding: Windows-1252.** |
| `Api/Bitcoin/IdeaL.Lib.Api.Bitcoin.Exchange.pas` | `TAPIExchange` | ❌ pre-existing error (`FAuthToken`) | ✔ | — | Public price/rate APIs (uses CoinOS `/rates` among others). |
| `Api/Bitcoin/README.md` | — | — | — | — | User-facing doc of the Bitcoin integrations, with a Delphi/Lazarus compatibility table. |
| `Api/IdeaL.Lib.Api.DropBox.pas`, `Api/IdeaL.Lib.Download.DropBox.pas` | — | ✔ | — | `Demos/Api/DropBox/*` | DropBox API and downloads. |
| `Api/IdeaL.Lib.Api.Image.ImgBB.pas` | `TImgBBApi` | ✔ | — | `Demos/Api/Image-ImgBB` | ImgBB image upload. |
| `Api/IdeaL.Lib.Api.ReceitaWs.pas` | — | ✔ | — | `Demos/Api/ReceitaWs` | Brazilian CNPJ lookup (ReceitaWS). |

## Tests/

| Path | What it is |
| ---- | ---- |
| `Tests/Delphi/IdeaLLibTests.dpr`, `run-tests.ps1` | DUnitX console runner (Win64) and its build/run script. |
| `Tests/Delphi/Test.LocalHttpServer.pas` | Indy HTTP server on 127.0.0.1 with scripted answers; records the last request. |
| `Tests/Delphi/Test.IdeaL.Lib.Api.Compat.pas` | Characterisation of the 0.0.6 `TIdeaLApi` behaviour (must stay green). |
| `Tests/Delphi/Test.IdeaL.Lib.Api.pas`, `Test.IdeaL.Lib.Api.Bitcoin.CoinOS.pas`, `Test.IdeaL.Lib.Bitcoin.Bolt11.pas`, `Test.IdeaL.Lib.Api.Bitcoin.LnurlPay.pas` | Unit tests of the base class, CoinOS (requests of every method pinned), BOLT 11 and LNURL-pay. |
| `Tests/FPC/IdeaLLibTestsFpc.lpr`, `run-tests-fpc.ps1`, `TestServerFpc.pas`, `TestIdeaLLibFpc.pas` | fpcunit runner for the FPC branches, with an fcl-web HTTP server on 127.0.0.1. |
| `Tests/Shared/Bolt11Vectors.pas` | BOLT 11 spec test vectors, generated from the spec, shared by both runners. |

## Root units *(name only unless stated)*

| Unit | Area |
| ---- | ---- |
| `IdeaL.Lib.Utils.pas` | General helpers (`TUtils`, e.g. `OpenUrl`). UTF-8 with BOM. Used by the demos. |
| `IdeaL.Lib.HttpUtils.pas`, `IdeaL.Lib.DownloadUpload.pas`, `IdeaL.Lib.RestDataware.Utils.pas` (cp1252) | HTTP / REST helpers. |
| `IdeaL.Lib.JSONManage.pas`, `IdeaL.Lib.SuperObject.Helper.pas`, `IdeaL.Lib.SuperObjectHelper.pas`, `IdeaL.Lib.CustomRtti.pas` (UTF-8 BOM) | JSON and RTTI helpers. |
| `IdeaL.Lib.Encryption.pas`, `IdeaL.Lib.Token.Jwt.pas` | Encryption, JWT. |
| `IdeaL.Lib.Cep.pas` | Brazilian postal code (CEP) lookup. |
| `IdeaL.Lib.PopUp*.pas`, `IdeaL.Lib.PopUp.DateTimePicker.pas` (UTF-8 BOM), `IdeaL.Lib.PopUp.Loading.pas`, `IdeaL.Lib.PopUp.Message.pas` | FMX pop-ups, toasts, loading, date/time picker. |
| `IdeaL.Lib.CircularProgressBar.pas`, `IdeaL.Lib.HorizontalProgressBar.pas`, `IdeaL.Lib.StatusBar.pas` (UTF-8 BOM), `IdeaL.Lib.CustomComboBox.*`, `IdeaL.Lib.PathSvg.pas` (cp1252) | FMX visual components. |
| `IdeaL.Lib.FrameItemList*.pas/.fmx`, `IdeaL.Lib.FrameListModel.*`, `IdeaL.Lib.ItemList*.pas` | FMX list frames. |
| `IdeaL.Lib.Android.Permissions.pas`, `IdeaL.Lib.Intents.Android.Helpers.pas` (UTF-8 BOM), `IdeaL.Lib.InterstitialAdmob.pas` (cp1252), `IdeaL.Lib.PushNotification.pas` | Mobile platform helpers. |
| `IdeaL.Lib.CustomMediaPlayer.pas` (cp1252), `IdeaL.Lib.PDFViewer.pas` (UTF-8 BOM) | Media and PDF. |
| `IdeaL.Lib.Mobile.Database.pas`, `IdeaL.Lib.ManageIniFile.pas` | Local storage. |
| `IdeaL.Lib.Messaging.pas` (UTF-8 BOM), `IdeaL.Lib.Thread.pas`, `IdeaL.Lib.CustomException.pas`, `IdeaL.Lib.CommonTypes.pas` | Infrastructure. |

## Demos/

`Demos/Api/Bitcoin/{Alby,CoinOS,CoinOS/FPC,DePIX,DIGPIX}`, `Demos/Api/{DropBox,Image-ImgBB,ReceitaWs}`, and FMX feature demos: `CustomMediaPlayer`, `DateTimePicker`, `DeviceInfo`, `EditFormat`, `Loading`, `MapSharingSheet`, `MessageAndToast`, `OpenPDF`, `Permissions`, `PushNotification` (Mobile + Server), `ScrollBox`, `SelfUpdate`, `Signature`, `SslMobile`, `TCep`, `TabControl`. Sub-folders such as `Rad10_4_1`, `D11`, `12_3` are per-Delphi-version project files sharing the same view units.

### CoinOS demo (studied 2026-11-18)

| File | Notes |
| ---- | ---- |
| `Demos/Api/Bitcoin/CoinOS/Project1.dpr` / `.dproj` | FMX project; references `IdeaL.Lib.Utils`, `IdeaL.Lib.Api`, `IdeaL.Lib.Api.Bitcoin.CoinOS` by relative path. New library units must be added here and in the `.dproj`. |
| `Demos/Api/Bitcoin/CoinOS/Unit1.pas` / `.fmx` | One form, `TabControl` with Demo/Info tabs. Group boxes: account (register/login/x-api-key), profile, LN invoice create/check, pay invoice (`PostPayment` with fee cap, memo, PIN, and a Check button), pay LN address in one call (`PostPaymentLnAddress`, PIN), payments list, rates, and "Pay LN Address - 3 steps (trackable)" (Resolve, Fetch invoice, Pay, Check status). Results go to a list box (raw JSON) and a log memo. Credentials and the pending invoice are saved to `config.json` next to the exe (ignored by git); the PIN is never saved. The `.fmx` was edited by script (ASCII, CRLF kept); open it in the IDE to adjust the layout. |
| `Demos/Api/Bitcoin/CoinOS/FPC/` | Lazarus version of the same demo (`project1.lpr`, `fpcunit2.pas/.lfm`). Last changed 2025-02; predates the `TIdeaLApi` refactor. |
| `Demos/Api/Bitcoin/CoinOS/AuthToken.jpg` | Screenshot showing where to find the CoinOS token. |
