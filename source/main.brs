sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

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
        end if
    end while
end sub
