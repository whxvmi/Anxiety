import SwiftUI
import AppKit

@main
struct AnxietyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {}
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var currentPermissionIndex = 0
    private var animationTimer: Timer?
    private var currentRotation: CGFloat = 0
    
    private let permissions = [
        "Accessibility", "AddressBook", "Calendar", "Camera", "Microphone", "Photos",
        "PhotosAdd", "Reminders", "ScreenCapture", "MediaLibrary", "SpeechRecognition",
        "Motion", "SystemPolicyDesktopFolder", "SystemPolicyDocumentsFolder",
        "SystemPolicyDownloadsFolder", "SystemPolicyNetworkVolumes",
        "SystemPolicyRemovableVolumes", "SystemPolicyAllFiles", "AppleEvents",
        "SystemPolicyAppBundles", "FileProviderDomain", "FileProviderPresence",
        "ShareKit", "Willow", "ContactsFull", "ContactsLimited",
        "WebBrowserPublicKeyCredential", "UserTracking", "FocusStatus",
        "PostEvent", "ListenEvent", "DeveloperTool"
    ]
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.2.circlepath", accessibilityDescription: "Anxiety Reset")
            button.action = #selector(showConfirmation)
            button.target = self
            button.toolTip = "Anxiety – Reset All Permissions"
        }
    }
    
    @objc private func showConfirmation() {
        let alert = NSAlert()
        alert.messageText = "Reset all permissions?"
        alert.informativeText = "This will reset all macOS privacy permissions for all apps.\nThe process will run in the background."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            startResetProcess()
        }
    }
    
    private func startResetProcess() {
        currentPermissionIndex = 0
        print("\n🔄 Starting permission reset...")
        print("Total categories: \(permissions.count)\n")
        
        startIconAnimation()
        resetNextPermission()
    }
    
    private func startIconAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let button = self.statusItem.button else { return }
            self.currentRotation = (self.currentRotation + 10).truncatingRemainder(dividingBy: 360)
            if let image = NSImage(systemSymbolName: "arrow.2.circlepath", accessibilityDescription: "Resetting") {
                button.image = self.rotatedImage(image, degrees: self.currentRotation)
            }
        }
    }
    
    private func stopIconAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        currentRotation = 0
        statusItem.button?.image = NSImage(systemSymbolName: "arrow.2.circlepath", accessibilityDescription: "Anxiety Reset")
    }
    
    private func rotatedImage(_ image: NSImage, degrees: CGFloat) -> NSImage {
        let rotated = NSImage(size: image.size)
        rotated.lockFocus()
        let transform = NSAffineTransform()
        transform.translateX(by: image.size.width / 2, yBy: image.size.height / 2)
        transform.rotate(byDegrees: degrees)
        transform.translateX(by: -image.size.width / 2, yBy: -image.size.height / 2)
        transform.concat()
        image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1.0)
        rotated.unlockFocus()
        return rotated
    }
    
    private func resetNextPermission() {
        guard currentPermissionIndex < permissions.count else {
            finishReset()
            return
        }
        
        let permission = permissions[currentPermissionIndex]
        
        DispatchQueue.main.async {
            self.statusItem.button?.toolTip = "Resetting: \(permission) (\(self.currentPermissionIndex + 1)/\(self.permissions.count))"
        }
        
        print("----------------------------------------")
        print("[\(currentPermissionIndex + 1)/\(permissions.count)] Resetting: \(permission)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", permission]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let error = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                if process.terminationStatus == 0 {
                    print("✅ Success: \(permission)")
                    if !output.isEmpty { print("   \(output)") }
                } else {
                    print("❌ Error: \(permission) (Exit code: \(process.terminationStatus))")
                    if !error.isEmpty { print("   \(error)") }
                }
            } catch {
                print("❌ Exception: \(permission) – \(error.localizedDescription)")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.currentPermissionIndex += 1
                self.resetNextPermission()
            }
        }
    }
    
    private func finishReset() {
        print("========================================")
        print("✨ All permissions have been reset.")
        print("Total: \(permissions.count) categories")
        print("========================================")
        
        stopIconAnimation()
        statusItem.button?.toolTip = "Anxiety – Reset All Permissions"
        
        let alert = NSAlert()
        alert.messageText = "Reset Complete"
        alert.informativeText = "All \(permissions.count) permission categories have been reset.\nApps will ask for permissions again when needed."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
