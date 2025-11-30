import 'package:flutter/material.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'chatPage.dart';
import 'debugDatabasePage.dart';
import 'profilePage.dart';
import '../services/p2p_service.dart';
import '../services/permissions_service.dart';
import '../providers/beacon_provider.dart';
import '../providers/message_provider.dart';

class HostDashboardUI extends StatefulWidget {
  const HostDashboardUI({Key? key}) : super(key: key);

  @override
  State<HostDashboardUI> createState() => _HostDashboardUIState();
}

class _HostDashboardUIState extends State<HostDashboardUI> {
  // Services
  P2PHostService? _hostService;
  late BeaconProvider _beaconProvider;

  // Host state
  String? _hotspotSSID; //network name
  String? _hotspotPSK; //password
  String? _hostIP; //host ip
  List<P2pClientInfo> _connectedClients = [];
  Set<String> _lastSyncedClientIds = {};

  // Device info for database
  String? _deviceUUID;
  String? _deviceName;

  // UI colors
  static const Color _bgColor = Color(0xFF0F1724);
  static const Color _cardColor = Color(0xFF16202B);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentGreen = Color(0xFF10B981);

  // Subscriptions
  Stream<List<P2pClientInfo>>? _clientListStream;
  Stream<String>? _hostMessageStream;

  @override
  void initState() {
    super.initState();
    _beaconProvider = Provider.of<BeaconProvider>(context, listen: false);
    _prepareAndInit();
  }

