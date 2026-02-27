import "package:flutter/material.dart";

import "../theme/app_colors.dart";
import "help_support_screen.dart";

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const List<_PolicySection> _sections = [
    _PolicySection(
      icon: Icons.lock_outline,
      title: "Data Encryption",
      content:
          "All cattle health data is encrypted end-to-end using industry-standard AES-256 encryption. "
          "Your biometric muzzle-ID data is never stored in plain text.",
    ),
    _PolicySection(
      icon: Icons.storage,
      title: "Data Storage",
      content:
          "Health records are stored securely on Indian servers complying with Data Protection Laws. "
          "You have full ownership and control of your data.",
    ),
    _PolicySection(
      icon: Icons.visibility_outlined,
      title: "Data Collection",
      content:
          "We collect only essential data: cattle biometric IDs, health scan results, and device diagnostics. "
          "No personal identification is linked to cattle data without consent.",
    ),
    _PolicySection(
      icon: Icons.description_outlined,
      title: "Third-Party Sharing",
      content:
          "We never sell your data. Information is only shared with veterinary partners when you "
          "explicitly request health consultations.",
    ),
    _PolicySection(
      icon: Icons.public,
      title: "Offline Processing",
      content:
          "With TinyML Edge mode, all AI diagnostics run on your device. Data syncs only when you are online "
          "and authorize it.",
    ),
  ];

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
              "Privacy Policy",
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Your data, your control",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.shield_outlined, color: AppColors.primary),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDBEAFE), Color(0xFFBFDBFE)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF93C5FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Privacy-First Design",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "PRANA-G AI is built with privacy at its core. As a hardware-less solution, "
                    "we minimize data collection and maximize user control.",
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 10),
                  _LastUpdatedTag(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ..._sections.map((section) => _PolicyCard(section: section)).toList(),
            const SizedBox(height: 16),
            _RightsCard(),
            const SizedBox(height: 16),
            _ContactCard(),
          ],
        ),
      ),
    );
  }
}

class _PolicySection {
  const _PolicySection({
    required this.icon,
    required this.title,
    required this.content,
  });

  final IconData icon;
  final String title;
  final String content;
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.section});

  final _PolicySection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(section.icon, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              section.content,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RightsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
        children: const [
          Text(
            "Your Rights",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          SizedBox(height: 12),
          _RightRow(
            title: "Access",
            text: "Request a copy of all your cattle health data at any time",
          ),
          _RightRow(
            title: "Delete",
            text: "Request permanent deletion of your account and all associated data",
          ),
          _RightRow(
            title: "Export",
            text: "Download health records in CSV or JSON format for analysis",
          ),
          _RightRow(
            title: "Opt-Out",
            text: "Disable cloud sync and use 100% offline TinyML mode",
          ),
        ],
      ),
    );
  }
}

class _RightRow extends StatelessWidget {
  const _RightRow({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.check, size: 14, color: Colors.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                children: [
                  TextSpan(
                    text: "$title: ",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFDCEFE1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Questions or Concerns?",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Contact our privacy team at privacy@prana-g.ai or call our helpline for assistance.",
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HelpSupportScreen(),
                ),
              );
            },
            child: const Text(
              "Visit Help & Support",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LastUpdatedTag extends StatelessWidget {
  const _LastUpdatedTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white70,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        "Last Updated: February 3, 2026",
        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }
}
