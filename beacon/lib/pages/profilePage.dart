import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- MOCK PROVIDER FOR DUMMY DATA ---
// (Paste this class at the bottom of your file or keep it here for testing)
class BeaconProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? get user => _user;

  // Mock Database helper
  final _MockDB db = _MockDB();

  Future<void> loadUser() async {
    // Simulate loading delay
    await Future.delayed(const Duration(milliseconds: 800));
    _user = {
      'name': 'Alex Mercer',
      'emergency_contact': '+1 (555) 019-2834',
    };
    notifyListeners();
  }

  void addLog(String log) {
    print("Log added: $log");
  }
}

class _MockDB {
  Future<dynamic> getUser() async => null;
  Future<void> updateUser(String n, String e) async {}
  Future<void> insertUser(String n, String e) async {}
}
// -------------------------------------

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _bgColor = Color(0xFF0F1724);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentOrange = Color(0xFFFF8A4B);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emergencyController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    // --- DUMMY DATA INJECTION START ---
    print('Loading Dummy Data...');
    
    // Simulate network/db delay
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    setState(() {
      _nameController.text = "Alex Mercer";
      _emergencyController.text = "+1 (555) 019-2834";
      // Optional: If you had a phone field
      _phoneController.text = "+1 (555) 123-4567"; 
    });
    // --- DUMMY DATA INJECTION END ---
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isNotEmpty && _emergencyController.text.isNotEmpty) {
      print('[ProfilePage] Saving profile: ${_nameController.text}');

      // --- SIMULATED SAVE START ---
      await Future.delayed(const Duration(seconds: 1)); // Fake saving delay
      
      if (mounted) {
        setState(() {
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully! (Simulated)'),
            backgroundColor: Colors.green,
          ),
        );
      }
      // --- SIMULATED SAVE END ---
      
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
    }
  }

  Widget _buildProfileField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF263244), Color(0xFF1A2332)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_accentRed, _accentOrange],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF263244), Color(0xFF1A2332)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentOrange, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_accentRed, _accentOrange],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              cursorColor: _accentOrange,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(
                  color: _accentOrange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: _accentOrange),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emergencyController.dispose();
    super.dispose();
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
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isEditing ? Icons.check_circle : Icons.edit,
              color: _isEditing ? Colors.green : _accentOrange,
              size: 28,
            ),
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
            tooltip: _isEditing ? 'Save Profile' : 'Edit Profile',
          ),
        ],
      ),
      // Wrapped in consumer, but using dummy data in local state
      body: Consumer<BeaconProvider>(
        builder: (context, beaconProvider, child) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Profile Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_accentRed, _accentOrange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white24, width: 3),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 60,
                  ),
                ),

                const SizedBox(height: 40),

                // Name Field
                _isEditing
                    ? _buildEditableField(
                        label: 'NAME',
                        controller: _nameController,
                        icon: Icons.person_outline,
                      )
                    : _buildProfileField(
                        label: 'NAME',
                        value: _nameController.text.isNotEmpty 
                            ? _nameController.text 
                            : 'Not set',
                        icon: Icons.person_outline,
                      ),

                // Emergency Contact Field
                _isEditing
                    ? _buildEditableField(
                        label: 'EMERGENCY CONTACT',
                        controller: _emergencyController,
                        icon: Icons.emergency_outlined,
                      )
                    : _buildProfileField(
                        label: 'EMERGENCY CONTACT',
                        value: _emergencyController.text.isNotEmpty
                            ? _emergencyController.text
                            : 'Not set',
                        icon: Icons.emergency_outlined,
                      ),

                const SizedBox(height: 40),

                // Medical Information Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      beaconProvider.addLog('Medical Information Accessed');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Activity logged')),
                      );
                    },
                    icon: const Icon(Icons.medical_services, color: Colors.white),
                    label: const Text(
                      'Medical Information',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: _accentRed, width: 2),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // View Database Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Debug DB Page is stubbed')),
                      );
                    },
                    icon: const Icon(Icons.bug_report, color: Colors.white),
                    label: const Text(
                      'View Database',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.white38, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}