import 'package:flutter/material.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'chatPage.dart';
import '../services/p2p_service.dart';
import '../services/permissions_service.dart';

class NetworkDashboardUI extends StatefulWidget {
	const NetworkDashboardUI({Key? key}) : super(key: key);

	@override
	State<NetworkDashboardUI> createState() => _NetworkDashboardUIState();
}

class _NetworkDashboardUIState extends State<NetworkDashboardUI> {
	late P2PService _p2pService;
	bool _isDiscovering = false;
	bool _permissionsGranted = false;

	static const Color _bgColor = Color(0xFF0F1724);
	static const Color _cardColor = Color(0xFF16202B);
	static const Color _accentRed = Color(0xFFEF4444);
	static const Color _accentGreen = Color(0xFF10B981);

	@override
	void initState() {
		super.initState();
		_p2pService = P2PService();
		_initializeP2P();
	}

	Future<void> _initializeP2P() async {
		// Request permissions
		final permissionsGranted = await PermissionService.requestPermissions();
		if (!mounted) return;

		setState(() {
			_permissionsGranted = permissionsGranted;
		});

		if (permissionsGranted) {
			try {
				await _p2pService.initialize();
				_startDiscovery();
			} catch (e) {
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(
						SnackBar(content: Text('Failed to initialize P2P: $e')),
					);
				}
			}
		}
	}

	Future<void> _startDiscovery() async {
		if (_isDiscovering) return;

		setState(() {
			_isDiscovering = true;
		});

		try {
			await _p2pService.discover();
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Discovery failed: $e')),
				);
			}
		}
	}

	Future<void> _stopDiscovery() async {
		try {
			await _p2pService.stopDiscovery();
			setState(() {
				_isDiscovering = false;
			});
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Stop discovery failed: $e')),
				);
			}
		}
	}

	@override
	void dispose() {
		_stopDiscovery();
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
						const Text('Network Dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
						const SizedBox(height: 2),
						Text(
							_isDiscovering ? 'Discovering devices...' : 'Connected Devices',
							style: const TextStyle(fontSize: 12, color: Colors.white70),
						),
					],
				),
				actions: [
					IconButton(
						onPressed: () {},
						icon: const Icon(Icons.info_outline),
						tooltip: 'Info',
					)
				],
			),
			body: SafeArea(
				child: Padding(
					padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							const SizedBox(height: 6),
							const Text(
								'Nearby Devices Detected',
								style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
							),
							const SizedBox(height: 12),

							Expanded(
								child: StreamBuilder<List<DiscoveredPeers>>(
									stream: _p2pService.deviceStream,
									builder: (context, snapshot) {
										if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
											return const Center(
												child: CircularProgressIndicator(),
											);
										}

										if (snapshot.hasError) {
											return Center(
												child: Text(
													'Error: ${snapshot.error}',
													style: const TextStyle(color: Colors.white70),
												),
											);
										}

										final devices = snapshot.data ?? [];

										if (devices.isEmpty) {
											return Center(
												child: Text(
													_isDiscovering ? 'Searching for devices...' : 'No devices found',
													style: const TextStyle(color: Colors.white70),
												),
											);
										}

										return ListView.builder(
											itemCount: devices.length,
											padding: const EdgeInsets.only(bottom: 8),
											itemBuilder: (context, index) {
												final device = devices[index];

												return Padding(
													padding: const EdgeInsets.symmetric(vertical: 8),
													child: Card(
														color: _cardColor,
														shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
														child: Padding(
															padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
															child: Row(
																children: [
																	Container(
																		width: 56,
																		height: 56,
																		decoration: BoxDecoration(
																			color: Colors.white10,
																			borderRadius: BorderRadius.circular(12),
																		),
																		child: const Icon(Icons.device_hub, color: Colors.white70),
																	),
																	const SizedBox(width: 12),

																	Expanded(
																		child: Column(
																			crossAxisAlignment: CrossAxisAlignment.start,
																			children: [
																				Text(
																					device.deviceName ?? 'Unknown Device',
																					style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
																					maxLines: 1,
																					overflow: TextOverflow.ellipsis,
																				),
																				const SizedBox(height: 6),
																				Row(
																					children: [
																						const Icon(Icons.signal_cellular_4_bar, color: Colors.white70, size: 16),
																						const SizedBox(width: 8),
																						Row(
																							children: [
																								Icon(
																									Icons.circle,
																									color: device.isGroupOwner == true ? _accentGreen : Colors.orange,
																									size: 12,
																								),
																								const SizedBox(width: 6),
																								Text(
																									device.isGroupOwner == true ? 'Group Owner' : 'Client',
																									style: const TextStyle(color: Colors.white70, fontSize: 12),
																								),
																							],
																						),
																					],
																				),
																				const SizedBox(height: 4),
																				Text(
																					'Address: ${device.deviceAddress}',
																					style: const TextStyle(color: Colors.white54, fontSize: 10),
																					maxLines: 1,
																					overflow: TextOverflow.ellipsis,
																				),
																			],
																		),
																	),

																	Row(
																		mainAxisSize: MainAxisSize.min,
																		children: [
																			ElevatedButton(
																				onPressed: () {
																					Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatPage()));
																				},
																				style: ElevatedButton.styleFrom(
																					backgroundColor: Colors.white12,
																					elevation: 0,
																					shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
																					padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
																				),
																				child: const Text('Message', style: TextStyle(color: Colors.white)),
																			),
																			const SizedBox(width: 8),
																			ElevatedButton(
																				onPressed: () => _p2pService.connect(device.deviceAddress ?? ''),
																				style: ElevatedButton.styleFrom(
																					backgroundColor: _accentRed,
																					elevation: 2,
																					shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
																					padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
																				),
																				child: const Text('Connect', style: TextStyle(color: Colors.white)),
																			),
																		],
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

							Padding(
								padding: const EdgeInsets.symmetric(vertical: 8),
								child: Center(
									child: Text(
										_permissionsGranted ? 'Peer-to-Peer Network Active' : 'Permissions required to enable P2P',
										style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
									),
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
						onPressed: _isDiscovering ? _stopDiscovery : _startDiscovery,
						backgroundColor: Colors.blueGrey[800],
						mini: true,
						child: Icon(_isDiscovering ? Icons.stop : Icons.refresh),
						tooltip: _isDiscovering ? 'Stop scanning' : 'Rescan devices',
					),
					const SizedBox(height: 10),
					FloatingActionButton(
						onPressed: () {},
						backgroundColor: _accentRed,
						child: const Icon(Icons.mic, color: Colors.white),
						tooltip: 'Voice commands',
					),
				],
			),
		);
	}
}

