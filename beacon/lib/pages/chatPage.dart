import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/message_provider.dart';
import '../services/p2p_service.dart';

class ChatPage extends StatefulWidget {
  final bool isHost;
  final P2PHostService? hostService;
  final P2PClientService? clientService;

  const ChatPage({
    Key? key,
    required this.isHost,
    this.hostService,
    this.clientService,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late TextEditingController _messageController;

  static const Color _bgColor = Color(0xFF0F1724);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentOrange = Color(0xFFFF8A4B);

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Widget _buildAvatar({bool isMine = false, String name = 'Contact'}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isMine 
            ? [_accentRed]
            : [Color(0xFF263244), Color(0xFF0F1724)],
        ),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Center(
        child: Text(
          isMine ? 'M' : (name.isNotEmpty ? name[0].toUpperCase() : '?'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildMessage({
    required bool isMine,
    required String senderName,
    required String text,
    required String time,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine) _buildAvatar(name: senderName),
          if (!isMine) const SizedBox(width: 12),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isMine ? _accentRed : null,
                gradient: isMine
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF263244), Color(0xFF0F1724)],
                      ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMine) const SizedBox(width: 12),
          if (isMine) _buildAvatar(isMine: true),
        ],
      ),
    );
  }

  Widget _buildQuickMessageChip(String message) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: () {
          _sendMessage(message);
        },
        backgroundColor: Color(0xFF263244),
        side: BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    try {
      final messageProvider = Provider.of<MessageProvider>(context, listen: false);
      
      // Add to local message list
      messageProvider.addSentMessage(text);

      // Send via P2P
      if (widget.isHost) {
        await widget.hostService?.sendMessage(text);
      } else {
        await widget.clientService?.sendMessage(text);
      }

      // Clear input
      _messageController.clear();
    } catch (e) {
      debugPrint('Send message error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageProvider = Provider.of<MessageProvider>(context);
    final contactName = messageProvider.currentDeviceName ?? 'Contact';

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).maybePop();
          },
          tooltip: 'Back',
        ),
        title: Row(
          children: [
            _buildAvatar(name: contactName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contactName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Online',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messageProvider.messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: messageProvider.messages.length,
                    itemBuilder: (context, index) {
                      final msg = messageProvider.messages[index];
                      return _buildMessage(
                        isMine: msg.isMine,
                        senderName: msg.senderName,
                        text: msg.text,
                        time: messageProvider.getFormattedTime(msg.timestamp),
                      );
                    },
                  ),
          ),

          // Quick message chips
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                'I am safe',
                'Need help',
                'On my way',
                'Medical emergency',
                'Share location',
                'All clear'
              ].map((msg) => _buildQuickMessageChip(msg)).toList(),
            ),
          ),

          // Message input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF1A2332),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                // Voice message button (placeholder)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_accentRed, _accentOrange],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.mic, color: Colors.white),
                    onPressed: () {
                      // Voice feature not implemented yet
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Voice messages coming soon')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Text input
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Color(0xFF263244),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Type message...',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (text) => _sendMessage(text),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Send button
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_accentOrange, _accentRed],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () => _sendMessage(_messageController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}