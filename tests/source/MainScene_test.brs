' MainScene_test.brs
' Unit tests for MainScene business logic (camera index resolution)
'
' Run with: npm test (via rooibos-cli)

' @suite MainScene Deep Link Tests
namespace MainSceneTests

    ' Helper: mirrors the deep link resolution logic from onLaunchArgs()
    function resolveCameraIndex(contentId as String) as Integer
        cid = lcase(contentId)
        if cid = "north" or cid = "beach-camera-north" or cid = "1" then
            return 1
        end if
        return 0
    end function

    ' @test "south" content ID resolves to index 0
    sub deepLink_south_resolvesTo0()
        m.assertEqual(resolveCameraIndex("south"), 0)
    end sub

    ' @test "beach-camera-south" resolves to index 0
    sub deepLink_beachCameraSouth_resolvesTo0()
        m.assertEqual(resolveCameraIndex("beach-camera-south"), 0)
    end sub

    ' @test "0" resolves to index 0
    sub deepLink_zeroString_resolvesTo0()
        m.assertEqual(resolveCameraIndex("0"), 0)
    end sub

    ' @test "north" resolves to index 1
    sub deepLink_north_resolvesTo1()
        m.assertEqual(resolveCameraIndex("north"), 1)
    end sub

    ' @test "beach-camera-north" resolves to index 1
    sub deepLink_beachCameraNorth_resolvesTo1()
        m.assertEqual(resolveCameraIndex("beach-camera-north"), 1)
    end sub

    ' @test "1" resolves to index 1
    sub deepLink_oneString_resolvesTo1()
        m.assertEqual(resolveCameraIndex("1"), 1)
    end sub

    ' @test unknown content ID defaults to south (index 0)
    sub deepLink_unknown_defaultsTo0()
        m.assertEqual(resolveCameraIndex("some-other-id"), 0)
    end sub

    ' @test content ID is case-insensitive
    sub deepLink_caseInsensitive()
        m.assertEqual(resolveCameraIndex("NORTH"), 1)
        m.assertEqual(resolveCameraIndex("South"), 0)
    end sub

end namespace
