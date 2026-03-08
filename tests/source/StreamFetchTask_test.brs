' StreamFetchTask_test.brs
' Unit tests for base64 encode/decode helpers in StreamFetchTask
'
' Run with: npm test (via rooibos-cli)

' @suite StreamFetchTask Tests
namespace StreamFetchTaskTests

    ' @test encodeBase64 produces expected output
    sub encodeBase64_encodesReferrer()
        result = encodeBase64("https://www.hoteldel.com/live-webcam/")
        ' Known base64 of the referrer string
        expected = "aHR0cHM6Ly93d3cuaG90ZWxkZWwuY29tL2xpdmUtd2ViY2FtLw=="
        m.assertEqual(result, expected)
    end sub

    ' @test decodeBase64 round-trips correctly
    sub decodeBase64_roundTrip()
        original = "https://live.hdontap.com/hls/stream.m3u8"
        encoded = encodeBase64(original)
        decoded = decodeBase64(encoded)
        m.assertEqual(decoded, original)
    end sub

    ' @test decodeBase64 handles empty string
    sub decodeBase64_emptyString()
        result = decodeBase64("")
        m.assertEqual(result, "")
    end sub

end namespace
