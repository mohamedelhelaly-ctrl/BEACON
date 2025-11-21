import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestPermissions() async {
    print('[PermissionService] Requesting permissions...');
    
    var location = await Permission.location.request();
    print('[PermissionService] Location permission: ${location.toString()}');
    
    var nearby = await Permission.nearbyWifiDevices.request();
    print('[PermissionService] Nearby WiFi devices permission: ${nearby.toString()}');

    bool granted = location.isGranted && nearby.isGranted;
    print('[PermissionService] All permissions granted: $granted');
    
    return granted;
  }
}
