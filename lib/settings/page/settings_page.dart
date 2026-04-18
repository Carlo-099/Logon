import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:logon/services/firebase_service.dart';
import 'package:logon/settings/widgets/wifi_networks_sheet.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _firebaseService = FirebaseService();
  bool _isLoading = true;
  bool _isDarkMode = true;
  String _selectedTextSize = 'medium';
  List<Map<String, dynamic>> _wifiConfigs = [];

  static const _darkGreen = Color(0xFF0B5D3B);
  static const _pageBackground = Color(0xFFF4F8F5);
  static const _cardBackground = Colors.white;
  static const _dangerRed = Color(0xFFB23A3A);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final uid = _firebaseService.getCurrentUserId();
      if (uid != null) {
        final db = FirebaseDatabase.instance.ref().child('profiling').child(uid);
        final dm = await db.child('isDarkMode').get();
        final ts = await db.child('textSize').get();
        final wifi = await _firebaseService.getUserWifiConfigs();
        if (!mounted) return;
        setState(() {
          _isDarkMode = dm.exists ? (dm.value as bool? ?? true) : true;
          final rawTs = ts.exists ? (ts.value?.toString() ?? 'medium') : 'medium';
          _selectedTextSize = rawTs == 'large' ? 'large' : 'medium';
          _wifiConfigs = wifi;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveThemePreference(bool isDarkMode) async {
    final userId = _firebaseService.getCurrentUserId();
    if (userId == null) return;
    try {
      await FirebaseDatabase.instance
          .ref()
          .child('profiling')
          .child(userId)
          .child('isDarkMode')
          .set(isDarkMode);
      if (mounted) setState(() => _isDarkMode = isDarkMode);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving theme: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveTextSize(String value) async {
    try {
      await _firebaseService.saveTextSize(value);
      if (!mounted) return;
      setState(() => _selectedTextSize = value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Font size updated'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving font size: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _changeDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final c = TextEditingController(text: user.displayName ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change display name'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) {
      c.dispose();
      return;
    }
    try {
      await user.updateDisplayName(c.text.trim());
      await user.reload();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name updated'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      c.dispose();
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not signed in with email/password')),
      );
      return;
    }

    final current = TextEditingController();
    final n1 = TextEditingController();
    final n2 = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
              ),
              TextField(
                controller: n1,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              TextField(
                controller: n2,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm new password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update')),
        ],
      ),
    );

    if (ok != true || !mounted) {
      current.dispose();
      n1.dispose();
      n2.dispose();
      return;
    }

    if (n1.text != n2.text) {
      current.dispose();
      n1.dispose();
      n2.dispose();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final cred = EmailAuthProvider.credential(email: user.email!, password: current.text);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(n1.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated'), backgroundColor: Colors.green),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Auth error'), backgroundColor: Colors.red),
      );
    } finally {
      current.dispose();
      n1.dispose();
      n2.dispose();
    }
  }

  Future<void> _changeEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    final email = TextEditingController();
    final pass = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change email'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current: ${user.email}', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'New email'),
              ),
              TextField(
                controller: pass,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password (re-auth)'),
              ),
              const SizedBox(height: 8),
              const Text('A verification link will be sent to the new email.', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );

    if (ok != true || !mounted) {
      email.dispose();
      pass.dispose();
      return;
    }

    try {
      final cred = EmailAuthProvider.credential(email: user.email!, password: pass.text);
      await user.reauthenticateWithCredential(cred);
      await user.verifyBeforeUpdateEmail(email.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent'), backgroundColor: Colors.green),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Error'), backgroundColor: Colors.red),
      );
    } finally {
      email.dispose();
      pass.dispose();
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete profiling data?'),
        content: const Text('This clears old questionnaire/profile fields, but keeps your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _firebaseService.deleteProfilingData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profiling data removed'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
      child: Text(
        t,
        style: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: _darkGreen,
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? color,
  }) {
    final itemColor = color ?? _darkGreen;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: itemColor.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: itemColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: itemColor),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: itemColor,
            fontWeight: FontWeight.w700,
            fontFamily: 'Georgia',
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: (color == null ? Colors.black87 : itemColor.withOpacity(0.85)),
                    fontSize: 12.5,
                  ),
                ),
              ),
        trailing: Icon(Icons.chevron_right, color: itemColor),
        onTap: onTap,
      ),
    );
  }

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: _pageBackground,
        body: const Center(
          child: CircularProgressIndicator(color: _darkGreen),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: _pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: _darkGreen,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontWeight: FontWeight.bold,
            color: _darkGreen,
          ),
        ),
      ),
      body: ListView(
        children: [
          _sectionTitle('ACCOUNT'),
          _sectionCard(
            children: [
              _tile(
                icon: Icons.person_outline,
                title: 'Change display name',
                subtitle: (user?.displayName?.isNotEmpty == true) ? user!.displayName : 'Not set',
                onTap: _changeDisplayName,
              ),
              _tile(
                icon: Icons.alternate_email,
                title: 'Change email',
                subtitle: user?.email ?? 'Not set',
                onTap: _changeEmail,
              ),
              _tile(
                icon: Icons.lock_outline,
                title: 'Change password',
                subtitle: 'Update your account password',
                onTap: _changePassword,
              ),
            ],
          ),
          _sectionTitle('CANE'),
          _sectionCard(
            children: [
              _tile(
                icon: Icons.wifi,
                title: 'WiFi Networks',
                subtitle: _wifiConfigs.isEmpty ? 'No saved networks' : '${_wifiConfigs.length} saved network(s)',
                onTap: () async {
                  await showWifiNetworksSheet(
                    context,
                    _firebaseService,
                    _wifiConfigs,
                    onLocalChanged: (updated) {
                      setState(() => _wifiConfigs = updated);
                    },
                  );
                  final fresh = await _firebaseService.getUserWifiConfigs();
                  if (mounted) setState(() => _wifiConfigs = fresh);
                },
              ),
            ],
          ),
          _sectionTitle('PREFERENCES'),
          _sectionCard(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _cardBackground,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _darkGreen.withOpacity(0.12)),
                ),
                child: SwitchListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _darkGreen.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: _darkGreen,
                    ),
                  ),
                  activeColor: _darkGreen,
                  title: Text(
                    _isDarkMode ? 'Dark mode' : 'Light mode',
                    style: const TextStyle(
                      color: _darkGreen,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Georgia',
                    ),
                  ),
                  value: _isDarkMode,
                  onChanged: _saveThemePreference,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _cardBackground,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _darkGreen.withOpacity(0.12)),
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _darkGreen.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.format_size, color: _darkGreen),
                  ),
                  title: const Text(
                    'Font size',
                    style: TextStyle(
                      color: _darkGreen,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Georgia',
                    ),
                  ),
                  subtitle: Text(_selectedTextSize == 'large' ? 'Large' : 'Medium'),
                  trailing: SegmentedButton<String>(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? _darkGreen
                            : Colors.white,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Colors.white
                            : _darkGreen,
                      ),
                      side: WidgetStateProperty.all(
                        const BorderSide(color: _darkGreen),
                      ),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(value: 'medium', label: Text('M')),
                      ButtonSegment(value: 'large', label: Text('L')),
                    ],
                    selected: {_selectedTextSize},
                    onSelectionChanged: (s) => _saveTextSize(s.first),
                  ),
                ),
              ),
            ],
          ),
          _sectionTitle('DANGER ZONE'),
          _sectionCard(
            children: [
              _tile(
                icon: Icons.delete_outline,
                color: _dangerRed,
                title: 'Delete profiling data',
                subtitle: 'Keep account, remove old profile data',
                onTap: _showDeleteConfirmation,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
