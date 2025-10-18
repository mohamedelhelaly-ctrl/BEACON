import 'package:flutter/material.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({Key? key}) : super(key: key);

  static const Color _bgColor = Color(0xFF0F1724);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentOrange = Color(0xFFFF8A4B);

  Widget _buildAvatar({bool isMine = false, String name = 'Emergency Contact'}) {
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
          isMine ? 'M' : name[0].toUpperCase(),
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
    required String text,
    required String time,
    bool isEmergency = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine) _buildAvatar(name: 'Emergency Responder Alpha'),
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
                border: isEmergency 
                  ? Border.all(color: _accentRed, width: 2)
                  : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isEmergency)
                    Row(
                      children: [
                        Icon(Icons.warning, color: _accentRed, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'EMERGENCY',
                          style: TextStyle(
                            color: _accentRed,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  if (isEmergency) const SizedBox(height: 6),
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
        onPressed: () {},
        backgroundColor: Color(0xFF263244),
        side: BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).maybePop();
          },
          tooltip: 'Back',
        ),
        title: Row(
          children: [
            _buildAvatar(name: 'Emergency Responder Alpha'),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Responder Alpha',
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
        actions: [
          IconButton(
            icon: Icon(Icons.campaign, color: _accentRed),
            onPressed: () {},
            tooltip: 'Escalate to broadcast',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildMessage(
                  isMine: false,
                  text: 'Are you safe? The bridge is flooded.',
                  time: '15:07',
                ),
                _buildMessage(
                  isMine: true,
                  text: 'Yes, I\'m safe. Currently at the community center.',
                  time: '15:08',
                ),
                _buildMessage(
                  isMine: false,
                  text: 'Good. We have medical supplies here if needed.',
                  time: '15:10',
                ),
                _buildMessage(
                  isMine: true,
                  text: 'EMERGENCY: Need immediate assistance!',
                  time: '15:12',
                  isEmergency: true,
                ),
              ],
            ),
          ),

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
                // Voice message button
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
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Color(0xFF263244),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Type emergency message...',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

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
                    onPressed: () {},
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