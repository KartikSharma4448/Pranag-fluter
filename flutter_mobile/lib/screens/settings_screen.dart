import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../theme/app_colors.dart";
import "help_support_screen.dart";
import "privacy_policy_screen.dart";

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _prefDarkMode = "settings_dark_mode";
  static const String _prefOfflineMode = "settings_offline_mode";
  static const String _prefVoiceOutput = "settings_voice_output";
  static const String _prefNotifications = "settings_notifications";
  static const String _prefLanguage = "settings_language";

  final List<_LanguageOption> _languages = const [
    _LanguageOption(code: "hindi", name: "Hindi", dialect: "Devanagari"),
    _LanguageOption(code: "marathi", name: "Marathi", dialect: "Devanagari"),
    _LanguageOption(code: "gujarati", name: "Gujarati", dialect: "Gujarati"),
    _LanguageOption(code: "punjabi", name: "Punjabi", dialect: "Gurmukhi"),
    _LanguageOption(code: "bengali", name: "Bengali", dialect: "Bengali"),
    _LanguageOption(code: "tamil", name: "Tamil", dialect: "Tamil"),
    _LanguageOption(code: "telugu", name: "Telugu", dialect: "Telugu"),
    _LanguageOption(code: "kannada", name: "Kannada", dialect: "Kannada"),
    _LanguageOption(code: "malayalam", name: "Malayalam", dialect: "Malayalam"),
    _LanguageOption(code: "english", name: "English", dialect: "Latin"),
  ];

  SharedPreferences? _prefs;
  bool _darkMode = false;
  bool _offlineMode = false;
  bool _voiceOutput = true;
  bool _notifications = true;
  String _selectedLanguage = "english";
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _darkMode = prefs.getBool(_prefDarkMode) ?? false;
      _offlineMode = prefs.getBool(_prefOfflineMode) ?? false;
      _voiceOutput = prefs.getBool(_prefVoiceOutput) ?? true;
      _notifications = prefs.getBool(_prefNotifications) ?? true;
      _selectedLanguage = prefs.getString(_prefLanguage) ?? "english";
      _loading = false;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _setLanguage(String code) {
    final lang = _languages.firstWhere((l) => l.code == code);
    setState(() {
      _selectedLanguage = code;
    });
    _prefs?.setString(_prefLanguage, code);
    _showSnack("Language changed to ${lang.name}");
  }

  void _toggleDarkMode(bool value) {
    setState(() => _darkMode = value);
    _prefs?.setBool(_prefDarkMode, value);
    _showSnack(value ? "Dark mode enabled" : "Light mode enabled");
  }

  void _toggleOfflineMode(bool value) {
    setState(() => _offlineMode = value);
    _prefs?.setBool(_prefOfflineMode, value);
    _showSnack(value ? "Offline mode enabled" : "Online mode enabled");
  }

  void _toggleVoiceOutput(bool value) {
    setState(() => _voiceOutput = value);
    _prefs?.setBool(_prefVoiceOutput, value);
  }

  void _toggleNotifications(bool value) {
    setState(() => _notifications = value);
    _prefs?.setBool(_prefNotifications, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Settings",
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Customize your experience",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SectionCard(
                    title: "Language Selection",
                    subtitle: "Powered by Bhashini - 22+ dialects",
                    icon: Icons.language,
                    iconColor: Colors.blue,
                    child: Column(
                      children: _languages
                          .map(
                            (lang) => _LanguageButton(
                              language: lang,
                              selected: _selectedLanguage == lang.code,
                              onTap: () => _setLanguage(lang.code),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: "Edge-Offline Sync",
                    subtitle: "TinyML on-device processing",
                    icon: _offlineMode ? Icons.wifi_off : Icons.wifi,
                    iconColor: Colors.purple,
                    trailing: Switch(
                      value: _offlineMode,
                      onChanged: _toggleOfflineMode,
                      activeColor: AppColors.primary,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _offlineMode
                            ? "All diagnostics run on your device. Data syncs when online."
                            : "Using cloud-enhanced AI processing. Internet required.",
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: "Voice Output",
                    subtitle: "Read diagnostics aloud",
                    icon: Icons.volume_up,
                    iconColor: Colors.green,
                    trailing: Switch(
                      value: _voiceOutput,
                      onChanged: _toggleVoiceOutput,
                      activeColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: "Early Warning Alerts",
                    subtitle: "48-hour disease detection",
                    icon: Icons.notifications,
                    iconColor: Colors.orange,
                    trailing: Switch(
                      value: _notifications,
                      onChanged: _toggleNotifications,
                      activeColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: "Dark Mode",
                    subtitle: _darkMode ? "Dark theme enabled" : "Light theme enabled",
                    icon: Icons.dark_mode,
                    iconColor: Colors.grey,
                    trailing: Switch(
                      value: _darkMode,
                      onChanged: _toggleDarkMode,
                      activeColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _GradientCard(
                    title: "Your Smartphone as a Lab",
                    rows: const [
                      _InfoRowData("Camera Resolution", "12MP (Sufficient)"),
                      _InfoRowData("Microphone Quality", "High Fidelity"),
                      _InfoRowData("Processing Power", "AI-Ready"),
                      _InfoRowData("Storage Available", "8.2 GB"),
                    ],
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8F5E9), Color(0xFFD9F0DE)],
                    ),
                    borderColor: const Color(0xFFC8E6C9),
                    icon: Icons.phone_android,
                    iconColor: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  _GradientCard(
                    title: "Designed for Everyone",
                    description:
                        "PRANA-G AI is built for zero-literacy users. Every diagnostic can be heard in your "
                        "preferred language via Bhashini integration.",
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE3F2FD), Color(0xFFD6E9FB)],
                    ),
                    borderColor: const Color(0xFFBBDEFB),
                    titleColor: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _SettingsLink(
                          title: "Privacy Policy",
                          subtitle: "Data protection & security",
                          icon: Icons.shield_outlined,
                          iconColor: Colors.blue,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const PrivacyPolicyScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _SettingsLink(
                          title: "Help & Support",
                          subtitle: "FAQs & customer care",
                          icon: Icons.help_outline,
                          iconColor: Colors.green,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const HelpSupportScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _LanguageOption {
  const _LanguageOption({
    required this.code,
    required this.name,
    required this.dialect,
  });

  final String code;
  final String name;
  final String dialect;
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final _LanguageOption language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${language.name} (${language.dialect})",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.white : AppColors.text,
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.trailing,
    this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          if (child != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child!,
            ),
        ],
      ),
    );
  }
}

class _GradientCard extends StatelessWidget {
  const _GradientCard({
    required this.title,
    this.description,
    required this.gradient,
    required this.borderColor,
    this.rows,
    this.icon,
    this.iconColor,
    this.titleColor,
  });

  final String title;
  final String? description;
  final LinearGradient gradient;
  final Color borderColor;
  final List<_InfoRowData>? rows;
  final IconData? icon;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null)
                Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
              if (icon != null) const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: titleColor ?? AppColors.primary,
                ),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          if (rows != null) ...[
            const SizedBox(height: 12),
            ...rows!.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      row.label,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      row.value,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRowData {
  const _InfoRowData(this.label, this.value);

  final String label;
  final String value;
}

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}
