import 'dart:async';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';

/// P2P Service for Host role
class P2PHostService {
  final _host = FlutterP2pHost();
  bool _initialized = false;

  /// Initialize the host
  Future<void> initialize() async {
    if (_initialized) return;
    await _host.initialize();
    _initialized = true;
  }

  /// Create a WiFi Direct group
  Future<HotspotHostState> createGroup({bool advertise = true}) async {
    return await _host.createGroup(advertise: advertise);
  }

  /// Remove the group
  Future<void> removeGroup() async {
    await _host.removeGroup();
  }

  /// Get stream of hotspot state (SSID, PSK, IP, active status)
  Stream<HotspotHostState> streamHotspotState() {
    return _host.streamHotspotState();
  }

  /// Get stream of connected clients
  Stream<List<P2pClientInfo>> streamClientList() {
    return _host.streamClientList();
  }

  /// Get stream of received text messages
  Stream<String> streamReceivedTexts() {
    return _host.streamReceivedTexts();
  }

  /// Broadcast text message to all clients
  Future<void> broadcastText(String text) async {
    await _host.broadcastText(text);
  }

  /// Send text to specific client
  Future<bool> sendTextToClient(String text, String clientId) async {
    return await _host.sendTextToClient(text, clientId);
  }

  /// Get stream of files being shared
  Stream<List<HostedFileInfo>> streamSentFilesInfo() {
    return _host.streamSentFilesInfo();
  }

  /// Get stream of files available to download
  Stream<List<ReceivableFileInfo>> streamReceivedFilesInfo() {
    return _host.streamReceivedFilesInfo();
  }

  /// Dispose resources
  void dispose() {
    _host.dispose();
    _initialized = false;
  }
}

/// P2P Service for Client role
class P2PClientService {
  final _client = FlutterP2pClient();
  bool _initialized = false;
  StreamSubscription<List<BleDiscoveredDevice>>? _scanSubscription;

  /// Initialize the client
  Future<void> initialize() async {
    if (_initialized) return;
    await _client.initialize();
    _initialized = true;
  }

  /// Start scanning for hosts via BLE
  Future<void> startScan(
    void Function(List<BleDiscoveredDevice>) onData, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _scanSubscription = await _client.startScan(onData, timeout: timeout);
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _client.stopScan();
  }

  /// Connect to a discovered BLE device
  Future<void> connectWithDevice(
    BleDiscoveredDevice device, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await _client.connectWithDevice(device, timeout: timeout);
  }

  /// Connect using SSID and PSK (manual/QR code)
  Future<void> connectWithCredentials(
    String ssid,
    String psk, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await _client.connectWithCredentials(ssid, psk, timeout: timeout);
  }

  /// Disconnect from host
  Future<void> disconnect() async {
    await _client.disconnect();
  }

  /// Get stream of client connection state
  Stream<HotspotClientState> streamHotspotState() {
    return _client.streamHotspotState();
  }

  /// Get stream of participants in the group
  Stream<List<P2pClientInfo>> streamClientList() {
    return _client.streamClientList();
  }

  /// Get stream of received text messages
  Stream<String> streamReceivedTexts() {
    return _client.streamReceivedTexts();
  }

  /// Broadcast text message to the group
  Future<void> broadcastText(String text) async {
    await _client.broadcastText(text);
  }

  /// Send text to specific client
  Future<bool> sendTextToClient(String text, String clientId) async {
    return await _client.sendTextToClient(text, clientId);
  }

  /// Get stream of files being shared
  Stream<List<HostedFileInfo>> streamSentFilesInfo() {
    return _client.streamSentFilesInfo();
  }

  /// Get stream of files available to download
  Stream<List<ReceivableFileInfo>> streamReceivedFilesInfo() {
    return _client.streamReceivedFilesInfo();
  }

  /// Dispose resources
  void dispose() {
    _scanSubscription?.cancel();
    _client.dispose();
    _initialized = false;
  }
}
