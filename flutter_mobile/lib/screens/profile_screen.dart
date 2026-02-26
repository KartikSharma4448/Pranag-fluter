import "package:flutter/material.dart";
import "package:material_design_icons_flutter/material_design_icons_flutter.dart";

import "../models/app_models.dart";
import "../state/app_state.dart";
import "../theme/app_colors.dart";

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final user = appState.user;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
              child: Column(
                children: [
                  _buildHeader(context, user),
                  const SizedBox(height: 20),
                  _buildStats(user),
                  const SizedBox(height: 24),
                  _buildContactCard(user.phone),
                  const SizedBox(height: 20),
                  _buildMoreOptions(),
                  const SizedBox(height: 16),
                  _buildBrandCard(),
                  const SizedBox(height: 16),
                  _buildLogoutButton(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, UserProfile user) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 3),
          ),
          child: const Icon(Icons.person, size: 36, color: AppColors.textLight),
        ),
        const SizedBox(height: 12),
        Text(
          user.name,
          style: const TextStyle(
            fontSize: 22,
            color: AppColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          user.role,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            user.membership,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeaderButton(
              icon: Icons.edit_outlined,
              text: "Edit Profile",
              color: AppColors.primary,
              onTap: () => _openProfileEditor(context, user),
            ),
            const SizedBox(width: 10),
            _HeaderButton(
              icon: Icons.settings_outlined,
              text: "Settings",
              color: AppColors.gold,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Settings screen will be added in next phase."),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openProfileEditor(
    BuildContext context,
    UserProfile user,
  ) async {
    final nameController = TextEditingController(text: user.name);
    final roleController = TextEditingController(text: user.role);
    final phoneController = TextEditingController(text: user.phone);
    final membershipController = TextEditingController(text: user.membership);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Edit Profile",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                _ProfileField(
                  label: "Name",
                  controller: nameController,
                ),
                const SizedBox(height: 10),
                _ProfileField(
                  label: "Role",
                  controller: roleController,
                ),
                const SizedBox(height: 10),
                _ProfileField(
                  label: "Phone",
                  controller: phoneController,
                ),
                const SizedBox(height: 10),
                _ProfileField(
                  label: "Membership",
                  controller: membershipController,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      final role = roleController.text.trim();
                      final phone = phoneController.text.trim();
                      final membership = membershipController.text.trim();

                      if (name.isEmpty ||
                          role.isEmpty ||
                          phone.isEmpty ||
                          membership.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please fill all fields."),
                          ),
                        );
                        return;
                      }

                      appState.updateUserProfile(
                        name: name,
                        role: role,
                        phone: phone,
                        membership: membership,
                      );
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text("Save"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStats(UserProfile user) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: "${user.totalCattle}",
            label: "Cattle",
            bg: const Color(0xFFE8F5E9),
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: "${user.totalScans}",
            label: "Health Scans",
            bg: const Color(0xFFE3F2FD),
            color: const Color(0xFF1976D2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: "${user.totalAlerts}",
            label: "Alerts",
            bg: const Color(0xFFFFF3E0),
            color: AppColors.danger,
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard(String phone) {
    return _Section(
      title: "Contact Information",
      child: Column(
        children: [
          const _InfoRow(icon: Icons.location_on_outlined, label: "Not provided"),
          const _DividerLine(),
          _InfoRow(icon: Icons.call_outlined, label: phone),
          const _DividerLine(),
          const _InfoRow(icon: Icons.mail_outline, label: "Not provided"),
        ],
      ),
    );
  }

  Widget _buildMoreOptions() {
    return _Section(
      title: "More Options",
      child: const Column(
        children: [
          _MenuRow(
            icon: Icons.emoji_events_outlined,
            iconColor: AppColors.gold,
            title: "Achievements",
            subtitle: "Health milestones & records",
          ),
          _DividerLine(),
          _MenuRow(
            icon: Icons.phone_android_outlined,
            iconColor: AppColors.primary,
            title: "Device Info",
            subtitle: "TinyML status & diagnostics",
          ),
          _DividerLine(),
          _MenuRow(
            icon: Icons.help_outline,
            iconColor: Color(0xFF2196F3),
            title: "Help & Support",
            subtitle: "FAQs and contact support",
          ),
          _DividerLine(),
          _MenuRow(
            icon: Icons.description_outlined,
            iconColor: AppColors.textSecondary,
            title: "Terms & Privacy",
            subtitle: "Legal information",
          ),
        ],
      ),
    );
  }

  Widget _buildBrandCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.cow, size: 24, color: AppColors.primary),
              const SizedBox(width: 4),
              const Text(
                "PRANA",
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "G",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Version 1.0.0",
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Hardware-less DeepTech livestock health",
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: appState.logout,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.dangerLight),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 20, color: AppColors.danger),
            SizedBox(width: 8),
            Text(
              "Logout",
              style: TextStyle(
                fontSize: 15,
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.text,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.white),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
  });

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
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
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textLight),
        ],
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      height: 1,
      color: AppColors.borderLight,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.bg,
    required this.color,
  });

  final String value;
  final String label;
  final Color bg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
