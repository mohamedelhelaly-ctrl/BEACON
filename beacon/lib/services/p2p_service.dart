import 'dart:async';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';

class P2PService {
  final _wifiP2P = FlutterP2pConnection();

  Stream<List<DiscoveredPeers>> get deviceStream =>
      _wifiP2P.streamPeers();

  Future<void> initialize() async {
    await _wifiP2P.initialize();
  }

  Future<void> discover() async {
    await _wifiP2P.discover();
  }

  Future<void> stopDiscovery() async {
    await _wifiP2P.stopDiscovery();
  }

  Future<void> connect(String address) async {
    await _wifiP2P.connect(address);
  }

  Future<List<DiscoveredPeers>> fetchPeers() async {
    return await _wifiP2P.fetchPeers();
  }
}
