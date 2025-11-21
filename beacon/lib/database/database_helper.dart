import 'dart:io';
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
    String path = join(dir.path, "beacon.db");

    return await openDatabase(
      path,
      password: "12345",  // Database encryption password
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      print('[DatabaseHelper] Upgrading database from version $oldVersion to $newVersion');
      try {
        // Check if created_at column already exists
        final result = await db.rawQuery(
          "PRAGMA table_info(user_profile)"
        );
        bool hasCreatedAt = result.any((col) => col['name'] == 'created_at');
        
        if (!hasCreatedAt) {
          print('[DatabaseHelper] Adding created_at column to user_profile');
          await db.execute('ALTER TABLE user_profile ADD COLUMN created_at TEXT');
        }
      } catch (e) {
        print('[DatabaseHelper] Error upgrading database: $e');
      }
    }
  }

  Future _createDB(Database db, int version) async {
    // 1. User Profile Table
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        emergency_contact TEXT,
        created_at TEXT
      )
    ''');

    // 2. Devices Table (Discovered + Connected Devices)
    await db.execute('''
      CREATE TABLE devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_name TEXT,
        device_address TEXT,
        last_seen TEXT
      )
    ''');

    // 3. Activity Logs Table
    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event TEXT,
        timestamp TEXT
      )
    ''');
  }

  Future<int> insertUser(String name, String contact) async {
    final db = await instance.database;
    return await db.insert('user_profile', {
      'name': name,
      'emergency_contact': contact,
      'created_at': DateTime.now().toString()
    });
  }

  Future<int> updateUser(String name, String contact) async {
    final db = await instance.database;
    return await db.update(
      'user_profile',
      {
        'name': name,
        'emergency_contact': contact,
      },
      where: 'id = ?',
      whereArgs: [1], // Update the first user
    );
  }

  Future<Map<String, dynamic>?> getUser() async {
    final db = await instance.database;
    final res = await db.query('user_profile', limit: 1);
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<int> insertDevice(String name, String address) async {
    final db = await instance.database;
    return await db.insert('devices', {
      'device_name': name,
      'device_address': address,
      'last_seen': DateTime.now().toString(),
    });
  }

  Future<List<Map<String, dynamic>>> getDevices() async {
    final db = await instance.database;
    return await db.query('devices');
  }

  Future<int> insertLog(String event) async {
    final db = await instance.database;
    return await db.insert('logs', {
      'event': event,
      'timestamp': DateTime.now().toString()
    });
  }

  Future<List<Map<String, dynamic>>> getLogs() async {
    final db = await instance.database;
    return await db.query('logs');
  }




}
