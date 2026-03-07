' StreamFetchTask.brs
' Fetches a signed HLS stream URL from the HDOnTap portal embed backend.
'
' The portal returns a base64-encoded JSON payload containing:
'   { "streamSrc": "https://live.hdontap.com/hls/..." }
'
' We supply the Hotel Del Coronado webcam page as the referrer so the
' portal recognises the embed as legitimate.

sub init()
    m.top.functionName = "fetchStream"
end sub

sub fetchStream()
    streamId = m.top.streamId
    if streamId = "" then
        m.top.result = { error: "No streamId provided" }
        return
    end if

    referrer = "https://www.hoteldel.com/live-webcam/"
    referrerB64 = encodeBase64(referrer)
    apiUrl = "https://portal.hdontap.com/backend/embed/" + streamId + "?r=" + referrerB64

    xfer = CreateObject("roURLTransfer")
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.AddHeader("Referer", referrer)
    xfer.AddHeader("User-Agent", "Mozilla/5.0 (compatible; RokuOS)")
    xfer.SetURL(apiUrl)

    response = xfer.GetToString()
    if response = "" then
        m.top.result = { error: "Empty response from stream API" }
        return
    end if

    ' Response is base64-encoded JSON
    decoded = decodeBase64(response)
    if decoded = "" then
        m.top.result = { error: "Failed to decode API response" }
        return
    end if

    json = ParseJSON(decoded)
    if json = invalid then
        m.top.result = { error: "Failed to parse stream JSON" }
        return
    end if

    if json.streamSrc <> invalid and json.streamSrc <> "" then
        m.top.result = { streamUrl: json.streamSrc }
    else if json.error = true or json.errorMessage <> invalid then
        errMsg = json.errorMessage
        if errMsg = invalid then errMsg = "Stream unavailable"
        m.top.result = { error: errMsg }
    else
        m.top.result = { error: "No stream URL in response" }
    end if
end sub

' Encode a string to base64 using roURLTransfer helper
function encodeBase64(s as String) as String
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(s)
    return ba.ToBase64String()
end function

' Decode a base64 string to a plain string
function decodeBase64(s as String) as String
    ba = CreateObject("roByteArray")
    ba.FromBase64String(s)
    return ba.ToAsciiString()
end function
