# x402 selling channel — field notes (2026-08-26)

Working seller implementation: `~/Projects/money-swarm/x402/` (server.js + assets/). Full operator brief lives in `~/Projects/money-swarm/state/X402-GUIDE.md`; this file is the condensed technical knowledge for future x402 work.

## Stack (v2 — v1 `x402-express` is DEPRECATED, drags conflicting wagmi/react peers)

```bash
npm i @x402/express @x402/core @x402/evm @x402/extensions express
```

Server skeleton (CommonJS require works):
```js
const { paymentMiddleware, x402ResourceServer } = require("@x402/express");
const { ExactEvmScheme } = require("@x402/evm/exact/server");
const { HTTPFacilitatorClient } = require("@x402/core/server");
const { declareDiscoveryExtension } = require("@x402/extensions/bazaar");

const facilitatorClient = new HTTPFacilitatorClient({ url: "https://x402.org/facilitator" });
const resourceServer = new x402ResourceServer(facilitatorClient)
  .register("eip155:84532", new ExactEvmScheme());   // network → scheme

app.use(paymentMiddleware(routes, resourceServer));   // routes: { "GET /path": {accepts:{scheme:"exact",price:"$9",network,payTo}, description, mimeType, extensions:{...declareDiscoveryExtension({...})}} }
```

## Verified behaviors (don't re-derive)

- **v2 carries the payment offer in a `PAYMENT-REQUIRED` response header** (base64 JSON), NOT the body — body is `{}` and that is correct. Decode with `base64 -d` to inspect accepts/extensions.
- `price: "$9"` auto-resolves to USDC units (`"amount":"9000000"`, 6 decimals) and the correct asset contract (Base Sepolia USDC `0x036CbD53842c5426634e7929541eC2318f3dCF7e`).
- **Public facilitator `https://x402.org/facilitator` supports Base SEPOLIA only** (`GET /facilitator/supported` lists kinds; mainnet `eip155:8453` returns route-validation errors `missing_facilitator` → protected routes 500). Mainnet requires an authenticated facilitator (CDP free tier) — flip env vars `FACILITATOR_URL` + `X402_NETWORK=eip155:8453`.
- Bazaar discovery declaration that validated in the live offer:
  ```js
  extensions: { ...declareDiscoveryExtension({
    input: {},                                  // query-param example for GET
    output: { mimeType: "application/zip", example: {...} },
  })}
  ```
  Facilitators catalog resources from this metadata automatically — no separate marketplace registration.
- Zero-account public URL: `npx -y localtunnel --port <port>` (loca.lt). Worked end-to-end on first try (real 402 through the tunnel), then began rate-limiting (408s) within ~10 min. Fine for demos; permanent hosting needs Railway/Fly/Vercel (human login step).

## Design constraints from consent gate / custody

- NEVER generate or store private keys/mnemonics on the user's behalf — the AFK consent gate blocks it, and it's correct custody practice anyway. Receiving address stays a required env var (`PAY_TO`, regex-validated at startup, server refuses to boot without it).
- Placeholder test address used this session: `0x000000000000000000000000000000000000dead`.

## Debugging recipe (local protocol verification without funds)

1. Run server locally with dummy-format PAY_TO.
2. `curl -si localhost:PORT/packs/x` → expect `HTTP/1.1 402` + `PAYMENT-REQUIRED:` header.
3. Decode header → verify scheme/network/amount/asset/payTo/extensions.bazaar present.
4. `/healthz` (free route) echoes active network+payTo config.

Real settlement testing needs a funded buyer wallet (Sepolia USDC faucet) — operator/human step.
