# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Hotel Del Live Cam** — a Roku channel (BrightScript/SceneGraph) that streams live beach webcams from Hotel Del Coronado via the HDOnTap backend API.

## Development & Deployment

There is no build system or package manager. Development is native Roku:

- **Package for deployment**: Zip the project root (excluding `.git`) and sideload via Roku Developer Mode (`http://<roku-ip>`)
- **Enable dev mode on Roku**: Home × 3, Up × 2, Right, Left, Right, Left, Right
- **Deploy via CLI**: `curl -s -S -F "mysubmit=Install" -F "archive=@channel.zip" --user rokudev:<password> http://<roku-ip>/plugin_install`
- **View logs**: Telnet to `<roku-ip>:8085` for BrightScript debug console

There are no linting or test tools — testing is done by deploying to a real or emulated Roku device.

## Architecture

### Entry Point → Scene → Task

```
source/main.brs          # App lifecycle: creates screen, runs event loop, handles exitChannel
    ↓ creates
components/MainScene.xml  # UI layout: full-screen video, header overlay, camera buttons, exit dialog
components/MainScene.brs  # All application logic: camera switching, playback, key handling, deep links
    ↓ spawns async
components/StreamFetchTask.brs  # Background task: fetches HLS URL from HDOnTap API
```

### Camera Data Flow

1. At launch, `MainScene.brs` creates two `StreamFetchTask` nodes in parallel (one per camera)
2. Each task calls `portal.hdontap.com` with a base64-encoded referrer, decodes the JSON response, and returns an HLS URL
3. Results are observed via `onSouthFetched` / `onNorthFetched` callbacks which call `playCamera()`
4. On error or stall, the scene retries after 3 seconds with a fresh fetch (clears cached URL)

### Key Design Decisions

- **Custom exit dialog** (XML overlay + `m.dialogVisible` flag) instead of Roku's built-in `Dialog` node — the Dialog node stole focus and broke camera switching
- **Scene always owns focus** (`m.top.setFocus(true)`) to ensure `onKeyEvent` reliably receives all remote input
- **Both streams pre-fetched at launch** so switching cameras doesn't require a new network round-trip
- **Deep linking** via `contentId`: `"south"`/`"0"` or `"north"`/`"1"` — supported at launch (`launchArgs`) and mid-session (`inputArgs`)

### Remote Key Mapping

| Key | Action |
|-----|--------|
| Left / Right / Up / Down | Switch camera |
| OK / Play | Re-fetch and replay current camera |
| Back | Show exit dialog |
| Left/Right in dialog | Select button |
| OK in dialog | Confirm selection |
| Back in dialog | Dismiss dialog |

## Key Files

| File | Purpose |
|------|---------|
| `manifest` | Channel metadata: title, version (1.0.1), resolution (FHD), icons, splash |
| `source/main.brs` | Event loop, screen lifecycle, deep link pass-through to scene |
| `components/MainScene.xml` | SceneGraph UI layout for 1920×1080 |
| `components/MainScene.brs` | All UI logic, state, playback, navigation |
| `components/StreamFetchTask.brs` | HDOnTap API integration (runs in background thread) |

## HDOnTap API

`StreamFetchTask` calls:
```
https://portal.hdontap.com/backend/embed/<streamId>
```
with a `Referer` header set to the Hotel Del Coronado website and `User-Agent` spoofed as Mozilla. The response body is base64-decoded JSON containing `streamSrc` (an HLS `.m3u8` URL).

Stream IDs are hardcoded in `MainScene.brs` in the `m.cameras` array.
