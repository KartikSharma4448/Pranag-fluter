import "package:flutter/material.dart";

import "../state/app_state.dart";
import "../theme/app_colors.dart";

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.appState,
    required this.onOpenHealthCheck,
    required this.onOpenAlerts,
  });

  final AppState appState;
  final VoidCallback onOpenHealthCheck;
  final VoidCallback onOpenAlerts;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 8),
                  _buildHero(),
                  const SizedBox(height: 16),
                  _buildPrimaryActions(),
                  const SizedBox(height: 24),
                  _buildQuickCards(),
                  const SizedBox(height: 28),
                  _buildFeatures(),
                  const SizedBox(height: 24),
                  _buildStatsRow(
                    unreadAlerts: appState.unreadAlerts,
                    cattleCount: appState.cattle.length,
                    scansCount: appState.user.totalScans,
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.gold,
            onPressed: onOpenHealthCheck,
            child: const Icon(Icons.mic, color: AppColors.white),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Flexible(
          child: Image(
            image: AssetImage("assets/logo.png"),
            height: 42,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: const Row(
            children: [
              Text(
                "Language | English",
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.expand_more, size: 14, color: AppColors.textSecondary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 487 / 463,
        child: Image.asset(
          "assets/home.png",
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildPrimaryActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onOpenHealthCheck,
            icon: const Icon(Icons.mic, size: 20),
            label: const Text("Check Cow Health"),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onOpenHealthCheck,
          icon: const Icon(
            Icons.camera_alt_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          label: const Text(
            "Scan with Camera",
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickCards() {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: const Icon(Icons.camera_alt, size: 28, color: AppColors.primary),
            label: "Scan Cow",
            bgColor: const Color(0xFFE8F5E9),
            onTap: onOpenHealthCheck,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: const Icon(Icons.graphic_eq, size: 28, color: Color(0xFFFF6B35)),
            label: "Listen to Sound",
            bgColor: const Color(0xFFFFF3E0),
            onTap: onOpenHealthCheck,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: const Icon(
              Icons.chat_bubble_outline,
              size: 28,
              color: AppColors.accent,
            ),
            label: "Hear Health Report",
            bgColor: const Color(0xFFFFF8E1),
            onTap: onOpenAlerts,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          "Features of PRANA-G",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        SizedBox(height: 14),
        _FeatureRow(
          icon: Icons.analytics,
          iconColor: AppColors.primary,
          title: "AI Health Analysis",
          desc: "Advanced deep learning for early disease detection",
        ),
        SizedBox(height: 10),
        _FeatureRow(
          icon: Icons.fingerprint,
          iconColor: Color(0xFF9C27B0),
          title: "Muzzle-ID",
          desc: "Unique biometric identification for each animal",
        ),
        SizedBox(height: 10),
        _FeatureRow(
          icon: Icons.monitor_heart,
          iconColor: AppColors.danger,
          title: "Real-time Monitoring",
          desc: "Continuous health tracking without hardware",
        ),
        SizedBox(height: 10),
        _FeatureRow(
          icon: Icons.shield,
          iconColor: Color(0xFF2196F3),
          title: "Early Warning System",
          desc: "48-hour predictive alerts for health issues",
        ),
      ],
    );
  }

  Widget _buildStatsRow({
    required int unreadAlerts,
    required int cattleCount,
    required int scansCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(number: "$cattleCount", label: "Cattle"),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatItem(number: "$scansCount", label: "Scans"),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatItem(
              number: "$unreadAlerts",
              label: "Alerts",
              color: unreadAlerts > 0 ? AppColors.danger : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: icon,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.desc,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      color: AppColors.border,
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.number,
    required this.label,
    this.color = AppColors.primary,
  });

  final String number;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          number,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
