import 'package:flutter/material.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'chatPage.dart';
import 'debugDatabasePage.dart';
import '../services/p2p_service.dart';
import '../services/permissions_service.dart';
import '../providers/beacon_provider.dart';

class NetworkDashboardUI extends StatefulWidget {
  final bool isHost;

  const NetworkDashboardUI({Key? key, required this.isHost}) : super(key: key);

  @override
  State<NetworkDashboardUI> createState() => _NetworkDashboardUIState();
}

class _NetworkDashboardUIState extends State<NetworkDashboardUI> {
  // Services
  P2PHostService? _hostService;
  P2PClientService? _clientService;
  late BeaconProvider _beaconProvider;

  // Host state
  String? _hotspotSSID;
  String? _hotspotPSK;
  String? _hostIP;
  List<P2pClientInfo> _connectedClients = [];

  // Client state
  bool _isScanning = false;
  bool _isClientConnected = false;
  String? _connectedDeviceName;
  String? _connectedEventId;
  List<BleDiscoveredDevice> _discoveredDevices = [];

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
  Stream<String>? _clientMessageStream;

  @override
  void initState() {
    super.initState();
    _beaconProvider = Provider.of<BeaconProvider>(context, listen: false);
    _prepareAndInit();
  }

  Future<void> _prepareAndInit() async {
    try {
      // Get device info for database initialization
      await _initializeDeviceInfo();

      // Ensure required runtime permissions first
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

      // Initialize device in database
      if (_deviceUUID != null && _deviceName != null) {
        await _beaconProvider.loadOrCreateDevice(
          _deviceUUID!,
          _deviceName!,
          widget.isHost,
        );
      }

      if (widget.isHost) {
        _initHost();
      } else {
        _initClient();
      }
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
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        _deviceUUID = iosInfo.identifierForVendor ?? 'unknown_ios';
        _deviceName = iosInfo.model;
      } else {
        // Fallback for other platforms
        _deviceUUID = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
        _deviceName = 'Unknown Device';
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

      // Create group and then fetch initial state
      final state = await _hostService!.createGroup();
      setState(() {
        _hotspotSSID = state.ssid;
        _hotspotPSK = state.preSharedKey;
        _hostIP = state.hostIpAddress;
      });

      // Store event in database
      await _beaconProvider.startHosting(
        state.ssid ?? 'Unknown',
        state.preSharedKey ?? 'Unknown',
        state.hostIpAddress ?? 'Unknown',
      );

      // Listen for connected clients
      _clientListStream = _hostService!.clientStream();
      _clientListStream!.listen((clients) {
        if (mounted) {
          setState(() => _connectedClients = clients);
          debugPrint('Host - connected clients updated: ${clients.length}');
          
          // Refresh provider connections and add any new clients
          _updateConnectedClients(clients);
        }
      });

      // Listen for incoming messages
      _hostMessageStream = _hostService!.messageStream();
      _hostMessageStream!.listen((msg) {
        debugPrint('Host received message: $msg');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Msg: $msg')));
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

  Future<void> _initClient() async {
    try {
      _clientService = P2PClientService();
      await _clientService!.initialize();

      // Listen for messages from host once connected
      _clientMessageStream = _clientService!.messageStream();
      _clientMessageStream!.listen((msg) {
        debugPrint('Client received message: $msg');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Msg: $msg')));
        }
      });
    } catch (e) {
      debugPrint('Client initialization failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Client init failed: $e')),
        );
      }
    }
  }

