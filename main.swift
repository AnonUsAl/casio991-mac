import Cocoa
import WebKit
import Foundation

// MARK: - 内置本地 HTTP 服务（只监听 127.0.0.1，供给 WASM/fetch 同源加载）
final class LocalHTTPServer {
    private var socketFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private let root: URL
    private(set) var port: UInt16 = 0

    init(root: URL) { self.root = root }

    func start() {
        socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else { return }
        var reuse: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_port = 0 // 系统分配随机端口
        let bindOK = withUnsafePointer(to: &addr) { p in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) { sp in
                bind(socketFD, sp, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
        guard bindOK else { return }

        var bound = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &bound) { p in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) { sp in
                getsockname(socketFD, sp, &len)
            }
        }
        port = UInt16(bigEndian: bound.sin_port)
        listen(socketFD, 16)

        acceptSource = DispatchSource.makeReadSource(fileDescriptor: socketFD, queue: DispatchQueue.global(qos: .userInitiated))
        acceptSource?.setEventHandler { [weak self] in
            while let self = self {
                let client = accept(self.socketFD, nil, nil)
                if client < 0 { break }
                DispatchQueue.global(qos: .userInitiated).async { self.handle(client: client) }
            }
        }
        acceptSource?.resume()
    }

    private func handle(client: Int32) {
        defer { close(client) }
        var buffer = [UInt8](repeating: 0, count: 8192)
        let n = recv(client, &buffer, buffer.count, 0)
        guard n > 0 else { return }
        let request = String(bytes: buffer[0..<n], encoding: .utf8) ?? ""
        let firstLine = request.split(separator: "\r\n").first ?? ""
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return sendStatus(client, 400, "Bad Request") }
        let method = String(parts[0])
        var path = String(parts[1]).components(separatedBy: "?")[0]
        if path == "/" { path = "/index.html" }
        path = path.removingPercentEncoding ?? path

        let target = root.appendingPathComponent(path).standardizedFileURL
        guard target.path.hasPrefix(root.path + "/") else { return sendStatus(client, 403, "Forbidden") }
        guard let data = try? Data(contentsOf: target) else { return sendStatus(client, 404, "Not Found") }

