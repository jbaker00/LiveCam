sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    ' Explicitly register for roInput events (required for certification 5.2)
    m.input = CreateObject("roInput")
    m.input.setMessagePort(m.port)

    ' Memory monitoring (required for certification)
    m.memMonitor = CreateObject("roAppMemoryMonitor")
    if m.memMonitor <> invalid then
        m.memMonitor.enableMemoryWarningEvent(true)
        m.memMonitor.setMessagePort(m.port)
        print "[LiveCam] Memory limit: " m.memMonitor.getChannelMemoryLimit()
        print "[LiveCam] Memory available: " m.memMonitor.getChannelAvailableMemory()
        print "[LiveCam] Memory used: " m.memMonitor.getMemoryLimitPercent() "%"
        print "[LiveCam] enableLowGeneralMemoryEvent: not available on this firmware"
    end if

    scene = screen.CreateScene("MainScene")
    screen.show()

    ' Pass launch-time deep link args (e.g. from voice search / Roku home shortcut).
    ' Must happen after screen.show() so the scene is fully initialised.
    if args <> invalid then
        scene.launchArgs = args
    end if

    ' AppLaunchComplete beacon: channel is visible and ready for user interaction.
    ' Must be fired from main thread after screen.show() per Roku certification 3.2.
    print "AppLaunchComplete"

    ' Observe the exitChannel flag so we can close the screen from the main thread
    ' when the user confirms exit in the dialog.
    scene.observeField("exitChannel", m.port)
    scene.observeField("dialogState", m.port)

    while true
        msg = wait(0, m.port)
        msgType = type(msg)

        if msgType = "roSGScreenEvent" then
            if msg.isScreenClosed() then return

        else if msgType = "roSGNodeEvent" then
            if msg.getField() = "exitChannel" and msg.getData() = true then
                screen.close()
                return
            else if msg.getField() = "dialogState" then
                ' Relay dialog beacons from scene to main thread
                if msg.getData() = "showing" then
                    print "AppDialogInitiate"
                else if msg.getData() = "hidden" then
                    print "AppDialogComplete"
                end if
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
