import Cocoa

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var serverProcess: Process?
    var serverRunning = false
    let projectDir: String

    override init() {
        // Get the project directory (parent of the .app bundle)
        let appPath = Bundle.main.bundlePath
        projectDir = (appPath as NSString).deletingLastPathComponent
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

        // Check prerequisites and start server
        if checkPrerequisites() {
            startServer()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopServer()
    }

    // MARK: - Menu Bar Setup
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "📍"
        }

        updateMenu()
    }

    func updateMenu() {
        let menu = NSMenu()

        // Status
        let statusText = serverRunning ? "✓ Server Running" : "✗ Server Stopped"
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // URLs section
        let urlHeader = NSMenuItem(title: "OBS Browser Source URLs:", action: nil, keyEquivalent: "")
        urlHeader.isEnabled = false
        menu.addItem(urlHeader)

        let copyAllURL = NSMenuItem(title: "  Copy: localhost:8080", action: #selector(copyAllEventsURL), keyEquivalent: "")
        copyAllURL.target = self
        menu.addItem(copyAllURL)

        let copyRoomURL = NSMenuItem(title: "  Copy: localhost:8080?room=", action: #selector(copyRoomURL), keyEquivalent: "")
        copyRoomURL.target = self
        menu.addItem(copyRoomURL)

        menu.addItem(NSMenuItem.separator())

        // Server controls
        if serverRunning {
            let restartItem = NSMenuItem(title: "Restart Server", action: #selector(restartServer), keyEquivalent: "r")
            restartItem.target = self
            menu.addItem(restartItem)
        } else {
            let startItem = NSMenuItem(title: "Start Server", action: #selector(startServerAction), keyEquivalent: "s")
            startItem.target = self
            menu.addItem(startItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Stop Server & Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    // MARK: - Prerequisites Check
    func checkPrerequisites() -> Bool {
        // Check for .env file
        let envPath = (projectDir as NSString).appendingPathComponent(".env")
        if !FileManager.default.fileExists(atPath: envPath) {
            showAlert(
                title: "Configuration Missing",
                message: "Please create a .env file in:\n\(projectDir)\n\nWith contents:\nESPACE_API_KEY=your-api-key"
            )
            return false
        }

        // Check for API key in .env
        if let envContents = try? String(contentsOfFile: envPath, encoding: .utf8) {
            if !envContents.contains("ESPACE_API_KEY=") || envContents.contains("ESPACE_API_KEY=\n") || envContents.contains("ESPACE_API_KEY=$") {
                showAlert(
                    title: "API Key Missing",
                    message: "ESPACE_API_KEY not found in .env file.\n\nPlease add:\nESPACE_API_KEY=your-api-key"
                )
                return false
            }
        }

        // Check for Node.js
        let nodeCheck = Process()
        nodeCheck.executableURL = URL(fileURLWithPath: "/bin/bash")
        nodeCheck.arguments = ["-c", "which node"]

        let pipe = Pipe()
        nodeCheck.standardOutput = pipe
        nodeCheck.standardError = pipe

        do {
            try nodeCheck.run()
            nodeCheck.waitUntilExit()

            if nodeCheck.terminationStatus != 0 {
                showAlert(
                    title: "Node.js Not Found",
                    message: "Node.js is required to run the server.\n\nPlease install from nodejs.org"
                )
                return false
            }
        } catch {
            showAlert(title: "Error", message: "Failed to check for Node.js: \(error)")
            return false
        }

        return true
    }

    // MARK: - Server Management
    func startServer() {
        // Kill any existing server on port 8080
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        killProcess.arguments = ["-c", "lsof -ti:8080 | xargs kill -9 2>/dev/null; exit 0"]
        try? killProcess.run()
        killProcess.waitUntilExit()

        // Load environment variables
        var environment = ProcessInfo.processInfo.environment
        let envPath = (projectDir as NSString).appendingPathComponent(".env")
        if let envContents = try? String(contentsOfFile: envPath, encoding: .utf8) {
            for line in envContents.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.hasPrefix("#") && trimmed.contains("=") {
                    let parts = trimmed.split(separator: "=", maxSplits: 1)
                    if parts.count == 2 {
                        environment[String(parts[0])] = String(parts[1])
                    }
                }
            }
        }

        // Start server
        serverProcess = Process()
        serverProcess?.executableURL = URL(fileURLWithPath: "/bin/bash")
        serverProcess?.arguments = ["-c", "cd '\(projectDir)' && node server.js"]
        serverProcess?.environment = environment

        do {
            try serverProcess?.run()

            // Wait a moment and check if it's running
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.serverRunning = self.serverProcess?.isRunning ?? false
                self.updateMenu()

                if !self.serverRunning {
                    self.showAlert(
                        title: "Server Failed",
                        message: "Failed to start the server.\n\nCheck that server.js exists."
                    )
                }
            }
        } catch {
            showAlert(title: "Error", message: "Failed to start server: \(error)")
        }
    }

    func stopServer() {
        serverProcess?.terminate()
        serverProcess = nil

        // Also kill anything on port 8080
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        killProcess.arguments = ["-c", "lsof -ti:8080 | xargs kill -9 2>/dev/null; exit 0"]
        try? killProcess.run()
        killProcess.waitUntilExit()

        serverRunning = false
        updateMenu()
    }

    // MARK: - Actions
    @objc func copyAllEventsURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("http://localhost:8080", forType: .string)
        showNotification(title: "URL Copied", body: "http://localhost:8080")
    }

    @objc func copyRoomURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("http://localhost:8080?room=", forType: .string)
        showNotification(title: "URL Copied", body: "Add room name to the end")
    }

    @objc func startServerAction() {
        if checkPrerequisites() {
            startServer()
        }
    }

    @objc func restartServer() {
        stopServer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.startServer()
        }
    }

    @objc func quitApp() {
        stopServer()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Helpers
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        NSUserNotificationCenter.default.deliver(notification)
    }
}

// MARK: - Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // Menu bar only, no dock icon
app.run()
