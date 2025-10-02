import Foundation
import Combine

// MARK: - EventSource Implementation for iOS
class EventSourceService: NSObject, ObservableObject {
    private var urlSessionTask: URLSessionDataTask?
    private var urlSession: URLSession?

    // Event handlers
    var onOpen: (() -> Void)?
    var onMessage: ((EventSourceEvent) -> Void)?
    var onError: ((Error) -> Void)?

    private let url: URL
    private let headers: [String: String]

    // Connection state
    @Published var isConnected = false
    @Published var connectionError: Error?

    // Buffer for incomplete SSE data
    private var dataBuffer = ""

    init(url: URL, headers: [String: String] = [:]) {
        self.url = url
        self.headers = headers
        super.init()

        // Create URLSession with delegate and SSE-optimized configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 0  // No timeout for SSE
        config.timeoutIntervalForResource = 0  // No timeout for SSE
        config.waitsForConnectivity = true  // Wait for network connectivity
        config.shouldUseExtendedBackgroundIdleMode = true  // Keep connection alive longer
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData  // No caching for SSE
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func connect() {
        guard urlSessionTask == nil else {
            #if DEBUG
            print("🔗 EventSource: ⚠️ Already connected or connecting")
            #endif
            return
        }

        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")

        // Add custom headers (like Authorization)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        #if DEBUG
        print("🔗 EventSource: 🚀 Connecting to \(url.absoluteString)")
        print("🔗 EventSource: 🚀 Headers: \(headers)")
        print("🔗 EventSource: 🚀 All request headers: \(request.allHTTPHeaderFields ?? [:])")
        #endif

        urlSessionTask = urlSession?.dataTask(with: request)
        urlSessionTask?.resume()

        #if DEBUG
        print("🔗 EventSource: 🚀 Data task created and resumed")
        #endif
    }

    func disconnect() {
        #if DEBUG
        print("🔗 EventSource: 🔌 Disconnecting...")
        #endif

        urlSessionTask?.cancel()
        urlSessionTask = nil

        // Clear the buffer
        dataBuffer = ""

        DispatchQueue.main.async {
            self.isConnected = false
        }

        #if DEBUG
        print("🔗 EventSource: 🔌 Disconnected and cleaned up")
        #endif
    }

    deinit {
        disconnect()
    }
}

// MARK: - URLSessionDataDelegate
extension EventSourceService: URLSessionDataDelegate {

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }

        #if DEBUG
        print("🔗 EventSource: Response status: \(httpResponse.statusCode)")
        #endif

        if httpResponse.statusCode == 200 {
            DispatchQueue.main.async {
                self.isConnected = true
                self.connectionError = nil
            }
            self.onOpen?()
            completionHandler(.allow)
        } else {
            let error = EventSourceError.httpError(httpResponse.statusCode)
            DispatchQueue.main.async {
                self.connectionError = error
            }
            self.onError?(error)
            completionHandler(.cancel)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard var string = String(data: data, encoding: .utf8) else {
            #if DEBUG
            print("🔗 EventSource: ❌ Failed to decode data as UTF-8")
            #endif
            return
        }

        #if DEBUG
        print("🔗 EventSource: 📨 Raw received chunk: '\(string.debugDescription)'")
        print("🔗 EventSource: 📨 Chunk length: \(data.count) bytes")
        print("🔗 EventSource: 📨 Current buffer length: \(dataBuffer.count) chars")
        #endif

        // CRITICAL FIX: Check if the chunk is JSON-encoded (happens with some tunnels/proxies)
        // If it starts and ends with quotes, it's likely JSON-encoded
        if string.hasPrefix("\"") && string.hasSuffix("\"") {
            // Remove surrounding quotes and unescape
            let trimmed = String(string.dropFirst().dropLast())
            // Unescape JSON string (convert \n to actual newlines, \" to quotes)
            string = trimmed
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")

            #if DEBUG
            print("🔗 EventSource: 🔧 Decoded JSON-encoded SSE chunk")
            print("🔗 EventSource: 🔧 Decoded chunk: '\(string.debugDescription)'")
            #endif
        }

        // Add new data to buffer
        dataBuffer += string

        #if DEBUG
        print("🔗 EventSource: 🧰 Buffer after append: '\(dataBuffer.debugDescription)'")
        print("🔗 EventSource: 🧰 Total buffer length: \(dataBuffer.count) chars")
        #endif

        // Process complete events in the buffer
        processBufferedData()
    }

    private func processBufferedData() {
        // Normalize line endings to handle CRLF and mixed endings from SSE servers
        let normalized = dataBuffer
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        #if DEBUG
        if normalized != dataBuffer {
            print("🔗 EventSource: 🧼 Normalized line endings (CRLF → LF)")
        }
        #endif

        // Split buffer by double LF (represents a blank line after normalization)
        let eventChunks = normalized.components(separatedBy: "\n\n")

        #if DEBUG
        print("🔗 EventSource: 🔄 Processing buffer, found \(eventChunks.count) potential events")
        #endif

        // Process all complete events (all but the last chunk)
        for i in 0..<(eventChunks.count - 1) {
            let eventChunk = eventChunks[i]

            #if DEBUG
            print("🔗 EventSource: 🎬 Processing complete event chunk \(i): '\(eventChunk)'")
            #endif

            if !eventChunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parseEventChunk(eventChunk)
            }
        }

        // Keep the last chunk in buffer (might be incomplete)
        if eventChunks.count > 1 {
            dataBuffer = eventChunks.last ?? ""
        } else {
            // No complete events found; keep the normalized buffer so future appends are consistent
            dataBuffer = eventChunks.first ?? ""
        }

