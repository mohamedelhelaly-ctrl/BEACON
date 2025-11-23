import 'dart:async';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';

/// ===============================
/// SIMPLE HOST SERVICE
/// ===============================
class P2PHostService {
  final FlutterP2pHost _host = FlutterP2pHost();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _host.initialize();
    _initialized = true;
  }

  /// Create Wi-Fi Direct hotspot group
  Future<HotspotHostState> createGroup() async {
    return await _host.createGroup(advertise: true);
  }

  /// Listen for connected clients
  Stream<List<P2pClientInfo>> clientStream() {
    return _host.streamClientList();
  }

  /// Listen for text messages
  Stream<String> messageStream() {
    return _host.streamReceivedTexts();
  }

  /// Send text to all clients
  Future<void> sendMessage(String text) async {
    await _host.broadcastText(text);
  }

  void dispose() {
    _host.dispose();
    _initialized = false;
  }
}

/// ===============================
/// SIMPLE CLIENT SERVICE
/// ===============================
class P2PClientService {
  final FlutterP2pClient _client = FlutterP2pClient();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _client.initialize();
    _initialized = true;
  }

  /// BLE scan for available hosts
  Future<void> startScan(Function(List<BleDiscoveredDevice>) onDevices) async {
    await _client.startScan(onDevices);
  }

  Future<void> stopScan() async {
    await _client.stopScan();
  }

  /// Connect to host using discovered device
  Future<void> connect(BleDiscoveredDevice device) async {
    await _client.connectWithDevice(device);
  }

  /// Listen for text messages
  Stream<String> messageStream() {
    return _client.streamReceivedTexts();
  }

  /// Send text to group
  Future<void> sendMessage(String text) async {
    await _client.broadcastText(text);
  }

  void dispose() {
    _client.dispose();
    _initialized = false;
  }
}
