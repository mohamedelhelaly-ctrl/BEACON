import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestPermissions() async {
    var location = await Permission.location.request();
    var nearby = await Permission.nearbyWifiDevices.request();

    return location.isGranted && nearby.isGranted;
  }
}
