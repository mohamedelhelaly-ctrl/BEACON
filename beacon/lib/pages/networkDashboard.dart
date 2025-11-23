import 'package:flutter/material.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'chatPage.dart';
import '../services/p2p_service.dart';

class NetworkDashboardUI extends StatefulWidget {
  final bool isHost;

  const NetworkDashboardUI({Key? key, required this.isHost})
      : super(key: key);

  @override
  State<NetworkDashboardUI> createState() => _NetworkDashboardUIState();
}

class _NetworkDashboardUIState extends State<NetworkDashboardUI> {
  late P2PHostService _hostService;
  late P2PClientService _clientService;
  bool _isScanning = false;
  bool _isClientConnected = false;
  String? _connectedDeviceName;
  String? _hotspotSSID;
  String? _hotspotPSK;
  String? _hostIP;
  List<BleDiscoveredDevice> _discoveredDevices = [];

  static const Color _bgColor = Color(0xFF0F1724);
  static const Color _cardColor = Color(0xFF16202B);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentGreen = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _initializeP2P();
  }

  Future<void> _initializeP2P() async {
    if (widget.isHost) {
      _hostService = P2PHostService();
      await _hostService.initialize();
      await _createGroup();
      _listenToHostStreams();
    } else {
      _clientService = P2PClientService();
      await _clientService.initialize();
    }
  }

  Future<void> _createGroup() async {
    try {
      final state = await _hostService.createGroup(advertise: true);
      if (mounted) {
        setState(() {
          _hotspotSSID = state.ssid;
          _hotspotPSK = state.preSharedKey;
          _hostIP = state.hostIpAddress;
        });
      }
      debugPrint(
          'Group created - SSID: ${state.ssid}, PSK: ${state.preSharedKey}, IP: ${state.hostIpAddress}');
    } catch (e) {
      debugPrint('Failed to create group: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
      }
    }
  }

  void _listenToHostStreams() {
    // Listen to connected clients
    _hostService.streamClientList().listen((clients) {
      if (mounted) {
        setState(() {});
      }
      debugPrint('Connected clients: ${clients.length}');
    });

    // Listen to hotspot state changes
    _hostService.streamHotspotState().listen((state) {
      if (mounted) {
        setState(() {
          _hotspotSSID = state.ssid;
          _hotspotPSK = state.preSharedKey;
          _hostIP = state.hostIpAddress;
        });
      }
      debugPrint('Hotspot state: Active=${state.isActive}');
    });

    // Listen to received messages
    _hostService.streamReceivedTexts().listen((message) {
      debugPrint('Host received message: $message');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message: $message')),
      );
    });
  }

  void _listenToClientStreams() {
    // Listen to connection state
    _clientService.streamHotspotState().listen((state) {
      if (mounted) {
        setState(() {
          _hostIP = state.hostGatewayIpAddress;
          _isClientConnected = state.isActive;
        });
      }
      debugPrint('Client state: Active=${state.isActive}, IP=${state.hostIpAddress}');
    });

    // Listen to received messages
    _clientService.streamReceivedTexts().listen((message) {
      debugPrint('Client received message: $message');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message: $message')),
      );
    });
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    setState(() => _isScanning = true);

    try {
      await _clientService.startScan(
        (devices) {
          setState(() {
            _discoveredDevices = devices;
          });
          debugPrint('Discovered ${devices.length} devices');
        },
      );
      _listenToClientStreams();
    } catch (e) {
      debugPrint('Scan error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
      setState(() => _isScanning = false);
    }
  }

  Future<void> _stopScan() async {
    try {
      await _clientService.stopScan();
      setState(() {
        _isScanning = false;
        _discoveredDevices.clear();
      });
    } catch (e) {
      debugPrint('Error stopping scan: $e');
    }
  }

  Future<void> _connectToDevice(BleDiscoveredDevice device) async {
    try {
      debugPrint('Connecting to ${device.deviceName}...');
      await _clientService.connectWithDevice(device);
      if (mounted) {
        setState(() {
          _connectedDeviceName = device.deviceName;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${device.deviceName}')),
        );
      }
    } catch (e) {
      debugPrint('Connection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    if (widget.isHost) {
      _hostService.dispose();
    } else {
      _clientService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Network Dashboard',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              widget.isHost
                  ? 'Hosting WiFi Direct group'
                  : _isScanning
                      ? 'Scanning for hosts...'
                      : 'Ready to scan',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              _showInfoDialog();
            },
            icon: const Icon(Icons.info_outline),
            tooltip: 'Info',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isHost) _buildHostMode() else _buildClientMode(),
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
              tooltip: _isScanning ? 'Stop scanning' : 'Start scanning',
            ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatPage()),
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

  Widget _buildHostMode() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          const Text(
            'WiFi Direct Group',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 12),
          // WiFi Hotspot Info Card
          Card(
            color: _cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.wifi, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Group Status',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _hotspotSSID ?? 'Initializing...',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Network', _hotspotSSID ?? 'N/A'),
                  _buildInfoRow('Password', _hotspotPSK ?? 'N/A'),
                  _buildInfoRow('Host IP', _hostIP ?? 'N/A'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Connected Devices',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<P2pClientInfo>>(
              stream: _hostService.streamClientList(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final clients = snapshot.data ?? [];

                if (clients.isEmpty) {
                  return Center(
                    child: Text(
                      'Waiting for devices to connect...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Card(
                        color: _cardColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  client.isHost ? Icons.router : Icons.phone_android,
                                  color: _accentGreen,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      client.username,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      client.isHost ? 'Host' : 'Client',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.check_circle,
                                color: _accentGreen,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientMode() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          // Connection status indicator
          if (_isClientConnected)
            Card(
              color: _accentGreen.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFF10B981), width: 1)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Connected',
                          style: TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w700),
                        ),
                        if (_connectedDeviceName != null)
                          Text(
                            'Host: $_connectedDeviceName',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70),
                          ),
                        if (_hostIP != null)
                          Text(
                            'IP: $_hostIP',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else ...[
            const Text(
              'Available Hosts',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
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
                        Text(
                          'Connected to $_connectedDeviceName',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Go to Chat to start messaging',
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : _discoveredDevices.isEmpty
                    ? Center(
                        child: Text(
                          _isScanning
                              ? 'Scanning for hosts...'
                              : 'Tap the scan button to find hosts',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _discoveredDevices.length,
                        itemBuilder: (context, index) {
                          final device = _discoveredDevices[index];
                          final isConnectedToThis =
                              _connectedDeviceName == device.deviceName &&
                                  _isClientConnected;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Card(
                              color: _cardColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
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
                                            BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.router,
                                          color: Colors.white70),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            device.deviceName,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'MAC: ${device.deviceAddress}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.white54),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isConnectedToThis)
                                      Icon(Icons.check_circle,
                                          color: _accentGreen, size: 28)
                                    else
                                      ElevatedButton(
                                        onPressed: () =>
                                            _connectToDevice(device),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _accentRed,
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                        ),
                                        child: const Text('Connect',
                                            style: TextStyle(
                                                color: Colors.white)),
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
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          SelectableText(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
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
            Text(
              'Mode: ${widget.isHost ? "Host (Group Owner)" : "Client"}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            if (widget.isHost) ...[
              Text(
                'SSID: $_hotspotSSID',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'PSK: $_hotspotPSK',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'Host IP: $_hostIP',
                style: const TextStyle(color: Colors.white70),
              ),
            ] else ...[
              Text(
                'Host IP: $_hostIP',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
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
}