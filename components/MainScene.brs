' MainScene.brs
' Controller for the Hotel Del Live Cam main scene.
'
' Cameras:
'   index 0 = Beach Camera South  (hdc_hoteldelsouith-4K_ptz-CUST)
'   index 1 = Beach Camera North  (hoteldelnorth_hdc-CUST)
'
' Deep link content IDs accepted:
'   "south", "beach-camera-south", "0"  -> camera 0
'   "north", "beach-camera-north", "1"  -> camera 1

sub init()
    m.cameras = [
        { id: "hdc_hoteldelsouith-4K_ptz-CUST", label: "Beach Camera South", url: "" },
        { id: "hoteldelnorth_hdc-CUST",          label: "Beach Camera North", url: "" }
    ]
    m.currentIndex = 0

    ' ── Node references ──────────────────────────────────────────────────────
    m.video       = m.top.findNode("videoPlayer")
    m.statusLbl   = m.top.findNode("statusLabel")
    m.headerGroup = m.top.findNode("headerGroup")
    m.btnSouthBg  = m.top.findNode("btnSouthBg")
    m.btnNorthBg  = m.top.findNode("btnNorthBg")
    m.btnSouth    = m.top.findNode("btnSouth")
    m.btnNorth    = m.top.findNode("btnNorth")

    ' ── Video setup ──────────────────────────────────────────────────────────
    m.video.width  = 1920
    m.video.height = 1080
    m.video.observeField("state", "onVideoStateChange")

    ' ── Exit dialog ──────────────────────────────────────────────────────────
    ' Created once and reused; shown by setting m.top.dialog = m.exitDialog
    m.exitDialog = CreateObject("roSGNode", "Dialog")
    m.exitDialog.title   = "Exit Hotel Del Live Cam"
    m.exitDialog.message = "Are you sure you want to exit?"
    m.exitDialog.buttons = ["Exit", "Cancel"]
    m.exitDialog.observeField("buttonSelected", "onExitDialogButton")
    m.exitDialog.observeField("wasDismissed",   "onExitDialogDismissed")

    ' ── Header auto-hide timer ────────────────────────────────────────────────
    m.hideTimer          = CreateObject("roSGNode", "Timer")
    m.hideTimer.duration = 5
    m.hideTimer.repeat   = false
    m.hideTimer.observeField("fire", "onHideTimerFired")

    ' ── Fetch both stream URLs concurrently at launch ─────────────────────────
    fetchStream(0)
    fetchStream(1)

    m.top.setFocus(true)
end sub

' =============================================================================
' Deep linking
' =============================================================================

' Called when launchArgs or inputArgs changes (both fields share this handler).
' Roku passes content info as an AA with at least a "contentId" key.
' We map the contentId to a camera index and switch to it.
sub onLaunchArgs()
    ' Prefer inputArgs (mid-session) over launchArgs, but both use this handler.
    ' Whichever field last changed will have the fresh value.
    args = m.top.inputArgs
    if args = invalid or args.contentId = invalid then
        args = m.top.launchArgs
    end if
    if args = invalid then return

    contentId = args.contentId
    if contentId = invalid then return
    contentId = lcase(contentId)

    if contentId = "north" or contentId = "beach-camera-north" or contentId = "1" then
        print "[LiveCam] Deep link -> North camera"
        switchCamera(1)
    else
        ' Default / "south" / "beach-camera-south" / "0"
        print "[LiveCam] Deep link -> South camera (contentId=" + contentId + ")"
        switchCamera(0)
    end if
end sub

' =============================================================================
' Stream URL fetching
' =============================================================================

sub fetchStream(idx as Integer)
    task          = CreateObject("roSGNode", "StreamFetchTask")
    task.streamId = m.cameras[idx].id

    if idx = 0 then
        task.observeField("result", "onSouthFetched")
        m.southTask = task
    else
        task.observeField("result", "onNorthFetched")
        m.northTask = task
    end if

    task.control = "RUN"
end sub

sub onSouthFetched()
    if m.southTask = invalid then return
    handleFetchResult(0, m.southTask.result)
end sub

sub onNorthFetched()
    if m.northTask = invalid then return
    handleFetchResult(1, m.northTask.result)
end sub

