import 'package:flutter/material.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'chatPage.dart';
import '../services/p2p_service.dart';
import '../services/permissions_service.dart';

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

  // Host state
  String? _hotspotSSID;
  String? _hotspotPSK;
  String? _hostIP;
  List<P2pClientInfo> _connectedClients = [];

  // Client state
  bool _isScanning = false;
  bool _isClientConnected = false;
  String? _connectedDeviceName;
  List<BleDiscoveredDevice> _discoveredDevices = [];

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
    _prepareAndInit();
  }

  Future<void> _prepareAndInit() async {
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

    if (widget.isHost) {
      _initHost();
    } else {
      _initClient();
    }
  }

  Future<void> _initHost() async {
    _hostService = P2PHostService();
    await _hostService!.initialize();

    // Create group and then fetch initial state
    try {
      final state = await _hostService!.createGroup();
      setState(() {
        _hotspotSSID = state.ssid;
        _hotspotPSK = state.preSharedKey;
        _hostIP = state.hostIpAddress;
      });
    } catch (e) {
      debugPrint('Host createGroup failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
      }
      return;
    }

    // Listen for connected clients
    _clientListStream = _hostService!.clientStream();
    _clientListStream!.listen((clients) {
      setState(() => _connectedClients = clients);
      debugPrint('Host - connected clients updated: ${clients.length}');
    });

    // Listen for incoming messages
    _hostMessageStream = _hostService!.messageStream();
    _hostMessageStream!.listen((msg) {
      debugPrint('Host received message: $msg');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Msg: $msg')));
      }
    });
  }

  Future<void> _initClient() async {
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
      // After connect we rely on client stream state updates (if available)
      setState(() {
        _isClientConnected = true;
        _connectedDeviceName = device.deviceName;
        _hostIP = null; // plugin may provide later via client state stream
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

  @override
  void dispose() {
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
