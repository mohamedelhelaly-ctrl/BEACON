import 'package:flutter/material.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'chatPage.dart';
import 'debugDatabasePage.dart';
import 'profilePage.dart';
import '../../services/p2p_service.dart';
import '../../services/permissions_service.dart';
import '../../providers/beacon_provider.dart';
import '../../providers/message_provider.dart';

class ClientDashboardUI extends StatefulWidget {
  const ClientDashboardUI({Key? key}) : super(key: key);

  @override
  State<ClientDashboardUI> createState() => _ClientDashboardUIState();
}

class _ClientDashboardUIState extends State<ClientDashboardUI> {
  // Services
  P2PClientService? _clientService;
  late BeaconProvider _beaconProvider;

  // Client state
  bool _isScanning = false;
  bool _isClientConnected = false;
  String? _connectedDeviceName;
  String? _hostIP;
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
  Stream<String>? _clientMessageStream;

  @override
  void initState() {
    super.initState();
    _beaconProvider = Provider.of<BeaconProvider>(context, listen: false);
    _prepareAndInit();
  }

  Future<void> _prepareAndInit() async {
    try {
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

      // if (_deviceUUID != null && _deviceName != null) {
      //   await _beaconProvider.loadOrCreateDevice(
      //     _deviceUUID!,
      //     _deviceName!,
      //     false, // isHost = false
      //   );
      // }

      _initClient();
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

  Future<void> _initClient() async {
    try {
      _clientService = P2PClientService();
      await _clientService!.initialize();

      final messageProvider = Provider.of<MessageProvider>(context, listen: false);
      messageProvider.initialize(_deviceUUID!, _deviceName!);

      _clientMessageStream = _clientService!.messageStream();
      _clientMessageStream!.listen((msg) {
        debugPrint('Client received message: $msg');

        final syncData = _clientService!.parseMessage(msg);
        if (syncData != null) {
          _handleEventSync(syncData);
        } else {
          if (mounted) {
            String hostName = _beaconProvider.hostDeviceName ?? 'Host';
            String hostId = 'host';
            messageProvider.addReceivedMessage(hostName, hostId, msg);
          }
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
      await _clientService!.startScan((devices) {
        if (mounted) {
          setState(() => _discoveredDevices = devices);
        }
        debugPrint('Discovered ${devices.length} device(s)');
      });
    } catch (e) {
      debugPrint('Scan error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
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
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connectToDevice(BleDiscoveredDevice device) async {
    if (_clientService == null) return;

    try {
      await _clientService!.connect(device);

      if (!mounted) return;

      setState(() {
        _isClientConnected = true;
        _connectedDeviceName = device.deviceName;
      });

      _beaconProvider.setHostDeviceName(device.deviceName);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device.deviceName}')),
      );

      debugPrint('Client connected — waiting for EVENT_SYNC...');
    } catch (e) {
      debugPrint('Client connect error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connect failed: $e')),
        );
      }
    }
  }

  Future<void> _handleEventSync(Map<String, dynamic> syncData) async {
    try {
      // Clear local database and repopulate with host's data
      // This ensures client has exact same data as host
      await _beaconProvider.db.clearAndRepopulateFromSync(syncData);
      
      // Reload all data from database
      await _beaconProvider.loadActiveEvent();
      await _beaconProvider.refreshConnections();
      await _beaconProvider.loadLogs();

      debugPrint('Client cleared local database and synced with host');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database cleared and synced with host')),
        );
      }
    } catch (e) {
      debugPrint('Error syncing with host: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _clientService?.dispose();
    super.dispose();
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
            const Text('Mode: Client', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Text('Connected Host: ${_connectedDeviceName ?? "N/A"}',
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
            Text(
              _isScanning
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
                    if (_isClientConnected)
                      Card(
                        color: _accentGreen.withOpacity(0.08),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(
                                color: Color(0xFF10B981), width: 1)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Color(0xFF10B981)),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Connected',
                                      style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontWeight: FontWeight.w700)),
                                  if (_connectedDeviceName != null)
                                    Text('Host: $_connectedDeviceName',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70)),
                                  if (_hostIP != null)
                                    Text('IP: $_hostIP',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      const Text('Available Hosts',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 12),
                    Expanded(
                      child: _isClientConnected
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      size: 64, color: _accentGreen),
                                  const SizedBox(height: 16),
                                  Text('Connected to $_connectedDeviceName',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white),
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'Go to Chat to start messaging',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70),
                                      textAlign: TextAlign.center),
                                ],
                              ),
                            )
                          : _discoveredDevices.isEmpty
                              ? Center(
                                  child: Text(
                                      _isScanning
                                          ? 'Scanning for hosts...'
                                          : 'Tap scan to find hosts',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.white70)))
                              : ListView.builder(
                                  itemCount: _discoveredDevices.length,
                                  itemBuilder: (context, index) {
                                    final device = _discoveredDevices[index];
                                    final isConnectedToThis =
                                        _connectedDeviceName ==
                                                device.deviceName &&
                                            _isClientConnected;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: Card(
                                        color: _cardColor,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 12),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 56,
                                                height: 56,
                                                decoration: BoxDecoration(
                                                    color: Colors.white10,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                                child: const Icon(
                                                    Icons.router,
                                                    color: Colors.white70),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(device.deviceName,
                                                        style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Colors
                                                                .white)),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                        'MAC: ${device.deviceAddress}',
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .white54)),
                                                  ],
                                                ),
                                              ),
                                              if (isConnectedToThis)
                                                Icon(
                                                    Icons.check_circle,
                                                    color: _accentGreen,
                                                    size: 28)
                                              else
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      _connectToDevice(device),
                                                  style: ElevatedButton
                                                      .styleFrom(
                                                    backgroundColor:
                                                        _accentRed,
                                                    elevation: 2,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(8),
                                                    ),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12,
                                                        vertical: 10),
                                                  ),
                                                  child: const Text('Connect',
                                                      style: TextStyle(
                                                          color:
                                                              Colors.white)),
                                                ),
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    isHost: false,
                    hostService: null,
                    clientService: _clientService,
                  ),
                ),
              );
            },
            backgroundColor: _accentRed,
            child: const Icon(Icons.chat, color: Colors.white),
            tooltip: 'Chat',
          ),
        ],
      ),
    );
  }
}