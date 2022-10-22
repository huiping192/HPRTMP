import Foundation

let url = URL(string: "rtmp://10.123.2.141:1935/stream")!
let streamKey = "hello"
let port = 1935
let socket = RTMPSocket(streamURL: url, streamKey: streamKey, port: port)
socket?.resume()
