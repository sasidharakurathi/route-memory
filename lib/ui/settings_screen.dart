import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../logic/settings_provider.dart';
import '../logic/auth_provider.dart';
import 'constants.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final user = FirebaseAuth.instance.currentUser;
    
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyMedium?.color;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final dividerColor = isDark ? Colors.grey[800] : Colors.grey[200];
    
    
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.cardColor,
        elevation: 0,
        foregroundColor: theme.iconTheme.color,
      ),
      body: ListView(
        
        padding: EdgeInsets.fromLTRB(16, 16, 16, 20 + bottomPadding),
        children: [
          
          _buildSectionHeader("PROFILE", subTextColor),
          Container(
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), boxShadow: kShadow),
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: kPrimaryColor.withOpacity(0.1),
                    child: const Icon(Icons.person, color: kPrimaryColor),
                  ),
                  title: Text(user?.email ?? "Guest User", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  subtitle: Text(user?.uid != null ? "ID: ${user!.uid.substring(0, 6)}..." : "Not logged in", style: TextStyle(fontSize: 10, color: subTextColor)),
                ),
                Divider(height: 1, color: dividerColor),
                ListTile(
                  leading: const Icon(Icons.logout, color: kDangerColor),
                  title: const Text("Log Out", style: TextStyle(color: kDangerColor, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(authRepositoryProvider).signOut();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          
          _buildSectionHeader("APPEARANCE", subTextColor),
          Container(
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), boxShadow: kShadow),
            child: Column(
              children: [
                _buildThemeOption(context, ref, settings, ThemeMode.system, Icons.brightness_auto, "System Default"),
                Divider(height: 1, color: dividerColor),
                _buildThemeOption(context, ref, settings, ThemeMode.light, Icons.light_mode, "Light Mode"),
                Divider(height: 1, color: dividerColor),
                _buildThemeOption(context, ref, settings, ThemeMode.dark, Icons.dark_mode, "Dark Mode"),
              ],
            ),
          ),
          const SizedBox(height: 24),

          
          _buildSectionHeader("PREFERENCES", subTextColor),
          Container(
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), boxShadow: kShadow),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: settings.distanceUnit == DistanceUnit.imperial,
                  activeColor: kPrimaryColor,
                  title: Text("Imperial Units", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  subtitle: Text("Show distances in Miles/Feet", style: TextStyle(color: subTextColor)),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.straighten, color: Colors.orange),
                  ),
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).setUnit(val ? DistanceUnit.imperial : DistanceUnit.metric);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          
          _buildSectionHeader("MAP RENDERING QUALITY", subTextColor),
          Container(
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), boxShadow: kShadow),
            child: Column(
              children: [
                _buildModeOption(context, ref, settings, "Battery Saver", "Low quality tiles, no rotation.", PerformanceMode.batterySaver, Icons.battery_saver, Colors.green),
                Divider(height: 1, color: dividerColor),
                _buildModeOption(context, ref, settings, "Balanced", "Standard quality. Good for daily use.", PerformanceMode.balanced, Icons.speed, Colors.blue),
                Divider(height: 1, color: dividerColor),
                _buildModeOption(context, ref, settings, "High Fidelity", "Retina tiles, smooth rotation.", PerformanceMode.highFidelity, Icons.hdr_strong, Colors.purple),
              ],
            ),
          ),
          const SizedBox(height: 24),

          
          _buildSectionHeader("ABOUT", subTextColor),
          Container(
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), boxShadow: kShadow),
            child: Column(
              children: [
                _buildAboutTile(context, Icons.code, "Developer", "Made by Sasidhar Akurathi"),
                Divider(height: 1, color: dividerColor),
                _buildAboutTile(context, Icons.info_outline, "Version", "1.1.0 (Alpha Build)"),
                Divider(height: 1, color: dividerColor),
                _buildAboutTile(context, Icons.source, "Project Status", "Open Source (Flutter & OSRM)"),
                Divider(height: 1, color: dividerColor),
                _buildAboutTile(context, Icons.email_outlined, "Contact Us", "22kt1a0595@gmail.com"),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
           Center(child: Text("Route Memory | Built with Flutter & Riverpod", style: TextStyle(color: Colors.grey[400], fontSize: 12))),
           const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color? color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
  
  Widget _buildAboutTile(BuildContext context, IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: kPrimaryColor),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
    );
  }

  Widget _buildThemeOption(BuildContext context, WidgetRef ref, MapSettings currentSettings, ThemeMode mode, IconData icon, String label) {
    final isSelected = currentSettings.themeMode == mode;
    final theme = Theme.of(context);
    
    return ListTile(
      leading: Icon(icon, color: isSelected ? kPrimaryColor : Colors.grey),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
      trailing: isSelected ? const Icon(Icons.check, color: kPrimaryColor) : null,
      onTap: () => ref.read(settingsProvider.notifier).setThemeMode(mode),
    );
  }

  Widget _buildModeOption(BuildContext context, WidgetRef ref, MapSettings currentSettings,
      String title, String subtitle, PerformanceMode mode, IconData icon, Color color) {
    final theme = Theme.of(context);
    
    return RadioListTile<PerformanceMode>(
      value: mode,
      groupValue: currentSettings.mode,
      onChanged: (val) {
        if (val != null) ref.read(settingsProvider.notifier).setMode(val);
      },
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color),
      ),
      activeColor: kPrimaryColor,
    );
  }
}