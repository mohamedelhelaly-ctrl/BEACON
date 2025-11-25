import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class BeaconProvider extends ChangeNotifier {
  final db = DatabaseHelper.instance;

  Map<String, dynamic>? currentDevice;      // this device identity
  Map<String, dynamic>? activeEvent;        // current hosting event
  List<Map<String, dynamic>> connected = []; // currently connected devices
  List<Map<String, dynamic>> logs = [];      // logs for active event

  // ============================================================
  //                   DEVICE INITIALIZATION
  // ============================================================

  Future<void> loadOrCreateDevice(String uuid, String name, bool isHost) async {
    final existing = await db.getDeviceByUUID(uuid);

    if (existing == null) {
      int id = await db.insertDevice(uuid, name, isHost);
      currentDevice = {
        "id": id,
        "device_uuid": uuid,
        "name": name,
        "is_host": isHost ? 1 : 0
      };
    } else {
      currentDevice = existing;
    }

    notifyListeners();
  }

  // ============================================================
  //                   EVENT LIFE CYCLE
  // ============================================================

  Future<void> startHosting(String ssid, String password, String ip) async {
    if (currentDevice == null) return;

    int eventId = await db.createEvent(
      currentDevice!["id"],
      ssid,
      password,
      ip,
    );

    activeEvent = {
      "id": eventId,
      "host_id": currentDevice!["id"],
      "ssid": ssid,
      "password": password,
      "host_ip": ip
    };

    await _writeLog("Host started event");

    notifyListeners();
  }

  Future<void> stopHosting() async {
    if (activeEvent == null) return;

    await db.endEvent(activeEvent!["id"]);
    await _writeLog("Host ended event");

    activeEvent = null;
    connected.clear();

    notifyListeners();
  }

  Future<void> loadActiveEvent() async {
    activeEvent = await db.getActiveEvent();
    notifyListeners();
  }

  // ============================================================
  //                   CLIENT JOIN / LEAVE
  // ============================================================

  Future<void> joinEvent(int eventId) async {
    if (currentDevice == null) return;

    int connectionId =
        await db.addDeviceConnection(eventId, currentDevice!["id"]);

    await _writeLog("Device joined event", eventId: eventId);

    await refreshConnections();

    notifyListeners();
  }

  Future<void> leaveEvent(int connectionId) async {
    await db.disconnectConnection(connectionId);
    await _writeLog("Device left event");

    await refreshConnections();
    notifyListeners();
  }

  // ============================================================
  //                   UPDATE CONNECTION
  // ============================================================

  Future<void> updateLastSeen(int connectionId) async {
    await db.updateLastSeen(connectionId);
  }

  // ============================================================
  //                   LOAD CONNECTED DEVICES
  // ============================================================

  Future<void> refreshConnections() async {
    if (activeEvent == null) return;

    connected = await db.getAllConnectedDevicesInEvent(activeEvent!["id"]);
    notifyListeners();
  }

  // ============================================================
  //                   LOGGING
  // ============================================================

  Future<void> loadLogs() async {
    if (activeEvent == null) return;

    logs = await db.getEventLogs(activeEvent!["id"]);
    notifyListeners();
  }

  Future<void> _writeLog(String msg, {int? eventId}) async {
    if (currentDevice == null) return;

    await db.insertLog(
      currentDevice!["id"],
      eventId ?? activeEvent?["id"],
      msg,
    );

    await loadLogs();
  }

  // Make it accessible for testing
  Future<void> writeLog(String msg, {int? eventId}) => 
      _writeLog(msg, eventId: eventId);
}
