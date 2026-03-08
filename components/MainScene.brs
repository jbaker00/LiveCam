' MainScene.brs — Hotel Del Live Cam controller
'
' Cameras:
'   0 = Beach Camera South  (hdc_hoteldelsouith-4K_ptz-CUST)
'   1 = Beach Camera North  (hoteldelnorth_hdc-CUST)
'
' Deep link contentId values:
'   "south" / "beach-camera-south" / "0"  -> index 0
'   "north" / "beach-camera-north" / "1"  -> index 1

sub init()
    m.cameras = [
        { id: "hdc_hoteldelsouith-4K_ptz-CUST", label: "Beach Camera South", url: "" },
        { id: "hoteldelnorth_hdc-CUST",          label: "Beach Camera North", url: "" }
    ]
    m.currentIndex  = 0
    m.dialogVisible = false   ' tracks exit dialog state; avoids any Dialog-node focus issues
    m.dialogFocus   = 0       ' 0 = Keep Watching, 1 = Exit

    ' ── Node refs ────────────────────────────────────────────────────────────
    m.video       = m.top.findNode("videoPlayer")
    m.statusLbl   = m.top.findNode("statusLabel")
    m.headerGroup = m.top.findNode("headerGroup")
    m.btnSouthBg  = m.top.findNode("btnSouthBg")
    m.btnNorthBg  = m.top.findNode("btnNorthBg")
    m.btnSouth    = m.top.findNode("btnSouth")
    m.btnNorth    = m.top.findNode("btnNorth")
    m.exitDialog  = m.top.findNode("exitDialog")
    m.btnKeepBg   = m.top.findNode("btnKeepBg")
    m.btnExitBg   = m.top.findNode("btnExitBg")
    m.btnKeep     = m.top.findNode("btnKeep")
    m.btnExit     = m.top.findNode("btnExit")

    ' ── Video ────────────────────────────────────────────────────────────────
    m.video.width  = 1920
    m.video.height = 1080
    m.video.observeField("state", "onVideoStateChange")

    ' ── Header auto-hide timer ────────────────────────────────────────────────
    m.hideTimer          = CreateObject("roSGNode", "Timer")
    m.hideTimer.duration = 5
    m.hideTimer.repeat   = false
    m.hideTimer.observeField("fire", "onHideTimerFired")

    ' ── Fetch both stream URLs at launch ─────────────────────────────────────
    fetchStream(0)
    fetchStream(1)

    m.top.setFocus(true)

    ' Performance beacon: UI is rendered and channel is ready for interaction
    print "AppLaunchComplete"
end sub

' =============================================================================
' Deep linking
' =============================================================================

' Handles both launchArgs (startup) and inputArgs (mid-session roInputEvent).
' Both fields share this one handler via their onChange attribute.
sub onLaunchArgs()
    args = m.top.inputArgs
    if args = invalid or args.contentId = invalid then
        args = m.top.launchArgs
    end if
    if args = invalid or args.contentId = invalid then return

    cid = lcase(args.contentId)
    if cid = "north" or cid = "beach-camera-north" or cid = "1" then
        print "[LiveCam] Deep link -> North"
        switchCamera(1)
    else
        print "[LiveCam] Deep link -> South (contentId=" + cid + ")"
        switchCamera(0)
    end if
end sub

' =============================================================================
' Stream fetching
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
        print "[LiveCam] Fetch error cam " idx ": " result.error
        if idx = m.currentIndex then setStatus("Error: " + result.error)
        return
    end if
    m.cameras[idx].url = result.streamUrl
    print "[LiveCam] URL ready cam " idx
    ' Auto-play on whichever camera is currently selected
    if idx = m.currentIndex then
        st = m.video.state
        if st <> "playing" and st <> "buffering" then
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

    updateCameraButtons(idx)

    ' Keep focus on the scene so onKeyEvent keeps receiving keys
    m.top.setFocus(true)
end sub

