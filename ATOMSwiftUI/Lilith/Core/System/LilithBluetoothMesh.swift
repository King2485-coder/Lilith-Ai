import Foundation
import CoreBluetooth
import Combine

/// Manages Bluetooth mesh discovery and advertising for local device networking.
final class LilithBluetoothMesh: NSObject, ObservableObject {

    // MARK: - Published state

    @Published private(set) var isScanning = false
    @Published private(set) var discoveredDevices: [CBPeripheral] = []

    // MARK: - Private

    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?

    private static let meshServiceUUID = CBUUID(string: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")

    // MARK: - Public API

    /// Starts Bluetooth scanning and advertising for the mesh network.
    func startMesh() {
        centralManager = CBCentralManager(delegate: self, queue: .main)
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
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
        guard central.state == .poweredOn else {
            isScanning = false
            return
        }
        central.scanForPeripherals(
            withServices: [LilithBluetoothMesh.meshServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        isScanning = true
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) else { return }
        discoveredDevices.append(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        discoveredDevices.removeAll { $0.identifier == peripheral.identifier }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension LilithBluetoothMesh: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else { return }
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [LilithBluetoothMesh.meshServiceUUID],
            CBAdvertisementDataLocalNameKey: "LilithMesh"
        ])
    }
}