  Future<void> _startScan() async {
    if (_clientService == null || _isScanning) return;

    setState(() => _isScanning = true);
    _discoveredDevices.clear();

    try {
      // startScan passes discovered devices to our callback
      await _clientService!.startScan((devices) {
        if (mounted) {
          setState(() => _discoveredDevices = devices);
        }
        debugPrint('Discovered ${devices.length} device(s)');
      });
    } catch (e) {
      debugPrint('Scan error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _stopScan() async {
    if (_clientService == null) return;
    try {
      await _clientService!.stopScan();
    } catch (e) {
      debugPrint('Stop scan error: $e');
    } finally {
      if (mounted) setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _connectToDevice(BleDiscoveredDevice device) async {
    if (_clientService == null) return;

    try {
      await _clientService!.connect(device);
      
      // For now, we'll use a simpler approach:
      // Query all active events and join the first one found
      // In a production app, the host would communicate its event ID via P2P
      final activeEvent = await _beaconProvider.db.getActiveEvent();
      
      if (activeEvent != null) {
        // Join the host's event
        await _beaconProvider.joinEvent(activeEvent['id']);
        debugPrint('Client joined event: ${activeEvent['id']}');
      } else {
        debugPrint('No active event found - client may need to wait for host to advertise');
      }

      setState(() {
        _isClientConnected = true;
        _connectedDeviceName = device.deviceName;
        _connectedEventId = activeEvent?['id'].toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connected to ${device.deviceName}')));
    } catch (e) {
      debugPrint('Client connect error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connect failed: $e')));
    }
  }

  Future<void> _sendMessage(String text) async {
    try {
      if (widget.isHost) {
        await _hostService?.sendMessage(text);
      } else {
        await _clientService?.sendMessage(text);
      }
    } catch (e) {
      debugPrint('Send message error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e')));
    }
  }

  Future<void> _keepConnectionAlive() async {
    if (!widget.isHost && _connectedEventId != null) {
      try {
        final connections = await _beaconProvider.db.getActiveEventConnections(int.parse(_connectedEventId!));
        if (connections.isNotEmpty) {
          await _beaconProvider.updateLastSeen(connections.first['id']);
        }
      } catch (e) {
        debugPrint('Keep alive error: $e');
      }
    }
  }

  Future<void> _updateConnectedClients(List<P2pClientInfo> clients) async {
    if (_beaconProvider.activeEvent == null) return;

    try {
      final eventId = _beaconProvider.activeEvent!['id'] as int;
      
      // Get all currently connected devices in the database for this event
      final existingConnections = 
          await _beaconProvider.db.getActiveEventConnections(eventId);
      
      // Extract device IDs that are already in the database
      final existingDeviceIds = existingConnections
          .map((conn) => conn['device_id'] as int)
          .toSet();

      debugPrint('Existing connections: ${existingDeviceIds.length}');

      // For each connected client, ensure they're in the database
      for (final client in clients) {
        try {
          // Try to find or create device entry for this client
          final clientDevice = await _beaconProvider.db.getDeviceByUUID(client.id);
          
          int deviceId;
          if (clientDevice == null) {
            // Create new device entry for the connected client
            deviceId = await _beaconProvider.db.insertDevice(
              client.id,
              client.username,
              false, // Client is not a host
            );
            debugPrint('Created new device for client: ${client.username}');
          } else {
            deviceId = clientDevice['id'] as int;
          }

          // Add connection if not already present
          if (!existingDeviceIds.contains(deviceId)) {
            await _beaconProvider.db.addDeviceConnection(eventId, deviceId);
            existingDeviceIds.add(deviceId);
            debugPrint('Added connection for client: ${client.username}');
            
            // Log the connection event
            await _beaconProvider.db.insertLog(
              _beaconProvider.currentDevice!['id'] as int,
              eventId,
              'Device with id $deviceId connected to the event $eventId',
            );
            debugPrint('Logged connection for device: $deviceId');
          } else {
            // Update last seen for existing connection
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

      // Check for disconnected clients and handle removal
      final connectedClientIds = clients.map((c) => c.id).toSet();
      final disconnectedDeviceIds = <int>[];
      
      for (final existingDeviceId in existingDeviceIds) {
        // Check if this device ID is still connected
        final clientDevice = await _beaconProvider.db.getDeviceById(existingDeviceId);
        if (clientDevice != null) {
          final isStillConnected = connectedClientIds.contains(clientDevice['device_uuid']);
          
          if (!isStillConnected) {
            disconnectedDeviceIds.add(existingDeviceId);
          }
        }
      }

      // Handle disconnected devices
      for (final deviceId in disconnectedDeviceIds) {
        try {
          // Find and disconnect the connection record
          final connToRemove = existingConnections.firstWhere(
            (c) => c['device_id'] == deviceId,
            orElse: () => {},
          );

          if (connToRemove.isNotEmpty) {
            // Update is_current to 0
            await _beaconProvider.db.disconnectConnection(connToRemove['id']);
            
            // Delete the device from devices table
            await _beaconProvider.db.deleteDevice(deviceId);
            
            // Log the disconnection
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
    // Stop hosting if active
    if (widget.isHost && _beaconProvider.activeEvent != null) {
      _beaconProvider.stopHosting();
    }

    _hostService?.dispose();
    _clientService?.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
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
            const Text('Network Dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              widget.isHost
                  ? 'Hosting — waiting for clients'
                  : _isScanning
                      ? 'Scanning for hosts...'
                      : (_isClientConnected ? 'Connected' : 'Ready to scan'),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
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
              if (widget.isHost) _buildHostView() else _buildClientView(),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.isHost)
            FloatingActionButton(
              onPressed: _isScanning ? _stopScan : _startScan,
              backgroundColor: Colors.blueGrey[800],
              mini: true,
              child: Icon(_isScanning ? Icons.stop : Icons.refresh),
              tooltip: _isScanning ? 'Stop scanning' : 'Start scan',
            ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatPage()));
            },
            backgroundColor: _accentRed,
            child: const Icon(Icons.chat, color: Colors.white),
            tooltip: 'Chat',
          ),
        ],
      ),
    );
  }

  Widget _buildHostView() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          const Text('WiFi Direct Group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          Card(
            color: _cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(color: _accentGreen, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.wifi, color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Group Status', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(_hotspotSSID ?? 'Initializing...', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ])),
                ]),
                const SizedBox(height: 12),
                _infoRow('Network', _hotspotSSID ?? 'N/A'),
                _infoRow('Password', _hotspotPSK ?? 'N/A'),
                _infoRow('Host IP', _hostIP ?? 'N/A'),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Connected Devices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          Expanded(
            child: _connectedClients.isEmpty
                ? Center(child: Text('Waiting for devices to connect...', style: TextStyle(color: Colors.white70)))
                : ListView.builder(
                    itemCount: _connectedClients.length,
                    itemBuilder: (context, i) {
                      final c = _connectedClients[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Card(
                          color: _cardColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)), child: Icon(c.isHost ? Icons.router : Icons.phone_android, color: _accentGreen)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(c.username, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                                const SizedBox(height: 4),
                                Text(c.isHost ? 'Host' : 'Client', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                              ])),
                              Icon(Icons.check_circle, color: _accentGreen, size: 20),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientView() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          if (_isClientConnected)
            Card(
              color: _accentGreen.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFF10B981), width: 1)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Connected', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700)),
                    if (_connectedDeviceName != null) Text('Host: $_connectedDeviceName', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    if (_hostIP != null) Text('IP: $_hostIP', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ]),
                ]),
              ),
            )
          else ...[
            const Text('Available Hosts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _isClientConnected
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle_outline, size: 64, color: _accentGreen),
                    const SizedBox(height: 16),
                    Text('Connected to $_connectedDeviceName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text('Go to Chat to start messaging', style: TextStyle(fontSize: 14, color: Colors.white70), textAlign: TextAlign.center),
                  ]))
                : _discoveredDevices.isEmpty
                    ? Center(child: Text(_isScanning ? 'Scanning for hosts...' : 'Tap scan to find hosts', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)))
                    : ListView.builder(
                        itemCount: _discoveredDevices.length,
                        itemBuilder: (context, index) {
                          final device = _discoveredDevices[index];
                          final isConnectedToThis = _connectedDeviceName == device.deviceName && _isClientConnected;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Card(
                              color: _cardColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(children: [
                                  Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.router, color: Colors.white70)),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(device.deviceName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                                    const SizedBox(height: 4),
                                    Text('MAC: ${device.deviceAddress}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                                  ])),
                                  if (isConnectedToThis)
                                    Icon(Icons.check_circle, color: _accentGreen, size: 28)
                                  else
                                    ElevatedButton(
                                      onPressed: () => _connectToDevice(device),
                                      style: ElevatedButton.styleFrom(backgroundColor: _accentRed, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                                      child: const Text('Connect', style: TextStyle(color: Colors.white)),
                                    ),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        SelectableText(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('WiFi Direct Info', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Mode: ${widget.isHost ? "Host (Group Owner)" : "Client"}', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          if (widget.isHost) ...[
            Text('SSID: ${_hotspotSSID ?? "N/A"}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('PSK: ${_hotspotPSK ?? "N/A"}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Host IP: ${_hostIP ?? "N/A"}', style: const TextStyle(color: Colors.white70)),
          ] else ...[
            Text('Connected Host: ${_connectedDeviceName ?? "N/A"}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text('Host IP: ${_hostIP ?? "N/A"}', style: const TextStyle(color: Colors.white70)),
          ]
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: _accentRed))),
        ],
      ),
    );
  }
}
