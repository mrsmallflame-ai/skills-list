# Electron Browser-Clone QA Checklist

Gotchas from building a Strawberry-Browser clone (Electron + Svelte 5 + TS strict). Each item was a real user-visible bug. Use as a pre-ship checklist when working on browser clones or multi-view Electron apps.

## IPC payload canonicalization (the #1 recurring bug class)

Multiple UI components independently invoke the same channel with DIFFERENT payload keys (`{tabId}` vs `{id}`, bare strings vs objects). The main handler reads one key → other callers resolve empty → silently no-op. Symptoms: "clicking does nothing", "closes the wrong tab".

Fix pattern: a pure resolver accepting every real call-site shape, used by ALL handlers of that domain:
```ts
// src/shared/tabs.ts
export function resolveTabId(payload: unknown): string {
  if (typeof payload === 'string') return payload
  const p = payload as { id?: string; tabId?: string }
  return p?.id ?? p?.tabId ?? ''
}
```
Plus regression tests enumerating each real call site's payload shape. When you fix one channel, grep sibling handlers for the same mismatch — they cluster.

## Internal-route placeholder matching

Omnibox/address bars bound to the active tab URL must blank out for internal pages, but URLs arrive with trailing slashes/query variants (`app://newtab` vs `app://newtab/`). Exact-equality checks leak raw internal URLs into the address bar.
```ts
const u = activeTab.url || ''
value = /^app:\/\/newtab($|[/?])/.test(u) ? '' : u
```

## Overlay layers above webviews

Floating widgets (agent orbs, PiP toasts) rendered over web content must set `pointer-events: none` on the layer and render only when entries exist — otherwise an invisible container intercepts every click ("can't switch tabs"). Keep the overlay inside the measured bounds container so existing ResizeObserver → `win:content-inset` reporting stays correct.

## "Dead button" symptom = handler module never registered

A whole feature (downloads) had list/clear/open buttons wired in the renderer while its main-process module (`extras/downloads.ts`) with all DL_* handlers was never imported/registered — everything no-oped. Checklist per feature: handler file exists → registered in the central registration function → preload bridge allowlists the channel (or generic `Object.values(IPC)` passthrough covers it) → renderer calls typed channel name.

## Advertised-but-unimplemented settings erode trust

Settings checkboxes with zero consumers (YouTube auto-PiP was one), model-facing tools always rejected at runtime (schema advertises `spawn_subagent`, loop rejects it), and fabricated placeholder rows (fake saved passwords) all read as broken product. Either implement minimally or remove from the surface; never ship a lying control.

## macOS GUI launch from agent sandboxes / daemons

Electron apps SIGABRT during `[NSApplication sharedApplication]` when launched from sandboxed agents or background daemons (`responsibleProc:` shows the daemon). Workaround: `open -n -a "<abs>/node_modules/electron/dist/Electron.app" --args <abs-app-dir>` routes through launchd's user session and works. In-worker tasks should mark `LAUNCH-VERIFY: DEFERRED TO INTEGRATOR`.

## YouTube auto-PiP implementation notes

- On departure of a youtube.com/watch tab (will-navigate, did-start-navigation for programmatic loadURL — will-navigate alone misses omnibox loads, did-navigate-in-page for SPA transitions): probe `{playing, currentTime}` via executeJavaScript, call `video.requestPictureInPicture()`.
- Native PiP dies at document teardown by design → simultaneously open a small always-on-top BrowserWindow loading `watch?v=<id>&autoplay=1&t=<currentTime>` on the same profile partition (stays signed in).
- One departure fires MULTIPLE nav events → time-windowed echo suppression (~4 s) keyed on video id; re-arm after window so hopping videos pops again.
- Tab close path must defer `webContents.close()` ~1 s so the probe completes first.
- Gate everything behind the settings flag; push a toast through IPC on pop-out.

## Pre-push hygiene

1. Verify built bundles contain new user-visible strings: `grep -l "exact string" out/renderer/assets/*.js` — stale `out/` dirs mislead (multiple hashed bundles linger).
2. Secret-scan full git history (`git log --all -p | grep -E 'sk-or-[A-Za-z0-9]{20}'`) before pushing public repos — API keys written into userData are safe there but any committed .env is not.
3. Run deterministic conformance checkers (R-checks) plus behavioral audits comparing against upstream docs (fetch llms.txt-style indexes for authoritative feature lists).

## Discoverability is part of done

Features buried behind non-obvious navigation read as missing to users ("where is X?") even when fully implemented. Standard entry points for browser features: new-tab page cards (Chrome puts import prompts here), right-click context menus on the related surface, toolbar/omnibox-row buttons, Settings nav near the top. A tiny text pill button reads as invisible — size and label matter.
