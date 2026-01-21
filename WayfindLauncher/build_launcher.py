#!/usr/bin/env python3
"""Build the Wayfind Launcher with all assets embedded."""

import base64
import os
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)

def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def read_binary(path):
    with open(path, 'rb') as f:
        return base64.b64encode(f.read()).decode('ascii')

def escape_swift_string(s):
    """Escape a string for use in Swift triple-quoted string."""
    # Replace backslashes first, then handle other escapes
    s = s.replace('\\', '\\\\')
    # Escape triple quotes that would break Swift's multiline strings
    s = s.replace('"""', '\\"\\"\\"')
    return s

def main():
    print("Building Wayfind Launcher...")

    # Read assets
    print("  Reading index.html...")
    index_html = read_file(os.path.join(PROJECT_DIR, 'index.html'))

    print("  Reading logo.png...")
    logo_base64 = read_binary(os.path.join(PROJECT_DIR, 'logo.png'))

    print("  Reading RedRock.otf...")
    font_base64 = read_binary(os.path.join(PROJECT_DIR, 'RedRock.otf'))

    # Modify index.html to use embedded assets
    print("  Embedding assets in HTML...")
    index_html = index_html.replace(
        "src=\"logo.png\"",
        f"src=\"data:image/png;base64,{logo_base64}\""
    )
    index_html = index_html.replace(
        "url('RedRock.otf')",
        f"url('data:font/otf;base64,{font_base64}')"
    )

    # Escape for Swift
    index_html_escaped = escape_swift_string(index_html)

    # Read server.js
    print("  Reading server.js...")
    server_js = read_file(os.path.join(PROJECT_DIR, 'server.js'))
    # Use the simplified version without dotenv
    server_js = '''const http = require('http');
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
'''
    server_js_escaped = escape_swift_string(server_js)

    # Generate Swift code
    print("  Generating Swift code...")
    swift_code = f'''import Cocoa

// MARK: - Configuration
let GITHUB_RAW_BASE = "https://raw.githubusercontent.com/NorthwoodsCommunityChurch/Northwoods-Wayfind/refs/heads/main"
let FILES_TO_SYNC = ["index.html"]

// MARK: - Embedded Files (auto-generated)
let INDEX_HTML = """
{index_html_escaped}
"""

let SERVER_JS = """
{server_js_escaped}
"""

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {{
    var statusItem: NSStatusItem!
    var serverProcess: Process?
    var serverRunning = false
    var projectDir: String = ""
    var lastUpdateCheck: Date?

    override init() {{
        super.init()
        projectDir = getSavedProjectDir()
    }}

    func getSavedProjectDir() -> String {{
        if let saved = UserDefaults.standard.string(forKey: "ProjectDirectory"),
           FileManager.default.fileExists(atPath: saved) {{
            return saved
        }}
        return ""
    }}

    func selectProjectFolder() -> Bool {{
        let panel = NSOpenPanel()
        panel.title = "Select Server Folder"
        panel.message = "Choose where to store the digital signage server files"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"

        if panel.runModal() == .OK, let url = panel.url {{
            projectDir = url.path
            UserDefaults.standard.set(projectDir, forKey: "ProjectDirectory")
            return true
        }}
        return false
    }}

    func setupProjectFolder() -> Bool {{
        // Create server.js
        let serverPath = (projectDir as NSString).appendingPathComponent("server.js")
        do {{
            try SERVER_JS.write(toFile: serverPath, atomically: true, encoding: .utf8)
        }} catch {{
            showAlert(title: "Error", message: "Failed to create server.js: \\(error.localizedDescription)")
            return false
        }}

        // Create index.html
        let indexPath = (projectDir as NSString).appendingPathComponent("index.html")
        do {{
            try INDEX_HTML.write(toFile: indexPath, atomically: true, encoding: .utf8)
        }} catch {{
            showAlert(title: "Error", message: "Failed to create index.html: \\(error.localizedDescription)")
            return false
        }}

        return true
    }}

    func promptForApiKey() -> Bool {{
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

        if alert.runModal() == .alertFirstButtonReturn {{
            let key = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {{
                saveApiKey(key)
                return true
            }}
        }}
        return false
    }}

    func applicationDidFinishLaunching(_ notification: Notification) {{
        setupMenuBar()

        // First launch - select folder
        if projectDir.isEmpty {{
            let welcome = NSAlert()
            welcome.messageText = "Welcome to Northwoods Wayfind"
            welcome.informativeText = "Select a folder to store the server files. This can be any folder on your Mac."
            welcome.addButton(withTitle: "Choose Folder")
            welcome.addButton(withTitle: "Quit")

            if welcome.runModal() != .alertFirstButtonReturn || !selectProjectFolder() {{
                NSApplication.shared.terminate(nil)
                return
            }}
        }}

        // Setup project files
        if !setupProjectFolder() {{
            return
        }}

        // Check for API key
        if getApiKey().isEmpty {{
            if !promptForApiKey() {{
                updateMenu()
                return
            }}
        }}

        // Check Node.js and start
        if checkNodeJS() {{
            startServer()
        }}
    }}

    func applicationWillTerminate(_ notification: Notification) {{
        stopServer()
    }}

    // MARK: - Menu Bar Setup
    func setupMenuBar() {{
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {{
            button.title = "📍"
        }}
        updateMenu()
    }}

    func updateMenu() {{
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

        let copyDebugURL = NSMenuItem(title: "  Copy: localhost:8080?debug=true", action: #selector(copyDebugURL), keyEquivalent: "")
        copyDebugURL.target = self
        menu.addItem(copyDebugURL)

        menu.addItem(NSMenuItem.separator())

        let openDebugItem = NSMenuItem(title: "Open Debug Mode", action: #selector(openDebugMode), keyEquivalent: "d")
        openDebugItem.target = self
        menu.addItem(openDebugItem)

        menu.addItem(NSMenuItem.separator())

        // Update section
        let updateItem = NSMenuItem(title: "Check for Updates", action: #selector(checkForUpdates), keyEquivalent: "u")
        updateItem.target = self
        menu.addItem(updateItem)

        if let lastCheck = lastUpdateCheck {{
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let timeAgo = formatter.localizedString(for: lastCheck, relativeTo: Date())
            let lastCheckItem = NSMenuItem(title: "  Last checked: \\(timeAgo)", action: nil, keyEquivalent: "")
            lastCheckItem.isEnabled = false
            menu.addItem(lastCheckItem)
        }}

        menu.addItem(NSMenuItem.separator())

        let apiKeyStatus = getApiKey().isEmpty ? "⚠ Not Set" : "✓ Configured"
        let configItem = NSMenuItem(title: "API Key: \\(apiKeyStatus)", action: #selector(configureApiKey), keyEquivalent: "")
        configItem.target = self
        menu.addItem(configItem)

        let folderItem = NSMenuItem(title: "Server Folder...", action: #selector(changeProjectFolder), keyEquivalent: "")
        folderItem.target = self
        menu.addItem(folderItem)

        menu.addItem(NSMenuItem.separator())

        if serverRunning {{
            let restartItem = NSMenuItem(title: "Restart Server", action: #selector(restartServer), keyEquivalent: "r")
            restartItem.target = self
            menu.addItem(restartItem)
        }} else {{
            let startItem = NSMenuItem(title: "Start Server", action: #selector(startServerAction), keyEquivalent: "s")
            startItem.target = self
            menu.addItem(startItem)
        }}

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Stop Server & Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }}

    // MARK: - API Key Management
    func getApiKey() -> String {{
        let envPath = (projectDir as NSString).appendingPathComponent(".env")
        guard let content = try? String(contentsOfFile: envPath, encoding: .utf8) else {{ return "" }}

        for line in content.components(separatedBy: .newlines) {{
            if line.hasPrefix("ESPACE_API_KEY=") {{
                return String(line.dropFirst("ESPACE_API_KEY=".count))
            }}
        }}
        return ""
    }}

    func saveApiKey(_ key: String) {{
        let envPath = (projectDir as NSString).appendingPathComponent(".env")
        var lines: [String] = []
        var found = false

        if let content = try? String(contentsOfFile: envPath, encoding: .utf8) {{
            lines = content.components(separatedBy: .newlines)
            for i in 0..<lines.count {{
                if lines[i].hasPrefix("ESPACE_API_KEY=") {{
                    lines[i] = "ESPACE_API_KEY=\\(key)"
                    found = true
                    break
                }}
            }}
        }}

        if !found {{
            lines.append("ESPACE_API_KEY=\\(key)")
        }}

        while lines.last?.isEmpty == true {{ lines.removeLast() }}

        do {{
            try lines.joined(separator: "\\n").write(toFile: envPath, atomically: true, encoding: .utf8)
        }} catch {{
            showAlert(title: "Error", message: "Failed to save API key: \\(error.localizedDescription)")
        }}
        updateMenu()
    }}

    @objc func configureApiKey() {{
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

        if alert.runModal() == .alertFirstButtonReturn {{
            let key = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {{
                saveApiKey(key)
                showNotification(title: "API Key Saved", body: "Restart server to apply changes")
            }}
        }}
    }}

    // MARK: - Node.js Check
    func checkNodeJS() -> Bool {{
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-l", "-c", "which node"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {{
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {{
                showAlert(
                    title: "Node.js Required",
                    message: "Node.js is required to run the server.\\n\\nInstall from: nodejs.org"
                )
                return false
            }}
        }} catch {{
            showAlert(title: "Error", message: "Failed to check for Node.js")
            return false
        }}
        return true
    }}

    // MARK: - Server Management
    func startServer() {{
        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/bin/bash")
        kill.arguments = ["-c", "lsof -ti:8080 | xargs kill -9 2>/dev/null; exit 0"]
        try? kill.run()
        kill.waitUntilExit()

        var env = ProcessInfo.processInfo.environment
        let envPath = (projectDir as NSString).appendingPathComponent(".env")
        if let content = try? String(contentsOfFile: envPath, encoding: .utf8) {{
            for line in content.components(separatedBy: .newlines) {{
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.hasPrefix("#") && trimmed.contains("=") {{
                    let parts = trimmed.split(separator: "=", maxSplits: 1)
                    if parts.count == 2 {{
                        env[String(parts[0])] = String(parts[1])
                    }}
                }}
            }}
        }}

        serverProcess = Process()
        serverProcess?.executableURL = URL(fileURLWithPath: "/bin/bash")
        serverProcess?.arguments = ["-l", "-c", "cd '\\(projectDir)' && node server.js"]
        serverProcess?.environment = env

        do {{
            try serverProcess?.run()

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {{
                self.serverRunning = self.serverProcess?.isRunning ?? false
                self.updateMenu()

                if !self.serverRunning {{
                    self.showAlert(title: "Server Failed", message: "Failed to start the server.")
                }}
            }}
        }} catch {{
            showAlert(title: "Error", message: "Failed to start server: \\(error)")
        }}
    }}

    func stopServer() {{
        serverProcess?.terminate()
        serverProcess = nil

        let kill = Process()
        kill.executableURL = URL(fileURLWithPath: "/bin/bash")
        kill.arguments = ["-c", "lsof -ti:8080 | xargs kill -9 2>/dev/null; exit 0"]
        try? kill.run()
        kill.waitUntilExit()

        serverRunning = false
        updateMenu()
    }}

    // MARK: - Actions
    @objc func copyAllEventsURL() {{
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("http://localhost:8080", forType: .string)
        showNotification(title: "URL Copied", body: "http://localhost:8080")
    }}

    @objc func copyRoomURL() {{
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("http://localhost:8080?room=", forType: .string)
        showNotification(title: "URL Copied", body: "Add room name to the end")
    }}

    @objc func copyDebugURL() {{
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("http://localhost:8080?debug=true", forType: .string)
        showNotification(title: "URL Copied", body: "Debug mode URL")
    }}

    @objc func openDebugMode() {{
        if let url = URL(string: "http://localhost:8080?debug=true") {{
            NSWorkspace.shared.open(url)
        }}
    }}

    @objc func checkForUpdates() {{
        showNotification(title: "Checking for Updates", body: "Downloading latest files from GitHub...")

        DispatchQueue.global(qos: .userInitiated).async {{
            var updatedCount = 0

            for fileName in FILES_TO_SYNC {{
                let urlString = "\\(GITHUB_RAW_BASE)/\\(fileName)"
                guard let url = URL(string: urlString) else {{ continue }}

                do {{
                    let newContent = try String(contentsOf: url, encoding: .utf8)
                    let localPath = (self.projectDir as NSString).appendingPathComponent(fileName)

                    // Check if file exists and compare
                    let existingContent = try? String(contentsOfFile: localPath, encoding: .utf8)
                    if existingContent != newContent {{
                        try newContent.write(toFile: localPath, atomically: true, encoding: .utf8)
                        updatedCount += 1
                    }}
                }} catch {{
                    print("Failed to sync \\(fileName): \\(error)")
                }}
            }}

            DispatchQueue.main.async {{
                self.lastUpdateCheck = Date()
                self.updateMenu()

                if updatedCount > 0 {{
                    self.showNotification(title: "Updates Applied", body: "Updated \\(updatedCount) file(s). Refreshing browser...")
                    // Open browser with cache-busting parameter to force reload
                    let timestamp = Int(Date().timeIntervalSince1970)
                    if let url = URL(string: "http://localhost:8080?_cb=\\(timestamp)") {{
                        NSWorkspace.shared.open(url)
                    }}
                }} else {{
                    self.showNotification(title: "Already Up to Date", body: "No updates available")
                }}
            }}
        }}
    }}

    @objc func startServerAction() {{
        if projectDir.isEmpty && !selectProjectFolder() {{ return }}
        if !setupProjectFolder() {{ return }}
        if getApiKey().isEmpty && !promptForApiKey() {{ return }}
        if checkNodeJS() {{ startServer() }}
    }}

    @objc func changeProjectFolder() {{
        let wasRunning = serverRunning
        if wasRunning {{ stopServer() }}

        if selectProjectFolder() && setupProjectFolder() {{
            updateMenu()
            if wasRunning {{ startServer() }}
        }}
    }}

    @objc func restartServer() {{
        stopServer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {{
            self.startServer()
        }}
    }}

    @objc func quitApp() {{
        stopServer()
        NSApplication.shared.terminate(nil)
    }}

    // MARK: - Helpers
    func showAlert(title: String, message: String) {{
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }}

    func showNotification(title: String, body: String) {{
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        NSUserNotificationCenter.default.deliver(notification)
    }}
}}

// MARK: - Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
'''

    # Write Swift file
    swift_path = os.path.join(SCRIPT_DIR, 'main.swift')
    print(f"  Writing {swift_path}...")
    with open(swift_path, 'w', encoding='utf-8') as f:
        f.write(swift_code)

    print("  Swift file generated successfully!")
    print(f"  File size: {os.path.getsize(swift_path):,} bytes")

    # Compile
    print("\\nCompiling universal binary...")
    os.chdir(SCRIPT_DIR)

    # ARM64
    print("  Compiling for ARM64...")
    result = subprocess.run([
        'swiftc', '-o', 'WayfindLauncher-arm64', 'main.swift',
        '-framework', 'Cocoa', '-target', 'arm64-apple-macos10.15'
    ], capture_output=True, text=True)
    if result.returncode != 0:
        print(f"ARM64 compile failed: {result.stderr}")
        sys.exit(1)

    # x86_64
    print("  Compiling for x86_64...")
    result = subprocess.run([
        'swiftc', '-o', 'WayfindLauncher-x86_64', 'main.swift',
        '-framework', 'Cocoa', '-target', 'x86_64-apple-macos10.15'
    ], capture_output=True, text=True)
    if result.returncode != 0:
        print(f"x86_64 compile failed: {result.stderr}")
        sys.exit(1)

    # Create universal binary
    print("  Creating universal binary...")
    subprocess.run([
        'lipo', '-create', '-output', 'WayfindLauncher',
        'WayfindLauncher-arm64', 'WayfindLauncher-x86_64'
    ], check=True)

    # Clean up
    os.remove('WayfindLauncher-arm64')
    os.remove('WayfindLauncher-x86_64')

    # Copy to app bundle
    app_binary = os.path.join(PROJECT_DIR, 'Northwoods Wayfind.app', 'Contents', 'MacOS', 'WayfindLauncher')
    print(f"  Copying to app bundle...")
    subprocess.run(['cp', 'WayfindLauncher', app_binary], check=True)

    # Sign
    print("  Signing app bundle...")
    app_path = os.path.join(PROJECT_DIR, 'Northwoods Wayfind.app')
    subprocess.run(['codesign', '--force', '--deep', '--sign', '-', app_path], check=True)

    # Create zip
    print("  Creating zip...")
    os.chdir(PROJECT_DIR)
    zip_name = 'Northwoods-Wayfind-Launcher-v1.0.0.zip'
    if os.path.exists(zip_name):
        os.remove(zip_name)
    subprocess.run(['zip', '-r', zip_name, 'Northwoods Wayfind.app'], check=True)

    print(f"\\n✓ Build complete: {zip_name}")
    print(f"  Size: {os.path.getsize(zip_name):,} bytes")

if __name__ == '__main__':
    main()
