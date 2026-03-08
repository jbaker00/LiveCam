sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    ' Memory monitoring (required for certification)
    m.memMonitor = CreateObject("roAppMemoryMonitor")
    if m.memMonitor <> invalid then
        m.memMonitor.enableMemoryWarningEvent(true)
        m.memMonitor.enableLowGeneralMemoryEvent(true)
        m.memMonitor.setMessagePort(m.port)
        print "[LiveCam] Memory limit: " m.memMonitor.getChannelMemoryLimit()
        print "[LiveCam] Memory available: " m.memMonitor.getChannelAvailableMemory()
        print "[LiveCam] Memory used: " m.memMonitor.getMemoryLimitPercent() "%"
    end if

    scene = screen.CreateScene("MainScene")
    screen.show()

    ' Pass launch-time deep link args (e.g. from voice search / Roku home shortcut).
    ' Must happen after screen.show() so the scene is fully initialised.
    if args <> invalid then
        scene.launchArgs = args
    end if

    ' Observe the exitChannel flag so we can close the screen from the main thread
    ' when the user confirms exit in the dialog.
    scene.observeField("exitChannel", m.port)

    while true
        msg = wait(0, m.port)
        msgType = type(msg)

        if msgType = "roSGScreenEvent" then
            if msg.isScreenClosed() then return

        else if msgType = "roSGNodeEvent" then
            ' exitChannel was set to true by the exit dialog confirmation
            if msg.getField() = "exitChannel" and msg.getData() = true then
                screen.close()
                return
            end if

        else if msgType = "roInputEvent" then
            ' Mid-session deep link: user launches via voice or Roku search
            ' while the channel is already running
            scene.inputArgs = msg.getInfo()

        else if msgType = "roAppMemoryMonitorEvent" then
            if msg.isMemoryWarning() then
                print "[LiveCam] Memory warning - available: " m.memMonitor.getChannelAvailableMemory()
            end if
        end if
    end while
end sub
