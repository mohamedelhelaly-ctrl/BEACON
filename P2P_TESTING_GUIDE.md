# P2P WiFi Direct Testing Guide for BEACON

## Overview
Your BEACON app is now configured to use **flutter_p2p_connection v3.0.3**, which implements WiFi Direct P2P communication between two Android phones. The app supports two modes:
- **Host Mode**: One device creates a WiFi Direct hotspot group
- **Client Mode**: Other devices discover and connect to the host

---

## Prerequisites

### Device Requirements
- **2 Android phones** (Android 8.0 / API 26 or higher recommended)
- Both devices must support WiFi Direct
- Bluetooth enabled on both devices
- WiFi enabled (not necessarily connected to internet)

### Software Requirements
- Flutter SDK installed
- Android SDK tools
- ADB (Android Debug Bridge) for debugging

---

## Key Changes Made

### 1. **pubspec.yaml**
- Updated `flutter_p2p_connection` from `^1.0.3` to `^3.0.3`
- Moved from `dev_dependencies` to `dependencies`

### 2. **AndroidManifest.xml**
Added complete permissions for WiFi Direct and BLE:
```xml
<!-- WiFi Permissions -->
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />

<!-- Bluetooth Permissions (API 31+) -->
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<!-- Location (required for scanning) -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

<!-- Storage (for file transfer) -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

<!-- Hardware Features -->
<uses-feature android:name="android.hardware.wifi.direct" android:required="true" />
<uses-feature android:name="android.hardware.bluetooth" android:required="true" />
<uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
```

### 3. **Services Refactored**

#### **p2p_service.dart** - Separated into two classes:
- `P2PHostService`: Uses `FlutterP2pHost` for creating WiFi Direct groups
- `P2PClientService`: Uses `FlutterP2pClient` for discovering and connecting to hosts

**Key Methods:**
```dart
// Host Mode
await hostService.initialize();
final state = await hostService.createGroup(advertise: true);
Stream<HotspotHostState> hotspotState = hostService.streamHotspotState();
Stream<List<P2pClientInfo>> connectedClients = hostService.streamClientList();

// Client Mode
await clientService.initialize();
await clientService.startScan((devices) {
  // Handle discovered BleDiscoveredDevice list
});
await clientService.connectWithDevice(device);
Stream<HotspotClientState> connectionState = clientService.streamHotspotState();
```

#### **permissions_service.dart** - Complete permission handling:
- `requestAllPermissions()`: Requests Storage, P2P, and Bluetooth permissions
- `enableAllServices()`: Enables WiFi, Location, and Bluetooth
- `prepareForP2P()`: Combines both for easy setup

### 4. **UI Updates**

#### **landingPage.dart**
- Now calls `PermissionService.prepareForP2P()` before transitioning to NetworkDashboard
- Handles permission denial with user feedback

#### **networkDashboard.dart**
- Split into Host and Client modes
- **Host Mode**: Shows hotspot info (SSID, PSK, IP), lists connected clients
- **Client Mode**: Shows available hosts via BLE scan, allows connection

---

## Testing Procedure

### Step 1: Prepare Both Devices