sub handleFetchResult(idx as Integer, result as Object)
    if result = invalid then return

    if result.error <> invalid then
        print "[LiveCam] Fetch error camera " idx ": " result.error
        if idx = m.currentIndex then setStatus("Error: " + result.error)
        return
    end if

    m.cameras[idx].url = result.streamUrl
    print "[LiveCam] URL ready camera " idx

    if idx = m.currentIndex then
        state = m.video.state
        if state <> "playing" and state <> "buffering" then
            playCamera(idx)
        end if
    end if
end sub

' =============================================================================
' Playback
' =============================================================================

sub playCamera(idx as Integer)
    cam = m.cameras[idx]
    if cam.url = "" then
        setStatus("Loading " + cam.label + "...")
        return
    end if

    setStatus("")
    m.video.control = "stop"

    content              = CreateObject("roSGNode", "ContentNode")
    content.url          = cam.url
    content.streamFormat = "hls"
    content.title        = cam.label

    m.video.content = content
    m.video.visible = true
    m.video.control = "play"

    updateButtonHighlight(idx)
end sub

sub updateButtonHighlight(idx as Integer)
    if idx = 0 then
        m.btnSouthBg.color = "0xFFFFFF33" : m.btnNorthBg.color = "0x00000000"
        m.btnSouth.color   = "0xFFFFFFFF" : m.btnNorth.color   = "0xBBBBBBFF"
    else
        m.btnSouthBg.color = "0x00000000" : m.btnNorthBg.color = "0xFFFFFF33"
        m.btnSouth.color   = "0xBBBBBBFF" : m.btnNorth.color   = "0xFFFFFFFF"
    end if
end sub

sub setStatus(msg as String)
    m.statusLbl.text = msg
end sub

' =============================================================================
' Header auto-hide
' =============================================================================

sub showHeader()
    m.headerGroup.visible = true
    m.hideTimer.control   = "stop"
    m.hideTimer.control   = "start"
end sub

sub onHideTimerFired()
    if m.video.state = "playing" then
        m.headerGroup.visible = false
    end if
end sub

' =============================================================================
' Video state
' =============================================================================

sub onVideoStateChange()
    state = m.video.state
    if state = "error" then
        setStatus("Stream error - retrying...")
        showHeader()
        m.retryTimer = CreateObject("roSGNode", "Timer")
        m.retryTimer.duration = 3
        m.retryTimer.observeField("fire", "onRetry")
        m.retryTimer.control = "start"
    else if state = "playing" then
        setStatus("")
        showHeader()
    else if state = "buffering" then
        setStatus("Buffering...")
    end if
end sub

sub onRetry()
    ' Discard the old URL so we re-fetch a fresh signed token
    m.cameras[m.currentIndex].url = ""
    fetchStream(m.currentIndex)
end sub

' =============================================================================
' Exit dialog
' =============================================================================

sub showExitDialog()
    m.video.control  = "pause"
    m.top.dialog     = m.exitDialog
    m.exitDialog.visible = true
end sub

' Called when the user selects a button in the exit dialog.
'   index 0 = "Exit"   -> signal main.brs to close the screen
'   index 1 = "Cancel" -> resume playback
sub onExitDialogButton()
    idx = m.exitDialog.buttonSelected
    dismissExitDialog()

    if idx = 0 then
        ' Tell main.brs to close the screen (can only call screen.close()
        ' from the main thread, not from a SceneGraph component)
        m.video.control     = "stop"
        m.top.exitChannel   = true
    else
        ' Cancel - resume wherever we left off
        m.video.control = "play"
    end if
end sub

' Called if the user presses Back while the dialog is shown (dismisses it)
sub onExitDialogDismissed()
    dismissExitDialog()
    m.video.control = "play"
end sub

sub dismissExitDialog()
    m.exitDialog.visible = false
    m.top.dialog         = invalid
end sub

' =============================================================================
' Remote key handling
' =============================================================================

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    ' If the exit dialog is visible, Back dismisses it (handled by
    ' wasDismissed observer above) — don't also handle it here
    if m.exitDialog.visible then return false

    showHeader()

    if key = "left" or key = "up" then
        switchCamera(0)
        return true
    else if key = "right" or key = "down" then
        switchCamera(1)
        return true
    else if key = "OK" or key = "play" then
        switchCamera(m.currentIndex)
        return true
    else if key = "back" then
        showExitDialog()
        return true   ' consume Back so Roku doesn't immediately exit
    end if

    return false
end function

sub switchCamera(idx as Integer)
    if idx = m.currentIndex and m.video.state = "playing" then return
    m.currentIndex = idx
    playCamera(idx)
    if m.cameras[idx].url = "" then fetchStream(idx)
end sub
