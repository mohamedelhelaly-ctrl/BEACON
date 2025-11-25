import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/beacon_provider.dart';

class DebugDatabasePage extends StatefulWidget {
  const DebugDatabasePage({Key? key}) : super(key: key);

  @override
  State<DebugDatabasePage> createState() => _DebugDatabasePageState();
}

class _DebugDatabasePageState extends State<DebugDatabasePage> {
  static const Color _bgColor = Color(0xFF0F1724);
  static const Color _cardColor = Color(0xFF16202B);
  static const Color _accentGreen = Color(0xFF10B981);
  static const Color _accentRed = Color(0xFFEF4444);

  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _connections = [];
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<BeaconProvider>();
      final db = provider.db;

      // Load all devices
      final devicesResult = await db.database.then((database) async {
        return await database.query('devices');
      });

      // Load all events
      final eventsResult = await db.database.then((database) async {
        return await database.query('events');
      });

      // Load all connections
      final connectionsResult = await db.database.then((database) async {
        return await database.query('event_connections');
      });

      // Load all logs
      final logsResult = await db.database.then((database) async {
        return await database.query('logs', orderBy: 'timestamp DESC');
      });

      if (mounted) {
        setState(() {
          _devices = devicesResult;
          _events = eventsResult;
          _connections = connectionsResult;
          _logs = logsResult;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Widget _buildDataSection({
    required String title,
    required List<Map<String, dynamic>> data,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _accentGreen),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (data.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text(
              'No data found',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.length,
              separatorBuilder: (_, __) => Divider(
                color: Colors.white12,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final item = data[index];
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: item.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              '${e.key}: ',
                              style: const TextStyle(
                                color: _accentGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                e.value.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final provider = context.read<BeaconProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                await provider.loadOrCreateDevice(
                  'test_uuid_${DateTime.now().millisecondsSinceEpoch}',
                  'Test Device ${DateTime.now().second}',
                  true,
                );
                _refreshData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Test device created!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✗ Error: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.add_circle),
            label: const Text('Add Test Device'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                if (provider.currentDevice == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('⚠️ Create a device first!')),
                    );
                  }
                  return;
                }

                await provider.startHosting(
                  'TestNetwork_${DateTime.now().second}',
                  'password123',
                  '192.168.49.1',
                );
                _refreshData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Test event created!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✗ Error: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.add_circle),
            label: const Text('Create Test Event'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                if (provider.activeEvent == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('⚠️ Create an event first!')),
                    );
                  }
                  return;
                }

                await provider.joinEvent(provider.activeEvent!['id']);
                _refreshData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Device joined event!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✗ Error: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.add_circle),
            label: const Text('Join Test Event'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                if (provider.currentDevice == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('⚠️ Create a device first!')),
                    );
                  }
                  return;
                }

                await provider.db.insertLog(
                  provider.currentDevice!['id'],
                  provider.activeEvent?['id'],
                  'Manual test log entry ${DateTime.now().second}',
                );
                await provider.loadLogs();
                _refreshData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Test log created!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✗ Error: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.add_circle),
            label: const Text('Add Test Log'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh All Data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Database Debug',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _accentGreen),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _accentGreen),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Devices Section
                  _buildDataSection(
                    title: 'Devices (${_devices.length})',
                    data: _devices,
                    icon: Icons.phone_android,
                  ),
                  const SizedBox(height: 16),

                  // Events Section
                  _buildDataSection(
                    title: 'Events (${_events.length})',
                    data: _events,
                    icon: Icons.wifi,
                  ),
                  const SizedBox(height: 16),

                  // Connections Section
                  _buildDataSection(
                    title: 'Event Connections (${_connections.length})',
                    data: _connections,
                    icon: Icons.link,
                  ),
                  const SizedBox(height: 16),

                  // Logs Section
                  _buildDataSection(
                    title: 'Activity Logs (${_logs.length})',
                    data: _logs,
                    icon: Icons.history,
                  ),
                  const SizedBox(height: 24),

                  // Quick Actions
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}