On **both phones**:
1. Enable WiFi (doesn't need to be connected to network)
2. Enable Bluetooth
3. Enable Location services
4. Install the BEACON app

### Step 2: First Phone (HOST)

1. **Launch the app** and grant all permissions when prompted
2. **Tap "Start New Communication"**
3. The app will:
   - Request permissions and enable services
   - Create a WiFi Direct group
   - Start BLE advertising with credentials
4. **Note the displayed information:**
   - Network SSID (e.g., "DIRECT_XXXX")
   - Password (PSK)
   - Host IP Address

### Step 3: Second Phone (CLIENT)

1. **Launch the app** and grant all permissions when prompted
2. **Tap "Join Existing Communication"**
3. **Tap the "Scan" button** (floating action button with refresh icon)
4. The app will discover the host via BLE
5. **Tap "Connect"** on the discovered device
6. The connection will establish, and you'll see the host IP address

### Step 4: Verify Connection

**On Host Phone:**
- Navigate to Network Dashboard
- Tap the info icon to see:
  - Mode: Host
  - SSID, PSK, Host IP
- Watch the "Connected Devices" section - should show the client device when connected

**On Client Phone:**
- Navigate to Network Dashboard
- Tap the info icon to see:
  - Mode: Client
  - Host IP address
  - Connected status

### Step 5: Test Messaging (Optional)

On either phone:
1. Navigate to Chat from Network Dashboard
2. Send test messages
3. Messages should appear on the other phone

---

## API Property Names Reference

### HotspotHostState (Host)
```dart
final bool isActive;              // Is hotspot active?
final String? ssid;               // Network name
final String? preSharedKey;       // WiFi password
final String? hostIpAddress;      // Host's IP (usually 192.168.49.1)
final int? failureReason;         // Error code if failed
```

### HotspotClientState (Client)
```dart
final bool isActive;                   // Connected to hotspot?
final String? hostSsid;               // Host's network name
final String? hostGatewayIpAddress;   // Gateway IP (host's IP)
final String? hostIpAddress;          // Client's IP in group
```

### BleDiscoveredDevice
```dart
final String deviceName;              // Device name
final String deviceAddress;           // MAC address
```

---

## Troubleshooting

### Issue: Permissions Not Granted
**Solution:**
- Manually grant permissions in Android Settings > Apps > BEACON > Permissions
- Restart the app

### Issue: Can't Find Host on Client
**Possible Causes:**
1. Bluetooth is not enabled - Enable it in settings
2. Location services disabled - Enable in settings
3. Host not advertising - Kill and restart host app
4. Device distance - Bring devices closer (WiFi Direct BLE range is limited)

**Solution:**
```
1. Verify Bluetooth is ON on both devices
2. Verify Location is ON on both devices
3. Check adb logcat for errors:
   adb logcat | grep "flutter_p2p_connection"
```

### Issue: Connection Times Out
**Solution:**
- Increase timeout duration in `networkDashboard.dart`:
```dart
await _clientService.connectWithDevice(device, 
  timeout: const Duration(seconds: 60)); // Increase from default 30
```

### Issue: App Crashes with "Undefined Method"
**Solution:**
- Run `flutter pub get` to update dependencies
- Clean build cache: `flutter clean && flutter pub get`
- Rebuild: `flutter run`

---

## Debug Logging

Enable detailed logs to see WiFi Direct operations:

```bash
# Terminal 1: Watch logs
adb logcat | grep -E "flutter_p2p_connection|FlutterP2p"

# Terminal 2: Run app
flutter run
```

Common log messages indicate:
- `Host: Group created` - Host hotspot is active
- `Host: BLE advertising started` - Clients can discover now
- `Client: Connecting to BLE device` - Client found and connecting
- `Client: Connected to hotspot` - Connection established

---

## Next Steps

Once P2P connection works:
1. Implement real messaging functionality in `chatPage.dart`
2. Add file transfer capabilities
3. Test on different Android versions
4. Optimize BLE scan performance
5. Add QR code sharing of hotspot credentials

---

## Important Notes

⚠️ **WiFi Direct Considerations:**
- WiFi Direct and regular WiFi can't be used simultaneously
- One device must act as hotspot; others connect as clients
- Limited to ~8 devices per hotspot group
- Works best with Android 8.0+

⚠️ **BLE Discovery:**
- BLE scanning drains battery faster
- Scanning range is typically 50-100 meters
- Multiple listeners on same stream will all receive events

---

## File Locations

- **Services**: `lib/services/`
  - `p2p_service.dart` - P2P host/client classes
  - `permissions_service.dart` - Permission management
  
- **Pages**: `lib/pages/`
  - `landingPage.dart` - Entry point with mode selection
  - `networkDashboard.dart` - Host/client UI
  - `chatPage.dart` - Messaging interface

- **Configuration**: `android/app/src/main/`
  - `AndroidManifest.xml` - Permissions and features
