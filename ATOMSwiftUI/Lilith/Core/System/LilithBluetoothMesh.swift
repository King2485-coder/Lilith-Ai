import Foundation
import CoreBluetooth
import Combine

/// Manages Bluetooth mesh discovery and advertising for local device networking.
final class LilithBluetoothMesh: NSObject, ObservableObject {

    // MARK: - Published state

    @Published private(set) var isScanning = false
    @Published private(set) var isConnected = false
    @Published private(set) var discoveredDevices: [CBPeripheral] = []

    // MARK: - Private

    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var connectedPeripheral: CBPeripheral?

    private static let meshServiceUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")

    // MARK: - Public API

    /// Starts Bluetooth scanning and advertising for the mesh network.
    func startMesh() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: .main)
        }
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
        }

        if centralManager?.state == .poweredOn {
            startScanning()
        }

        if peripheralManager?.state == .poweredOn {
            startAdvertising()
        }
    }

    private func startScanning() {
        centralManager?.scanForPeripherals(
            withServices: [LilithBluetoothMesh.meshServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        isScanning = true
    }

    private func startAdvertising() {
        peripheralManager?.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [LilithBluetoothMesh.meshServiceUUID],
            CBAdvertisementDataLocalNameKey: "LilithMesh"
        ])
    }

    /// Connects to a discovered peripheral.
    func connect(to peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        centralManager?.connect(peripheral, options: nil)
    }

    /// Stops all mesh activity and clears discovered devices.
    func stopMesh() {
        centralManager?.stopScan()
        peripheralManager?.stopAdvertising()
        isScanning = false
        discoveredDevices = []
    }
}

// MARK: - CBCentralManagerDelegate

extension LilithBluetoothMesh: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        } else {
            isScanning = false
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) else { return }
        print("🔥 Found device: \(peripheral.name ?? "Unknown")")
        discoveredDevices.append(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to \(peripheral.name ?? "Unknown")")
        isConnected = true
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        discoveredDevices.removeAll { $0.identifier == peripheral.identifier }
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
            isConnected = false
        }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension LilithBluetoothMesh: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            startAdvertising()
        }
    }
}
