import 'package:flutter/material.dart';
import 'chatPage.dart';

class NetworkDashboardUI extends StatelessWidget {
	const NetworkDashboardUI({Key? key}) : super(key: key);

	static const Color _bgColor = Color(0xFF0F1724);
	static const Color _cardColor = Color(0xFF16202B);
	static const Color _accentRed = Color(0xFFEF4444);
	static const Color _accentGreen = Color(0xFF10B981);

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
					children: const [
						Text('Network Dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
						SizedBox(height: 2),
						Text('Connected Devices', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
								child: ListView.builder(
									itemCount: 6,
									padding: const EdgeInsets.only(bottom: 8),
									itemBuilder: (context, index) {
										final deviceNames = [
											'Rescue Unit A',
											'Field Node 12',
											'Volunteer B',
											'Command Post',
											'Sensor Hub',
											'Medic Team 3'
										];

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
																			deviceNames[index],
																			style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
																		),
																		const SizedBox(height: 6),
																		Row(
																			children: [
																				const Icon(Icons.signal_cellular_4_bar, color: Colors.white70, size: 16),
																				const SizedBox(width: 8),
																				Row(
																					children: [
																						Icon(Icons.circle, color: _accentGreen, size: 12),
																						const SizedBox(width: 6),
																						const Text('Connected', style: TextStyle(color: Colors.white70, fontSize: 12)),
																					],
																				),
																			],
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
																		onPressed: () {},
																		style: ElevatedButton.styleFrom(
																			backgroundColor: _accentRed,
																			elevation: 2,
																			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
																			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
																		),
																		child: const Text('SOS', style: TextStyle(color: Colors.white)),
																	),
																],
															),
														],
													),
												),
											),
										);
									},
								),
							),

							Padding(
								padding: const EdgeInsets.symmetric(vertical: 8),
								child: Center(
									child: Text(
										'Peer-to-Peer Network Active',
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
						onPressed: () {},
						backgroundColor: Colors.blueGrey[800],
						mini: true,
						child: const Icon(Icons.refresh),
						tooltip: 'Rescan devices',
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