        let mime = mimeType(for: (target.pathExtension as NSString).lowercased)
        let header = "HTTP/1.1 200 OK\r\nContent-Type: \(mime)\r\nContent-Length: \(data.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
        _ = header.withCString { send(client, $0, strlen($0), 0) }
        if method != "HEAD" {
            data.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                var sent = 0
                while sent < data.count {
                    let s = send(client, base.advanced(by: sent), data.count - sent, 0)
                    if s <= 0 { break }
                    sent += s
                }
            }
        }
    }

    private func sendStatus(_ client: Int32, _ code: Int32, _ text: String) {
        let s = "HTTP/1.1 \(code) \(text)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        _ = s.withCString { send(client, $0, strlen($0), 0) }
    }

    private func mimeType(for ext: String) -> String {
        switch ext {
        case "html", "htm": return "text/html; charset=utf-8"
        case "js", "mjs": return "application/javascript; charset=utf-8"
        case "wasm": return "application/wasm"
        case "css": return "text/css; charset=utf-8"
        case "json": return "application/json; charset=utf-8"
        case "png": return "image/png"
        case "svg": return "image/svg+xml"
        case "lua", "txt": return "text/plain; charset=utf-8"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - 主视图控制器
final class ViewController: NSViewController, WKNavigationDelegate {
    private var webView: WKWebView!
    private var splash: NSView!
    private var splashStart: Date!
    private var dismissed = false
    private static let minMs: Double = 1200
    private static let timeoutMs: Double = 6000

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(hex: 0x0B0B0D).cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        splashStart = Date()

        // WebView
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.setValue(false, forKey: "drawsBackground")
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // 开屏
        buildSplash()

        // 启动本地服务并加载
        let site = Bundle.main.resourceURL!.appendingPathComponent("site")
        let server = LocalHTTPServer(root: site)
        server.start()
        objc_setAssociatedObject(self, &AssociatedKeys.server, server, .OBJC_ASSOCIATION_RETAIN)
        log("server started port=\(server.port)")
        if let url = URL(string: "http://127.0.0.1:\(server.port)/index.html") {
            webView.load(URLRequest(url: url))
            log("webView load: \(url)")
        }

        // 超时兜底
        DispatchQueue.main.asyncAfter(deadline: .now() + ViewController.timeoutMs / 1000) { [weak self] in
            self?.dismissSplash()
        }
    }

    private func buildSplash() {
        splash = NSView()
        splash.wantsLayer = true
        splash.layer?.backgroundColor = NSColor(hex: 0x0B0B0D).cgColor
        splash.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splash)
        NSLayoutConstraint.activate([
            splash.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splash.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splash.topAnchor.constraint(equalTo: view.topAnchor),
            splash.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let title = NSTextField(labelWithString: "AnonUsAl")
        title.font = NSFont.systemFont(ofSize: 30, weight: .semibold)
        title.textColor = NSColor(hex: 0xFF6A2B)
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false
        splash.addSubview(title)

        let credits = NSTextField(labelWithString: "AnonUsAl · 屿99捏")
        credits.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        credits.textColor = NSColor(hex: 0xEDEAE3)
        credits.alignment = .center
        credits.translatesAutoresizingMaskIntoConstraints = false
        splash.addSubview(credits)

        let qq = NSTextField(labelWithString: "QQ 3353739856")
        qq.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        qq.textColor = NSColor(hex: 0xA7A49C)
        qq.alignment = .center
        qq.translatesAutoresizingMaskIntoConstraints = false
        splash.addSubview(qq)

        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: splash.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: splash.centerYAnchor, constant: -30),
            credits.centerXAnchor.constraint(equalTo: splash.centerXAnchor),
            credits.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 14),
            qq.centerXAnchor.constraint(equalTo: splash.centerXAnchor),
            qq.topAnchor.constraint(equalTo: credits.bottomAnchor, constant: 16),
        ])
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        log("page finished")
        let elapsed = Date().timeIntervalSince(splashStart) * 1000
        let remain = max(0, ViewController.minMs - elapsed) / 1000
        DispatchQueue.main.asyncAfter(deadline: .now() + remain) { [weak self] in
            self?.dismissSplash()
        }
    }

    private func dismissSplash() {
        guard !dismissed, let splash = splash else { return }
        dismissed = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            splash.animator().alphaValue = 0
        }) { [weak self] in
            self?.splash.removeFromSuperview()
            self?.splash = nil
        }
    }
}

private struct AssociatedKeys { static var server = "server" }

// MARK: - AppDelegate
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("didFinishLaunching enter")
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        w.title = "fx-991CN X 科学计算器"
        w.backgroundColor = NSColor(hex: 0x0B0B0D)
        w.contentViewController = ViewController()
        w.setContentSize(NSSize(width: 900, height: 760))
        w.center()
        w.makeKeyAndOrderFront(nil)
        window = w
        NSApp.activate(ignoringOtherApps: true)
        log("window shown: \(w.frame.size) content=\(w.contentView?.frame.size ?? .zero)")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

// MARK: - NSColor 十六进制便利构造
extension NSColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(calibratedRed: r, green: g, blue: b, alpha: 1)
    }
}

// 使用标准 @main 入口
@main
struct Casio991App {
    // 关键：NSApplication.delegate 是 weak，必须用静态强引用持有，
    // 否则 delegate（及其 window）在 main() 返回后立即释放 → 进程在 Dock 但没窗口
    static let delegate = AppDelegate()

    static func main() {
        log("app main enter")
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        log("delegate set, run")
        app.run()
        log("app run exited")
    }
}

// 启动日志（便于排查双击无窗口问题）
func log(_ msg: String) {
    let line = "\(Date()) \(msg)\n"
    if let handle = FileHandle(forWritingAtPath: "/tmp/casio991_launch.log") {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        try? line.write(toFile: "/tmp/casio991_launch.log", atomically: true, encoding: .utf8)
    }
}
