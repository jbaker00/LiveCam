# GitHub Copilot Instructions — Hotel Del Live Cam

A Roku channel (BrightScript/SceneGraph) that streams live beach webcams from Hotel Del Coronado via the HDOnTap backend API. No build system, package manager, or automated tests — validation is done by deploying to a real or emulated Roku device.

## Deployment

```bash
# 1. Zip the project root (exclude .git)
zip -r channel.zip . -x '*.git*'

# 2. Sideload via Roku Developer Mode
curl -s -S -F "mysubmit=Install" -F "archive=@channel.zip" \
  --user rokudev:<password> http://<roku-ip>/plugin_install
```

Enable dev mode on a Roku device: **Home × 3, Up × 2, Right, Left, Right, Left, Right**

View BrightScript logs: `telnet <roku-ip> 8085`

## Architecture

```
source/main.brs           # App entry point: event loop, screen lifecycle, deep link pass-through
components/MainScene.xml  # Full-screen UI layout at 1920×1080
components/MainScene.brs  # All app logic: playback, camera switching, key handling, exit dialog
components/StreamFetchTask.xml / .brs  # Background Task node: fetches HLS URL from HDOnTap API
```

**Data flow:**
1. `init()` in `MainScene.brs` creates two `StreamFetchTask` nodes in parallel (one per camera) and calls `task.control = "RUN"`
2. Each task POSTs to `portal.hdontap.com/backend/embed/<streamId>`, decodes the base64 JSON response, and returns `{ streamUrl: ... }` or `{ error: ... }` via the `result` field
3. `onSouthFetched` / `onNorthFetched` observers receive results and call `playCamera(idx)`
4. On stream error, a 3-second retry timer fires `onRetry()`, which clears the cached URL and re-fetches

**Exit dialog pattern:** The exit dialog is a plain SceneGraph `<Group>` overlay — not a `Dialog` node — because `Dialog` steals focus and breaks key routing. Focus always stays on the scene (`m.top.setFocus(true)`), and `onKeyEvent` routes keys into dialog navigation when `m.dialogVisible = true`.

## Key Conventions

- **Scene always owns focus.** Every code path that returns to normal playback must call `m.top.setFocus(true)`. The `Video` node must never hold focus.
- **State tracked in `m.*` variables, not node fields.** `m.dialogVisible` (bool) and `m.dialogFocus` (0/1) drive dialog rendering; `m.currentIndex` tracks the active camera.
- **Highlight via color mutation.** Active/inactive states for camera buttons and dialog buttons are expressed by directly setting `.color` on paired `<Rectangle>` (background) and `<Label>` nodes — there is no separate "selected" node type.
- **BrightScript `m` scope:** Inside a component `.brs` file, `m` refers to the component instance. `m.top` is the SceneGraph node itself. Fields declared in the XML `<interface>` block are read/written via `m.top.<fieldId>`.
- **Task node pattern:** Background work uses `extends="Task"` components. Set `m.top.functionName = "fetchStream"` in `init()`, then write inputs to fields and set `control = "RUN"` from the scene. Results come back through observed output fields.
- **Deep linking:** Both `launchArgs` (startup) and `inputArgs` (mid-session `roInputEvent`) map to the same `onLaunchArgs()` handler via `onChange`. Both `"south"`/`"0"` and `"north"`/`"1"` are valid `contentId` values.
- **Exit signal:** The scene sets `m.top.exitChannel = true`; `main.brs` observes this field and calls `screen.close()` on the main thread. Never call `screen.close()` from within a scene component.
- **Version is in `manifest`**, not a source file: `major_version`, `minor_version`, `build_version`.

## HDOnTap API

```
GET https://portal.hdontap.com/backend/embed/<streamId>?r=<base64(referrer)>
Headers: Referer: https://www.hoteldel.com/live-webcam/
         User-Agent: Mozilla/5.0 (compatible; RokuOS)
Response: base64-encoded JSON → { "streamSrc": "https://live.hdontap.com/hls/..." }
```

Stream IDs are hardcoded in the `m.cameras` array in `MainScene.brs`:
- `hdc_hoteldelsouith-4K_ptz-CUST` — Beach Camera South
- `hoteldelnorth_hdc-CUST` — Beach Camera North
