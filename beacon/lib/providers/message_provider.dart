import 'package:flutter/material.dart';

/// Simple data class to represent a message
class ChatMessage {
  final String id;          // Unique message ID (timestamp-based)
  final String senderName;  // Name of the sender
  final String senderId;    // Unique ID of the sender device
  final String text;        // Message content
  final DateTime timestamp; // When the message was sent/received
  final bool isMine;        // True if this device sent it, false if received

  ChatMessage({
    required this.id,
    required this.senderName,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isMine,
  });
}

/// Provider to manage real-time messaging state
class MessageProvider extends ChangeNotifier {
  List<ChatMessage> _messages = [];
  String? _currentDeviceId;
  String? _currentDeviceName;

  // Getters
  List<ChatMessage> get messages => _messages;
  String? get currentDeviceId => _currentDeviceId;
  String? get currentDeviceName => _currentDeviceName;

  /// Initialize with current device info
  void initialize(String deviceId, String deviceName) {
    _currentDeviceId = deviceId;
    _currentDeviceName = deviceName;
  }

  /// Add a received message to the list
  void addReceivedMessage(
    String senderName,
    String senderId,
    String text,
  ) {
    final message = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_$senderId',
      senderName: senderName,
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
      isMine: false,
    );
    _messages.add(message);
    notifyListeners();
  }

  /// Add a sent message to the list
  void addSentMessage(String text) {
    if (_currentDeviceId == null || _currentDeviceName == null) return;

    final message = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_$_currentDeviceId',
      senderName: _currentDeviceName!,
      senderId: _currentDeviceId!,
      text: text,
      timestamp: DateTime.now(),
      isMine: true,
    );
    _messages.add(message);
    notifyListeners();
  }

  /// Clear all messages (useful for leaving an event)
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  /// Get formatted time string for a message
  String getFormattedTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
