import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class BeaconProvider extends ChangeNotifier {
  Map<String, dynamic>? user;
  List<Map<String, dynamic>> devices = [];
  List<Map<String, dynamic>> logs = [];

  final db = DatabaseHelper.instance;

  Future<void> loadUser() async {
    user = await db.getUser();
    notifyListeners();
  }

  Future<void> addDevice(String name, String address) async {
    await db.insertDevice(name, address);
    devices = await db.getDevices();
    notifyListeners();
  }

  Future<void> addLog(String event) async {
    await db.insertLog(event);
    logs = await db.getLogs();
    notifyListeners();
  }

  Future<void> loadDevices() async {
    devices = await db.getDevices();
    notifyListeners();
  }
}
