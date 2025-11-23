# BEACON P2P WiFi Direct - Complete Testing Procedure

## Pre-Testing Checklist

- [ ] Two Android phones with Android 8.0+ (API 26+)
- [ ] Both phones support WiFi Direct
- [ ] USB cables for both phones (for adb debugging)
- [ ] Flutter SDK installed and working
- [ ] Android SDK tools updated
- [ ] Both phones charged (battery drain from scanning)

---

## Step 1: Prepare Your Development Environment

```bash
# Navigate to project
cd "d:\ASU\sem 9\MP\Project\BEACON\beacon"

# Get latest dependencies
flutter pub get

# List connected devices
flutter devices

# You should see both phones listed
```

---

## Step 2: Prepare Phone 1 (HOST)

### Device Setup
1. **Unlock the phone**
2. **Enable Developer Options** (tap Build Number 7 times in Settings > About Phone)
3. **Enable USB Debugging** (Settings > Developer Options > USB Debugging)
4. **Connect to computer via USB**
5. **Allow USB Debugging** when prompted
6. **Enable WiFi** (doesn't need internet, just enabled)
7. **Enable Bluetooth**
8. **Enable Location Services**

### Deploy App
```bash
# Get device ID
flutter devices

# Build and run on Phone 1 (replace DEVICE_ID)
flutter run -d DEVICE_ID_1

# Wait for app to load and appear on Phone 1's screen
```

---

## Step 3: Prepare Phone 2 (CLIENT)

### Device Setup
1. **Unlock the phone**
2. **Enable Developer Options** (tap Build Number 7 times)
3. **Enable USB Debugging**
4. **Enable WiFi**
5. **Enable Bluetooth**
6. **Enable Location Services**

### Deploy App
```bash
# In new terminal window
cd "d:\ASU\sem 9\MP\Project\BEACON\beacon"

# Run on Phone 2
flutter run -d DEVICE_ID_2

# Wait for app to load
```

---

## Step 4: Start WiFi Direct Group (HOST PHONE)

### On Phone 1:
1. **App loads** → You see landing page with two buttons
2. **Tap "Start New Communication"**
3. **Permissions Dialog** appears → **Tap "Allow" for each permission**
4. **Services Dialog** may appear → **Tap "Enable"** for each service
5. **Wait 3-5 seconds** for WiFi Direct group to create
6. **Screen shows:**
   - WiFi icon badge with green checkmark
   - SSID (e.g., `DIRECT_ABCD1234`)
   - Password (PSK)
   - Host IP Address (usually `192.168.49.1`)
   - Section "Connected Devices" (empty initially)

### Expected Log Output:
```
I/flutter: Group created - SSID: DIRECT_ABCD1234, PSK: abcdef1234, IP: 192.168.49.1
I/flutter: Hotspot state: Active=true
I/flutter: BLE advertising started
```

✅ **If you see this, Host setup is successful!**

---

## Step 5: Discover and Connect (CLIENT PHONE)

### On Phone 2:
1. **App loads** → Landing page
2. **Tap "Join Existing Communication"**
3. **Permissions Dialog** → **Allow all**
4. **Services Dialog** → **Enable all**
5. **Wait for Network Dashboard to load**
6. **Tap the "Scan" button** (floating action button with refresh icon)
7. **Status changes to "Scanning for hosts..."**
8. **Wait 5-10 seconds** (BLE scan takes time)

### After Scan Completes:
- **Host Phone should appear** in the "Available Hosts" list
- Shows device name and MAC address
- **Tap "Connect"** button

### During Connection:
```
"Scanning for hosts..."
↓
[Host Device appears]
↓
[Tap Connect]
↓
"Connecting..."
↓
Connected! (shows Host IP)
```

### Expected Log Output:
```
I/flutter: Discovered 1 devices
I/flutter: Connecting to DIRECT_ABCD1234...
I/flutter: Client: Connected to BLE device
I/flutter: Client: Received SSID via BLE: DIRECT_ABCD1234
I/flutter: Client: Received PSK via BLE
I/flutter: Client: Attempting to connect to hotspot
I/flutter: Client state: Active=true, IP=192.168.49.X
```

✅ **Connection successful!**

---

## Step 6: Verify Connection

### On Host Phone:
- Tap the **info icon** (i) in top right
- You should see:
  ```
  Mode: Host (Group Owner)
  SSID: DIRECT_ABCD1234
  PSK: [password]
  Host IP: 192.168.49.1
  ```
- Scroll down to "Connected Devices"
- **Client phone should appear** in the list with green checkmark
- Shows client's username

### On Client Phone:
- Tap the **info icon** (i) in top right
- You should see:
  ```
  Mode: Client
  Host IP: 192.168.49.1
  ```

✅ **Both devices should see each other!**

---

## Step 7: Test Messaging

### From Host Phone:
1. Tap **"Chat"** button (bottom right)
2. Type a test message
3. Tap send
4. Check **Client phone** - message should appear

### From Client Phone:
1. Tap **"Chat"** button
2. Type a test message
3. Tap send
4. Check **Host phone** - message should appear

✅ **Bidirectional messaging works!**

---

## Step 8: Advanced Testing (Optional)

### Test Host/Client Role Reversal
1. **Disconnect** client from host
2. **On Phone 2**, start new communication (become Host)
3. **On Phone 1**, join communication (become Client)
4. Verify connection works

### Test Distance Limitations
1. Establish connection
2. **Slowly move phones apart** while connected
3. Note when connection drops (usually 50-100m for BLE)

### Test Multiple Clients
1. **Keep Phone 2 connected** (as Client 1)
2. **Connect Phone 1 as Host**
3. Try connecting a **3rd phone** (if available)
4. Verify Host sees all connected clients

### Test Connection Stability
1. Establish connection
2. **Disable Bluetooth** on client, re-enable
3. Verify reconnection works
4. **Disable WiFi**, re-enable
5. Verify connection restores

---

## Troubleshooting During Testing

### Issue: "Permissions required"
**On the affected phone:**
1. Go to `Settings > Apps > BEACON > Permissions`
2. Manually enable all permissions:
   - Location
   - Bluetooth
   - Storage (if file transfer)
3. Go back to the app and try again

### Issue: "Scanning but no devices found"
**Checklist:**
1. Is **Host phone still running**?
2. Is **Bluetooth enabled** on both phones?
3. Is **Location enabled** on client phone?
4. Are phones **close together** (within 10 meters)?
5. **Kill and restart** Host app first

**Still not working?**
```bash
# Check logs
adb logcat | grep "flutter_p2p_connection"

# Restart phone
adb reboot
```

### Issue: "Connection times out"
**Causes:**
- Phones too far apart (BLE range limited)
- Network interference
- WiFi interference

**Solutions:**
1. Bring phones **closer together**
2. Move away from other WiFi networks
3. **Restart both apps**
4. Wait longer (connection can take 30+ seconds)

### Issue: "Connected but can't message"
**Likely cause:** P2P transport layer not initialized

**Solution:**
1. **Disconnect** both phones
2. **Kill and restart** Host app
3. **Then connect** Client app
4. Try messaging again

### Issue: App keeps crashing
**Solution:**
```bash
flutter clean
flutter pub get
flutter run -d DEVICE_ID --verbose
```

Check for error messages in verbose output.

---

## Success Criteria

✅ **Basic Connection Success:**
- [ ] Host phone creates WiFi Direct group
- [ ] Host phone displays SSID, PSK, IP
- [ ] Client phone discovers host via BLE scan
- [ ] Client phone connects to host
- [ ] Both phones see each other as connected

✅ **Advanced Success:**
- [ ] Messages send from Host to Client
- [ ] Messages send from Client to Host
- [ ] Client phone displays Host IP
- [ ] Multiple clients can connect (if available)
- [ ] Disconnection and reconnection works

---

## Data to Record

For your project documentation, record:

```
Test Date: [DATE]
Device 1 (HOST):
  - Model: [e.g., Samsung Galaxy A12]
  - Android Version: [e.g., Android 11]
  - IP Address: [e.g., 192.168.49.1]

Device 2 (CLIENT):
  - Model: [e.g., OnePlus 9]
  - Android Version: [e.g., Android 12]
  - IP Address: [e.g., 192.168.49.X]

Successful Connection: Yes/No
Message Exchange Working: Yes/No
Connection Stability: [Notes]
Issues Encountered: [List any]
Fixes Applied: [List any]
```

---

## Performance Notes

### Expected Performance
- **BLE Scan Time**: 5-15 seconds
- **Connection Time**: 10-30 seconds
- **Message Latency**: <100ms
- **Battery Drain**: ~5-10% per hour (during active scanning)

### Optimal Conditions
- Devices within 10 meters
- No WiFi network interference
- Both devices stationary
- Bluetooth enabled
- Location enabled

---

## Next Steps After Successful Testing

1. **Document Results** - Record successful connection details
2. **Test File Transfer** - Implement file sharing feature
3. **Test Multiple Clients** - Verify group management
4. **Optimize BLE** - Reduce scan power consumption
5. **Add QR Code** - Enable credential sharing via QR
6. **Production Build** - Build release APK for deployment

---

## Emergency Debugging

If something goes wrong and you need detailed logs:

```bash
# Real-time logs
adb logcat | grep -i "p2p\|flutter"

# Save logs to file
adb logcat > logs.txt

# Check specific error
adb logcat | grep -i "error\|exception"

# Reset device
adb reboot

# Clear app data
adb shell pm clear com.beacon.app
```

---

## Contact & Support

If you encounter issues not covered here:

1. Check the `P2P_TESTING_GUIDE.md` for detailed API documentation
2. Review flutter_p2p_connection GitHub: https://github.com/ugo-studio/flutter_p2p_connection
3. Check Android logcat for platform-specific errors
4. Verify all permissions are granted in device settings

---

**Good luck with your testing! 🚀**

Status: Ready for production after successful testing
Date: 2025-11-23
