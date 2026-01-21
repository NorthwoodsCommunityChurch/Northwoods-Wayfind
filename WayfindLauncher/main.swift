import Cocoa

// MARK: - Configuration
let GITHUB_RAW_BASE = "https://raw.githubusercontent.com/NorthwoodsCommunityChurch/Northwoods-Wayfind/main"
let FILES_TO_SYNC = ["index.html", "logo.png", "RedRock.otf"]
let UPDATE_CHECK_INTERVAL: TimeInterval = 3600 // Check every hour

// Embedded server.js (small, rarely changes)
let SERVER_JS = """
const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

const PORT = 8080;
const ESPACE_API_KEY = process.env.ESPACE_API_KEY;
const ESPACE_DISPLAY_ID = process.env.ESPACE_DISPLAY_ID || '7';

if (!ESPACE_API_KEY) {
    console.error('ERROR: ESPACE_API_KEY not set');
    process.exit(1);
}

const API_URL = `https://app.espace.cool/FacilieSpace/DigitalSignage/GetDisplayEvents/${ESPACE_DISPLAY_ID}?key=${ESPACE_API_KEY}`;

const mimeTypes = {
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'application/javascript',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.otf': 'font/otf',
    '.ttf': 'font/ttf'
};

http.createServer((req, res) => {
    const parsedUrl = new URL(req.url, `http://localhost:${PORT}`);
    const pathname = parsedUrl.pathname;

    if (pathname === '/api/events') {
        https.get(API_URL, (apiRes) => {
            let data = '';
            apiRes.on('data', chunk => data += chunk);
            apiRes.on('end', () => {
                res.writeHead(200, {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                });
                res.end(data);
            });
        }).on('error', (err) => {
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Failed to fetch events' }));
        });
        return;
    }

    let filePath = pathname === '/' ? '/index.html' : pathname;
    filePath = path.join(__dirname, filePath);
    const ext = path.extname(filePath);
    const contentType = mimeTypes[ext] || 'application/octet-stream';

    fs.readFile(filePath, (err, content) => {
        if (err) {
            res.writeHead(err.code === 'ENOENT' ? 404 : 500);
            res.end(err.code === 'ENOENT' ? 'Not found' : 'Error');
        } else {
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(content);
        }
    });
}).listen(PORT, () => console.log(`Server running on http://localhost:${PORT}`));
"""

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var serverProcess: Process?
    var serverRunning = false
    var projectDir: String = ""
    var updateTimer: Timer?
    var lastUpdateCheck: Date?

    override init() {
        super.init()
        projectDir = getSavedProjectDir()
    }

    func getSavedProjectDir() -> String {
        if let saved = UserDefaults.standard.string(forKey: "ProjectDirectory"),
           FileManager.default.fileExists(atPath: saved) {
            return saved
        }
        return ""
    }

    func selectProjectFolder() -> Bool {
        let panel = NSOpenPanel()
        panel.title = "Select Server Folder"
        panel.message = "Choose where to store the digital signage server files"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"

        if panel.runModal() == .OK, let url = panel.url {
            projectDir = url.path
            UserDefaults.standard.set(projectDir, forKey: "ProjectDirectory")
            return true
        }
        return false
    }

    // MARK: - GitHub Sync
    func downloadFile(filename: String, completion: @escaping (Bool) -> Void) {
        let urlString = "\(GITHUB_RAW_BASE)/\(filename)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            let filePath = (self.projectDir as NSString).appendingPathComponent(filename)
            do {
                try data.write(to: URL(fileURLWithPath: filePath))
                DispatchQueue.main.async { completion(true) }
            } catch {
                DispatchQueue.main.async { completion(false) }
            }
        }
        task.resume()
    }

    func syncFilesFromGitHub(completion: @escaping (Bool, Int) -> Void) {
        var successCount = 0
        var completedCount = 0
        let totalFiles = FILES_TO_SYNC.count

        for filename in FILES_TO_SYNC {
            downloadFile(filename: filename) { success in
                completedCount += 1
                if success { successCount += 1 }

                if completedCount == totalFiles {
                    completion(successCount > 0, successCount)
                }
            }
        }
    }

    func setupProjectFolder(completion: @escaping (Bool) -> Void) {
        // Create server.js (embedded, doesn't need GitHub)
        let serverPath = (projectDir as NSString).appendingPathComponent("server.js")
        do {
            try SERVER_JS.write(toFile: serverPath, atomically: true, encoding: .utf8)
        } catch {
            showAlert(title: "Error", message: "Failed to create server.js: \(error.localizedDescription)")
            completion(false)
            return
        }

        // Download display files from GitHub
        syncFilesFromGitHub { success, count in
            if success {
                self.lastUpdateCheck = Date()
                completion(true)
            } else {
                // If GitHub fails, create a minimal placeholder
                let indexPath = (self.projectDir as NSString).appendingPathComponent("index.html")
                if !FileManager.default.fileExists(atPath: indexPath) {
                    let placeholder = """
                    <!DOCTYPE html>
                    <html>
                    <head><title>Northwoods Wayfind</title>
                    <style>body{font-family:system-ui;background:#002855;color:white;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;text-align:center;}</style>
                    </head>
                    <body><div><h1>Northwoods Wayfind</h1><p>Could not download display files from GitHub.<br>Check your internet connection and restart.</p></div></body>
                    </html>
                    """
                    try? placeholder.write(toFile: indexPath, atomically: true, encoding: .utf8)
                }
                completion(true) // Still allow server to start
            }
        }
    }

    @objc func checkForUpdates() {
        syncFilesFromGitHub { success, count in
            if success {
                self.lastUpdateCheck = Date()
                self.showNotification(title: "Updates Downloaded", body: "\(count) file(s) updated from GitHub")
                self.updateMenu()
            } else {
                self.showNotification(title: "Update Check Failed", body: "Could not connect to GitHub")
            }
        }
    }

    func startUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: UPDATE_CHECK_INTERVAL, repeats: true) { _ in
            self.syncFilesFromGitHub { success, _ in
                if success {
                    self.lastUpdateCheck = Date()
                    DispatchQueue.main.async { self.updateMenu() }
                }
            }
        }
    }

    func promptForApiKey() -> Bool {
        let alert = NSAlert()
        alert.messageText = "eSpace API Key Required"
        alert.informativeText = "Enter your eSpace API key to connect to the event system:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save & Start")
        alert.addButton(withTitle: "Cancel")

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 350, height: 24))
        inputField.placeholderString = "Enter your API key..."
        alert.accessoryView = inputField
        alert.window.initialFirstResponder = inputField

        if alert.runModal() == .alertFirstButtonReturn {
            let key = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                saveApiKey(key)
                return true
            }
        }
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

        // First launch - select folder
        if projectDir.isEmpty {
            let welcome = NSAlert()
            welcome.messageText = "Welcome to Northwoods Wayfind"
            welcome.informativeText = "Select a folder to store the server files. The display will be downloaded from GitHub automatically."
            welcome.addButton(withTitle: "Choose Folder")
            welcome.addButton(withTitle: "Quit")

            if welcome.runModal() != .alertFirstButtonReturn || !selectProjectFolder() {
                NSApplication.shared.terminate(nil)
                return
            }
        }

        // Setup project files (downloads from GitHub)
        setupProjectFolder { success in
            if !success { return }

            // Check for API key
            if self.getApiKey().isEmpty {
                if !self.promptForApiKey() {
                    self.updateMenu()
                    return
                }
            }

            // Check Node.js and start
            if self.checkNodeJS() {
                self.startServer()
                self.startUpdateTimer()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateTimer?.invalidate()
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

        let statusText = serverRunning ? "✓ Server Running" : "✗ Server Stopped"
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

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

        // Update section
        let updateItem = NSMenuItem(title: "Check for Updates", action: #selector(checkForUpdates), keyEquivalent: "u")
        updateItem.target = self
        menu.addItem(updateItem)

        if let lastCheck = lastUpdateCheck {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let timeAgo = formatter.localizedString(for: lastCheck, relativeTo: Date())
            let lastCheckItem = NSMenuItem(title: "  Last checked: \(timeAgo)", action: nil, keyEquivalent: "")
            lastCheckItem.isEnabled = false
            menu.addItem(lastCheckItem)
        }

        menu.addItem(NSMenuItem.separator())

        let apiKeyStatus = getApiKey().isEmpty ? "⚠ Not Set" : "✓ Configured"
        let configItem = NSMenuItem(title: "API Key: \(apiKeyStatus)", action: #selector(configureApiKey), keyEquivalent: "")
        configItem.target = self
        menu.addItem(configItem)

        let folderItem = NSMenuItem(title: "Server Folder...", action: #selector(changeProjectFolder), keyEquivalent: "")
        folderItem.target = self
        menu.addItem(folderItem)

        menu.addItem(NSMenuItem.separator())

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

        let quitItem = NSMenuItem(title: "Stop Server & Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    // MARK: - API Key Management
    func getApiKey() -> String {
        let envPath = (projectDir as NSString).appendingPathComponent(".env")
        guard let content = try? String(contentsOfFile: envPath, encoding: .utf8) else { return "" }

        for line in content.components(separatedBy: .newlines) {
            if line.hasPrefix("ESPACE_API_KEY=") {
                return String(line.dropFirst("ESPACE_API_KEY=".count))
            }
        }
        return ""
    }

    func saveApiKey(_ key: String) {
        let envPath = (projectDir as NSString).appendingPathComponent(".env")
        var lines: [String] = []
        var found = false

        if let content = try? String(contentsOfFile: envPath, encoding: .utf8) {
            lines = content.components(separatedBy: .newlines)
            for i in 0..<lines.count {
                if lines[i].hasPrefix("ESPACE_API_KEY=") {
                    lines[i] = "ESPACE_API_KEY=\(key)"
                    found = true
                    break
                }
            }
        }

        if !found {
            lines.append("ESPACE_API_KEY=\(key)")
        }

        while lines.last?.isEmpty == true { lines.removeLast() }

        do {
            try lines.joined(separator: "\n").write(toFile: envPath, atomically: true, encoding: .utf8)
        } catch {
            showAlert(title: "Error", message: "Failed to save API key: \(error.localizedDescription)")
        }
        updateMenu()
    }

    @objc func configureApiKey() {
        let alert = NSAlert()
        alert.messageText = "eSpace API Key"
        alert.informativeText = "Enter your eSpace API key:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 350, height: 24))
        inputField.stringValue = getApiKey()
        inputField.placeholderString = "Enter API key..."
        alert.accessoryView = inputField
        alert.window.initialFirstResponder = inputField

        if alert.runModal() == .alertFirstButtonReturn {
            let key = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                saveApiKey(key)
                showNotification(title: "API Key Saved", body: "Restart server to apply changes")
            }
        }
    }

    // MARK: - Node.js Check
    func checkNodeJS() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-l", "-c", "which node"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                showAlert(
                    title: "Node.js Required",
                    message: "Node.js is required to run the server.\n\nInstall from: nodejs.org"
                )
                return false
            }
        } catch {
            showAlert(title: "Error", message: "Failed to check for Node.js")
            return false
        }
        return true
    }

    // MARK: - Server Management
    func startServer() {
        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/bin/bash")
        kill.arguments = ["-c", "lsof -ti:8080 | xargs kill -9 2>/dev/null; exit 0"]
        try? kill.run()
        kill.waitUntilExit()

        var env = ProcessInfo.processInfo.environment
        let envPath = (projectDir as NSString).appendingPathComponent(".env")
        if let content = try? String(contentsOfFile: envPath, encoding: .utf8) {
            for line in content.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.hasPrefix("#") && trimmed.contains("=") {
                    let parts = trimmed.split(separator: "=", maxSplits: 1)
                    if parts.count == 2 {
                        env[String(parts[0])] = String(parts[1])
                    }
                }
            }
        }

        serverProcess = Process()
        serverProcess?.executableURL = URL(fileURLWithPath: "/bin/bash")
        serverProcess?.arguments = ["-l", "-c", "cd '\(projectDir)' && node server.js"]
        serverProcess?.environment = env

        do {
            try serverProcess?.run()

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.serverRunning = self.serverProcess?.isRunning ?? false
                self.updateMenu()

                if !self.serverRunning {
                    self.showAlert(title: "Server Failed", message: "Failed to start the server.")
                }
            }
        } catch {
            showAlert(title: "Error", message: "Failed to start server: \(error)")
        }
    }

    func stopServer() {
        serverProcess?.terminate()
        serverProcess = nil

        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/bin/bash")
        kill.arguments = ["-c", "lsof -ti:8080 | xargs kill -9 2>/dev/null; exit 0"]
        try? kill.run()
        kill.waitUntilExit()

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
        if projectDir.isEmpty && !selectProjectFolder() { return }

        setupProjectFolder { success in
            if !success { return }
            if self.getApiKey().isEmpty && !self.promptForApiKey() { return }
            if self.checkNodeJS() {
                self.startServer()
                self.startUpdateTimer()
            }
        }
    }

    @objc func changeProjectFolder() {
        let wasRunning = serverRunning
        if wasRunning { stopServer() }

        if selectProjectFolder() {
            setupProjectFolder { success in
                if success {
                    self.updateMenu()
                    if wasRunning { self.startServer() }
                }
            }
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
app.setActivationPolicy(.accessory)
app.run()