  Future<void> _prepareAndInit() async {
    try {
      await _beaconProvider.db.clearAllData();
      await _initializeDeviceInfo();

      final ok = await PermissionService.requestP2PPermissions();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Required permissions not granted')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      if (_deviceUUID != null && _deviceName != null) {
        await _beaconProvider.loadOrCreateDevice(
          _deviceUUID!,
          _deviceName!,
          true, // isHost = true
        );
      }

      _initHost();
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Initialization failed: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _initializeDeviceInfo() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        _deviceUUID = androidInfo.id;
        _deviceName = androidInfo.model;
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
      _deviceUUID = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      _deviceName = 'Unknown Device';
    }
  }

  Future<void> _initHost() async {
    try {
      _hostService = P2PHostService();
      await _hostService!.initialize();

      final state = await _hostService!.createGroup();
      setState(() {
        _hotspotSSID = state.ssid;
        _hotspotPSK = state.preSharedKey;
        _hostIP = state.hostIpAddress;
      });

      await _beaconProvider.startHosting( //create new event and log in db
        state.ssid ?? 'Unknown',
        state.preSharedKey ?? 'Unknown',
        state.hostIpAddress ?? 'Unknown',
      );

      final messageProvider = Provider.of<MessageProvider>(context, listen: false);
      messageProvider.initialize(_deviceUUID!, _deviceName!);

      // Listen for connected clients
      _clientListStream = _hostService!.clientStream();
      _clientListStream!.listen((clients) async {
        if (!mounted) return;

        setState(() => _connectedClients = clients);
        debugPrint('Host - connected clients updated: ${clients.length}');

        // Update database with connected clients
        await _updateConnectedClients(clients);

        // Detect new client connections
        final currentClientIds = clients.map((c) => c.id).toSet();
        final hasNewClient =
            !currentClientIds.containsAll(_lastSyncedClientIds) ||
            currentClientIds.length > _lastSyncedClientIds.length;

        // ALWAYS broadcast latest database to all clients

        if (hasNewClient) {
           await _broadcastDatabaseToAllClients();

          _lastSyncedClientIds = currentClientIds;
          debugPrint('Host detected new client(s), broadcasting updated database');
        }
      });

      // Listen for incoming messages from clients
      _hostMessageStream = _hostService!.messageStream();
      _hostMessageStream!.listen((msg) {
        debugPrint('Host received message: $msg');

        String senderName = 'Unknown Client';
        String senderId = 'unknown';

        if (_connectedClients.isNotEmpty) {
          final client = _connectedClients.first;
          senderName = client.username;
          senderId = client.id;
        }

        if (mounted) {
          final messageProvider = Provider.of<MessageProvider>(context, listen: false);
          messageProvider.addReceivedMessage(senderName, senderId, msg);
        }
      });
    } catch (e) {
      debugPrint('Host initialization failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Host init failed: $e')),
        );
      }
    }
  }

  Future<void> _broadcastDatabaseToAllClients() async {
    if (_hostService == null || _connectedClients.isEmpty) return;

    try {
      final syncData = await _beaconProvider.db.buildEventSync();
      if (syncData != null) {
        // Broadcast to all connected clients
        for (final client in _connectedClients) {
          await _hostService!.sendEventSync(syncData);
          debugPrint('Host sent EVENT_SYNC to client: ${client.id}');
        }
      }
    } catch (e) {
      debugPrint('Error broadcasting database to clients: $e');
    }
  }

  Future<void> _updateConnectedClients(List<P2pClientInfo> clients) async {
    if (_beaconProvider.activeEvent == null) return;

    try {
      final eventId = _beaconProvider.activeEvent!['id'] as int;

      final existingConnections =
          await _beaconProvider.db.getActiveEventConnections(eventId);

      final existingDeviceIds = existingConnections
          .map((conn) => conn['device_id'] as int)
          .toSet();

      debugPrint('Existing connections: ${existingDeviceIds.length}');

      for (final client in clients) {
        try {
          final clientDevice = await _beaconProvider.db.getDeviceByUUID(client.id);

          int deviceId;
          if (clientDevice == null) {
            deviceId = await _beaconProvider.db.insertDevice(
              client.id,
              client.username,
              false,
            );
            debugPrint('Created new device for client: ${client.username}');
          } else {
            deviceId = clientDevice['id'] as int;
          }

          if (!existingDeviceIds.contains(deviceId)) {
            await _beaconProvider.db.addDeviceConnection(eventId, deviceId);
            existingDeviceIds.add(deviceId);
            debugPrint('Added connection for client: ${client.username}');

            await _beaconProvider.db.insertLog(
              _beaconProvider.currentDevice!['id'] as int,
              eventId,
              'Device with id $deviceId connected to the event $eventId',
            );
            debugPrint('Logged connection for device: $deviceId');
          } else {
            final connIndex = existingConnections
                .indexWhere((conn) => conn['device_id'] == deviceId);
            if (connIndex >= 0) {
              await _beaconProvider.db
                  .updateLastSeen(existingConnections[connIndex]['id'] as int);
            }
          }
        } catch (e) {
          debugPrint('Error processing client ${client.username}: $e');
        }
      }

      final connectedClientIds = clients.map((c) => c.id).toSet();
      final disconnectedDeviceIds = <int>[];

      for (final existingDeviceId in existingDeviceIds) {
        final clientDevice = await _beaconProvider.db.getDeviceById(existingDeviceId);
        if (clientDevice != null) {
          final isStillConnected =
              connectedClientIds.contains(clientDevice['device_uuid']);

          if (!isStillConnected) {
            disconnectedDeviceIds.add(existingDeviceId);
          }
        }
      }

      for (final deviceId in disconnectedDeviceIds) {
        try {
          final connToRemove = existingConnections.firstWhere(
            (c) => c['device_id'] == deviceId,
            orElse: () => {},
          );

          if (connToRemove.isNotEmpty) {
            await _beaconProvider.db.disconnectConnection(connToRemove['id']);
            await _beaconProvider.db.deleteDevice(deviceId);

            await _beaconProvider.db.insertLog(
              _beaconProvider.currentDevice!['id'] as int,
              eventId,
              'Device with id $deviceId has left the event $eventId',
            );

            debugPrint('Device $deviceId disconnected and removed from database');
          }
        } catch (e) {
          debugPrint('Error removing disconnected device $deviceId: $e');
        }
      }

      await _beaconProvider.refreshConnections();
      await _beaconProvider.loadLogs();
    } catch (e) {
      debugPrint('Error updating connected clients: $e');
    }
  }

  @override
  void dispose() {
    if (_beaconProvider.activeEvent != null) {
      _beaconProvider.stopHosting();
    }

    _hostService?.dispose();
    super.dispose();
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          SelectableText(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('WiFi Direct Info', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mode: Host (Group Owner)',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Text('SSID: ${_hotspotSSID ?? "N/A"}',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('PSK: ${_hotspotPSK ?? "N/A"}',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Host IP: ${_hostIP ?? "N/A"}',
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: _accentRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Network Dashboard',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            const Text(
              'Hosting — waiting for clients',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DebugDatabasePage()),
              );
            },
            icon: const Icon(Icons.bug_report),
            tooltip: 'Database Debug',
          ),
          IconButton(
            onPressed: _showInfoDialog,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    const Text('WiFi Direct Group',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 12),
                    Card(
                      color: _cardColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                      color: _accentGreen,
                                      borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.wifi,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Group Status',
                                          style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(_hotspotSSID ?? 'Initializing...',
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _infoRow('Network', _hotspotSSID ?? 'N/A'),
                            _infoRow('Password', _hotspotPSK ?? 'N/A'),
                            _infoRow('Host IP', _hostIP ?? 'N/A'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Connected Devices',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _connectedClients.isEmpty
                          ? Center(
                              child: Text('Waiting for devices to connect...',
                                  style:
                                      TextStyle(color: Colors.white70)))
                          : ListView.builder(
                              itemCount: _connectedClients.length,
                              itemBuilder: (context, i) {
                                final c = _connectedClients[i];
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Card(
                                    color: _cardColor,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                                color: Colors.white10,
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: Icon(
                                                c.isHost
                                                    ? Icons.router
                                                    : Icons.phone_android,
                                                color: _accentGreen),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(c.username,
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors.white)),
                                                const SizedBox(height: 4),
                                                Text(
                                                    c.isHost ? 'Host' : 'Client',
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            Colors.white70)),
                                              ],
                                            ),
                                          ),
                                          Icon(Icons.check_circle,
                                              color: _accentGreen, size: 20),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatPage(
                isHost: true,
                hostService: _hostService,
                clientService: null,
              ),
            ),
          );
        },
        backgroundColor: _accentRed,
        child: const Icon(Icons.chat, color: Colors.white),
        tooltip: 'Chat',
      ),
    );
  }
}