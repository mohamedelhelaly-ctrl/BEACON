# Wi-Fi Direct Database Sync Implementation

## Overview
Simple database sync between host and client using JSON messages over P2P text messaging.

## Changes Made

### 1. DatabaseHelper (`lib/database/database_helper.dart`)

Added two new methods:

#### `buildEventSync()` 
- Reads the active event, all connected devices, event connections, and logs
- Returns a complete sync object as JSON:
  ```json
  {
    "type": "EVENT_SYNC",
    "event": { ... },
    "devices": [ ... ],
    "connections": [ ... ],
    "logs": [ ... ]
  }
  ```
- Returns `null` if no active event exists

#### `importEventSync(Map<String, dynamic> syncData)`
- Takes the sync object from the host
- Uses transactions to atomically upsert:
  - **events** table (INSERT OR REPLACE by id)
  - **devices** table (INSERT OR REPLACE by id)
  - **event_connections** table (INSERT OR REPLACE by id)
  - **logs** table (INSERT OR REPLACE by id)
- Safely handles null/missing fields in sync data

### 2. P2PHostService (`lib/services/p2p_service.dart`)

Added method:

#### `sendEventSync(Map<String, dynamic> syncData)`
- Encodes the sync object to JSON using `jsonEncode()`
- Broadcasts the JSON string to all connected clients via `broadcastText()`
- Catches and rethrows any encoding errors

**Note**: Added `import 'dart:convert';` at the top of the file to enable JSON encoding.

### 3. P2PClientService (`lib/services/p2p_service.dart`)

Added method:

#### `parseMessage(String rawMessage)`
- Attempts to decode the message as JSON
- If it contains `"type": "EVENT_SYNC"`, returns the decoded map
- Otherwise returns `null` (regular text message)
- Silently handles JSON decode errors (returns null)

### 4. NetworkDashboard (`lib/pages/networkDashboard.dart`)

#### Host Integration
Modified `_initHost()`:
- When the client list changes, calls `_sendEventSync()` after updating connections
- This ensures clients get the latest database state whenever they connect

Added `_sendEventSync()` method:
- Calls `buildEventSync()` from the database
- Sends the sync data using `hostService.sendEventSync()`
- Logs the sync action for debugging

#### Client Integration
Modified `_initClient()`:
- Message stream listener now parses each message
- If it's an EVENT_SYNC message, calls `_handleEventSync()`
- Otherwise displays it as a regular message

Added `_handleEventSync(Map<String, dynamic> syncData)` method:
- Imports the sync data using `importEventSync()`
- Refreshes the provider's active event, connections, and logs
- Shows a snackbar notification
- Logs errors if anything fails

## How It Works

### Flow: Client Connects to Host

1. **Client discovers and connects to host** via BLE/Wi-Fi Direct
2. **Host detects new connection** in `clientStream()`
3. **Host triggers `_sendEventSync()`** which:
   - Reads all event data from SQLite
   - Converts to JSON
   - Broadcasts via `broadcastText()`
4. **Client receives the message** in message stream
5. **Client parses the message** - recognizes `"type": "EVENT_SYNC"`
6. **Client imports the sync data** via `importEventSync()`:
   - Upserts event, devices, connections, logs
   - Updates provider state
7. **Client UI updates** with synced data

## Key Features

✅ **Simple**: No delta sync, binary transfer, or complex logic
✅ **Atomic**: Uses database transactions for upsert operations
✅ **Robust**: INSERT OR REPLACE prevents duplicate key errors
✅ **Safe**: Null-safe JSON parsing, error handling
✅ **Stateless**: Each sync is a complete snapshot
✅ **Lightweight**: Single JSON message per sync

## Limitations

- **No incremental sync**: Full event data sent every time (OK for small datasets)
- **No conflict resolution**: Incoming data always overwrites local data
- **No compression**: JSON string sent as-is
- **No ACK**: No confirmation that client received/processed sync
- **No bandwidth optimization**: All fields sent even if unchanged

## Testing

1. Start host on Device A
2. Start client on Device B
3. Connect Device B to Device A's Wi-Fi Direct group
4. Verify Device B receives EVENT_SYNC message
5. Check Device B's database for synced event, devices, connections, logs
6. Add new log message or device on host
7. Trigger another sync and verify client receives updates

## Files Modified

- `lib/database/database_helper.dart` - Added sync import/export functions
- `lib/services/p2p_service.dart` - Added sync message sending and parsing
- `lib/pages/networkDashboard.dart` - Added sync triggers on connect/receive

No breaking changes to existing code.
