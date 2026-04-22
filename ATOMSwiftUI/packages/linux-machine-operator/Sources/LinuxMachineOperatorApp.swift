import SwiftUI

@main
struct LinuxMachineOperatorApp: App {
    @StateObject private var eventManager = SimpleForegroundLogger.shared
    
    var body: some Scene {
        WindowGroup {
            MachineConnectionView()
        }
    }
}