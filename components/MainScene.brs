' MainScene.brs
' Controller for the Hotel Del Live Cam main scene.
'
' Cameras:
'   index 0 = Beach Camera South  (hdc_hoteldelsouith-4K_ptz-CUST)
'   index 1 = Beach Camera North  (hoteldelnorth_hdc-CUST)
'
' On launch both stream URLs are fetched concurrently via StreamFetchTask
' background tasks. The South camera plays immediately when its URL is ready.
' The North URL is cached and played when the user switches cameras.

sub init()
    m.cameras = [
        {
            id:    "hdc_hoteldelsouith-4K_ptz-CUST",
            label: "Beach Camera South",
            url:   ""
        },
        {
            id:    "hoteldelnorth_hdc-CUST",
            label: "Beach Camera North",
            url:   ""
        }
    ]

    m.currentIndex = 0
    m.southReady = false
    m.northReady = false

    ' Grab scene node references
    m.video      = m.top.findNode("videoPlayer")
    m.statusLbl  = m.top.findNode("statusLabel")
    m.btnSouthBg = m.top.findNode("btnSouthBg")
    m.btnNorthBg = m.top.findNode("btnNorthBg")
    m.btnSouth   = m.top.findNode("btnSouth")
    m.btnNorth   = m.top.findNode("btnNorth")

    ' Size the video node to fill the full FHD canvas (1920x1080).
    ' Setting this in BrightScript is more reliable than XML attributes
    ' across different Roku firmware versions.
    m.video.width  = 1920
    m.video.height = 1080

    ' Wire up video error/state observer
    m.video.observeField("state", "onVideoStateChange")
    fetchStream(1)

    ' Give focus to this scene so we receive remote key events
    m.top.setFocus(true)
end sub

' ─────────────────────────────────────────────────────────────────────────────
' Stream URL fetching
' ─────────────────────────────────────────────────────────────────────────────

sub fetchStream(idx as Integer)
    task = CreateObject("roSGNode", "StreamFetchTask")
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
        print "[LiveCam] Fetch error for camera " idx ": " result.error
        if idx = m.currentIndex then
            setStatus("Error: " + result.error)
        end if
        return
    end if

    m.cameras[idx].url = result.streamUrl
    print "[LiveCam] Stream URL ready for camera " idx ": " result.streamUrl

    if idx = 0 then m.southReady = true
    if idx = 1 then m.northReady = true

    ' Play if this is the active camera and video isn't already running.
    ' After an error+retry the state will be "error" or "stopped", so this
    ' also covers the recovery path.
    if idx = m.currentIndex then
        state = m.video.state
        if state <> "playing" and state <> "buffering" then
            playCamera(idx)
        end if
    end if
end sub

' ─────────────────────────────────────────────────────────────────────────────
' Playback
' ─────────────────────────────────────────────────────────────────────────────

sub playCamera(idx as Integer)
    cam = m.cameras[idx]
    if cam.url = "" then
        setStatus("Loading " + cam.label + "…")
        return
    end if

    setStatus("")

    ' Always stop existing playback before loading new content.
    ' Without this, switching cameras or retrying after an error can
    ' leave the player in a bad state on some Roku firmware versions.
    m.video.control = "stop"

    content = CreateObject("roSGNode", "ContentNode")
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
        m.btnSouthBg.color = "0xFFFFFF33"
        m.btnNorthBg.color = "0x00000000"
        m.btnSouth.color   = "0xFFFFFFFF"
        m.btnNorth.color   = "0xBBBBBBFF"
    else
        m.btnSouthBg.color = "0x00000000"
        m.btnNorthBg.color = "0xFFFFFF33"
        m.btnSouth.color   = "0xBBBBBBFF"
        m.btnNorth.color   = "0xFFFFFFFF"
    end if
end sub

sub setStatus(msg as String)
    m.statusLbl.text = msg
end sub

' ─────────────────────────────────────────────────────────────────────────────
' Video state observer
' ─────────────────────────────────────────────────────────────────────────────

sub onVideoStateChange()
    state = m.video.state
    if state = "error" then
        setStatus("Stream error — retrying…")
        ' Re-fetch a fresh signed URL and retry after 3 seconds
        m.retryTimer = CreateObject("roSGNode", "Timer")
        m.retryTimer.duration = 3
        m.retryTimer.observeField("fire", "onRetry")
        m.retryTimer.control = "start"
    else if state = "playing" then
        setStatus("")
    else if state = "buffering" then
        setStatus("Buffering…")
    end if
end sub

sub onRetry()
    fetchStream(m.currentIndex)
end sub

' ─────────────────────────────────────────────────────────────────────────────
' Remote key handling
' ─────────────────────────────────────────────────────────────────────────────

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "left" or key = "up" then
        switchCamera(0)
        return true
    else if key = "right" or key = "down" then
        switchCamera(1)
        return true
    else if key = "OK" or key = "play" then
        switchCamera(m.currentIndex)    ' re-select current (force refresh)
        return true
    else if key = "back" then
        m.video.control = "stop"
        return false                    ' let Roku handle Back → exit
    end if

    return false
end function

sub switchCamera(idx as Integer)
    if idx = m.currentIndex and m.video.state = "playing" then return
    m.currentIndex = idx
    ' If URL isn't ready yet, show loading and the task result will trigger play
    playCamera(idx)
    ' If URL was empty, re-fetch (handles edge case where initial fetch failed)
    if m.cameras[idx].url = "" then
        fetchStream(idx)
    end if
end sub