sub updateCameraButtons(idx as Integer)
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
    ' Only hide when actively playing and no dialog is up
    if m.video.state = "playing" and not m.dialogVisible then
        m.headerGroup.visible = false
    end if
end sub

' =============================================================================
' Video state changes
' =============================================================================

sub onVideoStateChange()
    state = m.video.state
    if state = "error" then
        setStatus("Stream error - retrying...")
        showHeader()
        m.retryTimer          = CreateObject("roSGNode", "Timer")
        m.retryTimer.duration = 3
        m.retryTimer.observeField("fire", "onRetry")
        m.retryTimer.control  = "start"
    else if state = "playing" then
        setStatus("")
        showHeader()
    else if state = "buffering" then
        setStatus("Buffering...")
    end if
end sub

sub onRetry()
    ' Discard stale URL so we get a fresh signed token
    m.cameras[m.currentIndex].url = ""
    fetchStream(m.currentIndex)
end sub

' =============================================================================
' Exit dialog — pure BrightScript overlay, no Dialog node, no focus stealing
' =============================================================================

sub showExitDialog()
    m.dialogVisible      = true
    m.dialogFocus        = 0   ' default: Keep Watching
    m.video.control      = "pause"
    m.headerGroup.visible = true   ' keep header visible while dialog is open
    m.hideTimer.control  = "stop"
    m.exitDialog.visible = true
    updateDialogHighlight()
    print "AppDialogInitiate"
end sub

sub hideExitDialog()
    m.dialogVisible      = false
    m.exitDialog.visible = false
    m.video.control      = "play"
    print "AppDialogComplete"
    ' Restart auto-hide countdown now that we're back to playing
    showHeader()
end sub

sub updateDialogHighlight()
    if m.dialogFocus = 0 then
        ' "Keep Watching" highlighted
        m.btnKeepBg.color = "0xFFFFFF33" : m.btnExitBg.color = "0x00000000"
        m.btnKeep.color   = "0xFFFFFFFF" : m.btnExit.color   = "0x888888FF"
    else
        ' "Exit" highlighted
        m.btnKeepBg.color = "0x00000000" : m.btnExitBg.color = "0xCC2222CC"
        m.btnKeep.color   = "0x888888FF" : m.btnExit.color   = "0xFFFFFFFF"
    end if
end sub

sub doExit()
    print "AppDialogComplete"
    m.video.control    = "stop"
    m.top.exitChannel  = true   ' main.brs observes this and calls screen.close()
end sub

' =============================================================================
' Camera switching
' =============================================================================

sub switchCamera(idx as Integer)
    m.currentIndex = idx
    playCamera(idx)
    if m.cameras[idx].url = "" then fetchStream(idx)
end sub

' =============================================================================
' Remote key handling
' =============================================================================

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    ' ── Dialog is open: route all keys into dialog navigation ────────────────
    if m.dialogVisible then
        if key = "left" or key = "up" then
            m.dialogFocus = 0
            updateDialogHighlight()
            return true
        else if key = "right" or key = "down" then
            m.dialogFocus = 1
            updateDialogHighlight()
            return true
        else if key = "OK" or key = "select" then
            if m.dialogFocus = 1 then
                doExit()
            else
                hideExitDialog()
            end if
            return true
        else if key = "back" then
            hideExitDialog()
            return true
        end if
        return true   ' swallow all other keys while dialog is open
    end if

    ' ── Normal playback keys ──────────────────────────────────────────────────
    showHeader()

    if key = "left" or key = "up" then
        switchCamera(0)
        return true
    else if key = "right" or key = "down" then
        switchCamera(1)
        return true
    else if key = "OK" or key = "play" then
        ' Re-fetch + replay the current camera (useful if stream stalled)
        m.cameras[m.currentIndex].url = ""
        fetchStream(m.currentIndex)
        return true
    else if key = "back" then
        showExitDialog()
        return true
    end if

    return false
end function
