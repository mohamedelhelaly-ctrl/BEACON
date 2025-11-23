import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';

class PermissionService {
  static final _p2pHost = FlutterP2pHost();
  static final _p2pClient = FlutterP2pClient();

  /// Request all required permissions for P2P operations
  static Future<bool> requestAllPermissions() async {
    print('[PermissionService] Requesting all permissions...');

    // 1) Request Storage permissions (for file transfer)
    if (!await _p2pHost.checkStoragePermission()) {
      print('[PermissionService] Requesting storage permission...');
      await _p2pHost.askStoragePermission();
    }

    // 2) Request P2P permissions (Wi-Fi Direct)
    if (!await _p2pHost.checkP2pPermissions()) {
      print('[PermissionService] Requesting P2P permissions...');
      await _p2pHost.askP2pPermissions();
    }

    // 3) Request Bluetooth permissions (for BLE discovery)
    if (!await _p2pHost.checkBluetoothPermissions()) {
      print('[PermissionService] Requesting Bluetooth permissions...');
      await _p2pHost.askBluetoothPermissions();
    }

    print('[PermissionService] All permissions requested!');
    return true;
  }

  /// Enable required services (WiFi, Location, Bluetooth)
  static Future<void> enableAllServices() async {
    print('[PermissionService] Enabling services...');

    // Enable WiFi
    if (!await _p2pHost.checkWifiEnabled()) {
      print('[PermissionService] Enabling WiFi...');
      await _p2pHost.enableWifiServices();
    }

    // Enable Location (required for Wi-Fi scanning on many Android versions)
    if (!await _p2pHost.checkLocationEnabled()) {
      print('[PermissionService] Enabling location...');
      await _p2pHost.enableLocationServices();
    }

    // Enable Bluetooth (for BLE discovery)
    if (!await _p2pHost.checkBluetoothEnabled()) {
      print('[PermissionService] Enabling Bluetooth...');
      await _p2pHost.enableBluetoothServices();
    }

    print('[PermissionService] Services enabled!');
  }

  /// Request permissions and enable services before P2P operations
  static Future<bool> prepareForP2P() async {
    try {
      await requestAllPermissions();
      await enableAllServices();
      return true;
    } catch (e) {
      print('[PermissionService] Error preparing for P2P: $e');
      return false;
    }
  }

  /// Dispose resources
  static void dispose() {
    _p2pHost.dispose();
    _p2pClient.dispose();
  }
}