        #if DEBUG
        print("🔗 EventSource: 🧰 Remaining buffer: '\(dataBuffer.debugDescription)'")
        #endif

        // If buffer gets too large, reset it to prevent memory issues
        if dataBuffer.count > 10000 {
            #if DEBUG
            print("🔗 EventSource: ⚠️ Buffer too large (\(dataBuffer.count) chars), resetting")
            #endif
            dataBuffer = ""
        }
    }

    private func parseEventChunk(_ chunk: String) {
        let lines = chunk.components(separatedBy: CharacterSet.newlines)
        var eventData: [String: String] = [:]

        #if DEBUG
        print("🔗 EventSource: 📋 Parsing \(lines.count) lines in event chunk:")
        for (index, line) in lines.enumerated() {
            print("🔗 EventSource: 📋   Line \(index): '\(line)'")
        }
        #endif

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine.isEmpty {
                continue // Skip empty lines within the chunk
            } else if trimmedLine.hasPrefix("data:") {
                let data = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                #if DEBUG
                print("🔗 EventSource: 📦 Found data field: '\(data)'")
                #endif

                // Handle multiline data by appending with newlines
                if eventData["data"] != nil {
                    eventData["data"]! += "\n" + data
                } else {
                    eventData["data"] = data
                }
            } else if trimmedLine.hasPrefix("event:") {
                let event = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                #if DEBUG
                print("🔗 EventSource: 🏷️ Found event field: '\(event)'")
                #endif
                eventData["event"] = event
            } else if trimmedLine.hasPrefix("id:") {
                let id = String(trimmedLine.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                #if DEBUG
                print("🔗 EventSource: 🆔 Found id field: '\(id)'")
                #endif
                eventData["id"] = id
            } else if trimmedLine.hasPrefix("retry:") {
                let retry = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                #if DEBUG
                print("🔗 EventSource: ⏱️ Found retry field: '\(retry)'")
                #endif
                eventData["retry"] = retry
            } else if !trimmedLine.hasPrefix(":") {
                // Unknown field - log it but don't fail
                #if DEBUG
                print("🔗 EventSource: ❓ Unknown SSE field: '\(trimmedLine)'")
                #endif
            }
            // Lines starting with ":" are comments and should be ignored
        }

        // Process the complete event
        if !eventData.isEmpty {
            #if DEBUG
            print("🔗 EventSource: 🎯 Processing complete event: \(eventData)")
            #endif
            processEvent(eventData)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didCompleteWithError error: Error?) {
        #if DEBUG
        print("🔗 EventSource: ⚠️ Connection completed/disconnected")
        print("🔗 EventSource: ⚠️ URL: \(dataTask.originalRequest?.url?.absoluteString ?? "unknown")")
        print("🔗 EventSource: ⚠️ Response status: \((dataTask.response as? HTTPURLResponse)?.statusCode ?? -1)")
        print("🔗 EventSource: ⚠️ Bytes received: \(dataTask.countOfBytesReceived)")
        
        if let error = error {
            print("🔗 EventSource: ❌ Error: \(error)")
            print("🔗 EventSource: ❌ Error code: \((error as NSError).code)")
            print("🔗 EventSource: ❌ Error domain: \((error as NSError).domain)")
            print("🔗 EventSource: ❌ Error description: \(error.localizedDescription)")
            
            // Check for specific error types
            if let urlError = error as? URLError {
                print("🔗 EventSource: ❌ URLError code: \(urlError.code.rawValue)")
                switch urlError.code {
                case .cancelled:
                    print("🔗 EventSource: ❌ Connection was cancelled")
                case .timedOut:
                    print("🔗 EventSource: ❌ Connection timed out")
                case .networkConnectionLost:
                    print("🔗 EventSource: ❌ Network connection lost")
                case .notConnectedToInternet:
                    print("🔗 EventSource: ❌ Not connected to internet")
                default:
                    print("🔗 EventSource: ❌ Other URLError: \(urlError.localizedDescription)")
                }
            }
        } else {
            print("🔗 EventSource: ℹ️ Connection closed normally (no error)")
        }
        #endif

        DispatchQueue.main.async {
            self.isConnected = false
        }

        if let error = error {
            DispatchQueue.main.async {
                self.connectionError = error
            }
            self.onError?(error)
        }
    }

    private func processEvent(_ eventData: [String: String]) {
        let event = EventSourceEvent(
            id: eventData["id"],
            event: eventData["event"],
            data: eventData["data"] ?? ""
        )

        #if DEBUG
        print("🔗 EventSource: 🎬 Processing event:")
        print("🔗 EventSource: 🎬   ID: \(event.id ?? "nil")")
        print("🔗 EventSource: 🎬   Event: \(event.event ?? "nil")")
        print("🔗 EventSource: 🎬   Data: '\(event.data)'")
        print("🔗 EventSource: 🎬   Data length: \(event.data.count) chars")
        #endif

        DispatchQueue.main.async {
            #if DEBUG
            print("🔗 EventSource: 🚀 Calling onMessage handler on main thread")
            #endif
            self.onMessage?(event)
        }
    }
}

// MARK: - EventSourceEvent
struct EventSourceEvent {
    let id: String?
    let event: String?
    let data: String
}

// MARK: - EventSourceError
enum EventSourceError: LocalizedError {
    case httpError(Int)
    case connectionFailed
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .connectionFailed:
            return "Connection failed"
        case .invalidURL:
            return "Invalid URL"
        }
    }
}