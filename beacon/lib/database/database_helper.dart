import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    Directory dir = await getApplicationDocumentsDirectory();
    String dbPath = join(dir.path, "beacon_secure.db");

    return await openDatabase(
      dbPath,
      password: "12345",
      version: 1,
      onCreate: _createDB
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute("PRAGMA foreign_keys = ON");

    // ============= DEVICES TABLE =============
    await db.execute('''
      CREATE TABLE devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_uuid TEXT UNIQUE,
        name TEXT,
        is_host INTEGER,
        created_at TEXT
      )
    ''');

    // ============= EVENTS TABLE =============
    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        host_id INTEGER,
        ssid TEXT,
        password TEXT,
        host_ip TEXT,
        started_at TEXT,
        ended_at TEXT,
        FOREIGN KEY(host_id) REFERENCES devices(id)
      )
    ''');

    // ============= EVENT_CONNECTIONS TABLE =============
    await db.execute('''
      CREATE TABLE event_connections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id INTEGER,
        device_id INTEGER,
        joined_at TEXT,
        last_seen TEXT,
        is_current INTEGER,
        FOREIGN KEY(event_id) REFERENCES events(id),
        FOREIGN KEY(device_id) REFERENCES devices(id)
      )
    ''');

    // ============= LOGS TABLE =============
    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id INTEGER,
        device_id INTEGER,
        message TEXT,
        timestamp TEXT,
        FOREIGN KEY(event_id) REFERENCES events(id),
        FOREIGN KEY(device_id) REFERENCES devices(id)
      )
    ''');
  }

  // =====================================================
  //                     DEVICES CRUD
  // =====================================================

  Future<int> insertDevice(String uuid, String name, bool isHost) async {
    final db = await database;

    return await db.insert(
      "devices",
      {
        'device_uuid': uuid,
        'name': name,
        'is_host': isHost ? 1 : 0,
        'created_at': DateTime.now().toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getDeviceByUUID(String uuid) async {
    final db = await database;
    final res = await db.query(
      "devices",
      where: "device_uuid = ?",
      whereArgs: [uuid],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<Map<String, dynamic>?> getDeviceById(int id) async {
    final db = await database;
    final res = await db.query(
      "devices",
      where: "id = ?",
      whereArgs: [id],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> deleteDevice(int deviceId) async {
    final db = await database;
    await db.delete(
      "devices",
      where: "id = ?",
      whereArgs: [deviceId],
    );
  }

  // =====================================================
  //                     EVENTS CRUD
  // =====================================================

  Future<int> createEvent(int hostId, String ssid, String pwd, String ip) async {
    final db = await database;

    return await db.insert("events", {
      "host_id": hostId,
      "ssid": ssid,
      "password": pwd,
      "host_ip": ip,
      "started_at": DateTime.now().toString(),
      "ended_at": null,
    });
  }

  Future<void> endEvent(int eventId) async {
    final db = await database;

    await db.update(
      "events",
      {"ended_at": DateTime.now().toString()},
      where: "id = ?",
      whereArgs: [eventId],
    );
  }

  Future<Map<String, dynamic>?> getActiveEvent() async {
    final db = await database;

    final res = await db.query(
      "events",
      where: "ended_at IS NULL",
      limit: 1,
    );

    return res.isNotEmpty ? res.first : null;
  }

  // =====================================================
  //              EVENT CONNECTIONS CRUD
  // =====================================================

  Future<int> addDeviceConnection(int eventId, int deviceId) async {
    final db = await database;

    return await db.insert("event_connections", {
      "event_id": eventId,
      "device_id": deviceId,
      "joined_at": DateTime.now().toString(),
      "last_seen": DateTime.now().toString(),
      "is_current": 1,
    });
  }

  Future<void> updateLastSeen(int connectionId) async {
    final db = await database;
    await db.update(
      "event_connections",
      {"last_seen": DateTime.now().toString()},
      where: "id = ?",
      whereArgs: [connectionId],
    );
  }

  Future<void> disconnectConnection(int connectionId) async {
    final db = await database;
    await db.update(
      "event_connections",
      {"is_current": 0},
      where: "id = ?",
      whereArgs: [connectionId],
    );
  }

  Future<List<Map<String, dynamic>>> getActiveEventConnections(int eventId) async {
    final db = await database;

    return await db.query(
      "event_connections",
      where: "event_id = ? AND is_current = 1",
      whereArgs: [eventId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllConnectedDevicesInEvent(int eventId) async {
    final db = await database;

    return await db.rawQuery('''
      SELECT devices.id, devices.device_uuid, devices.name, devices.is_host, devices.created_at
      FROM devices
      JOIN event_connections
      ON devices.id = event_connections.device_id
      WHERE event_connections.event_id = ?
    ''', [eventId]);
  }

  // =====================================================
  //                     LOGS CRUD
  // =====================================================

  Future<int> insertLog(int deviceId, int? eventId, String message) async {
    final db = await database;

    return await db.insert("logs", {
      "device_id": deviceId,
      "event_id": eventId,
      "message": message,
      "timestamp": DateTime.now().toString(),
    });
  }

  Future<List<Map<String, dynamic>>> getEventLogs(int eventId) async {
    final db = await database;

    return await db.query(
      "logs",
      where: "event_id = ?",
      whereArgs: [eventId],
      orderBy: "timestamp DESC",
    );
  }

  // =====================================================
  //                  SYNC IMPORT
  // =====================================================

  /// Import synced event data from host
  /// Upserts event, devices, connections, and logs
  Future<void> importEventSync(Map<String, dynamic> syncData) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // Upsert event
        if (syncData['event'] != null) {
          final event = syncData['event'] as Map<String, dynamic>;
          try {
            await txn.insert(
              "events",
              {
                'id': event['id'],
                'host_id': event['host_id'],
                'ssid': event['ssid'],
                'password': event['password'],
                'host_ip': event['host_ip'],
                'started_at': event['started_at'],
                'ended_at': event['ended_at'],
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (e) {
            debugPrint('Error upserting event: $e');
            rethrow;
          }
        }

        // Upsert devices
        if (syncData['devices'] != null) {
          final devices = syncData['devices'] as List<dynamic>;
          debugPrint('Importing ${devices.length} devices...');
          for (final device in devices) {
            final deviceMap = device as Map<String, dynamic>;
            try {
              await txn.insert(
                "devices",
                {
                  'id': deviceMap['id'],
                  'device_uuid': deviceMap['device_uuid'],
                  'name': deviceMap['name'],
                  'is_host': deviceMap['is_host'],
                  'created_at': deviceMap['created_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (e) {
              debugPrint('Error upserting device ${deviceMap['id']}: $e');
            }
          }
        }

        // Upsert event connections
        if (syncData['connections'] != null) {
          final connections = syncData['connections'] as List<dynamic>;
          debugPrint('Importing ${connections.length} connections...');
          for (final conn in connections) {
            final connMap = conn as Map<String, dynamic>;
            try {
              await txn.insert(
                "event_connections",
                {
                  'id': connMap['id'],
                  'event_id': connMap['event_id'],
                  'device_id': connMap['device_id'],
                  'joined_at': connMap['joined_at'],
                  'last_seen': connMap['last_seen'],
                  'is_current': connMap['is_current'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (e) {
              debugPrint('Error upserting connection ${connMap['id']}: $e');
            }
          }
        }

        // Upsert logs
        if (syncData['logs'] != null) {
          final logs = syncData['logs'] as List<dynamic>;
          debugPrint('Importing ${logs.length} logs...');
          for (final log in logs) {
            final logMap = log as Map<String, dynamic>;
            try {
              await txn.insert(
                "logs",
                {
                  'id': logMap['id'],
                  'event_id': logMap['event_id'],
                  'device_id': logMap['device_id'],
                  'message': logMap['message'],
                  'timestamp': logMap['timestamp'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (e) {
              debugPrint('Error upserting log ${logMap['id']}: $e');
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Transaction failed: $e');
      rethrow;
    }
  }

  /// Build a sync object from current active event
  /// Returns null if no active event
  Future<Map<String, dynamic>?> buildEventSync() async {
    final event = await getActiveEvent();
    if (event == null) return null;

    final eventId = event['id'] as int;
    final devices = await getAllConnectedDevicesInEvent(eventId);
    final connections = await getActiveEventConnections(eventId);
    final logs = await getEventLogs(eventId);

    return {
      'type': 'EVENT_SYNC',
      'event': event,
      'devices': devices,
      'connections': connections,
      'logs': logs,
    };
  }
}
