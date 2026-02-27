import "package:flutter/material.dart";

import "../models/app_models.dart";
import "../state/app_state.dart";
import "../theme/app_colors.dart";

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _filter = "all";

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final filtered = widget.appState.alerts.where((a) {
          if (_filter == "all") return true;
          return a.type == _filter;
        }).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(widget.appState.unreadAlerts),
                  const SizedBox(height: 14),
                  _buildFilterChips(),
                  const SizedBox(height: 20),
                  if (filtered.isEmpty)
                    _buildEmptyState()
                  else
                    ...filtered.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AlertCard(
                          alert: a,
                          onDismiss: () => widget.appState.dismissAlert(a.id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(int unreadCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Alerts",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            Text(
              "$unreadCount new alerts",
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (unreadCount > 0)
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.danger,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              "$unreadCount",
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      children: [
        _FilterChip(
          label: "Critical",
          color: AppColors.danger,
          active: _filter == "critical",
          onTap: () => setState(() {
            _filter = _filter == "critical" ? "all" : "critical";
          }),
        ),
        _FilterChip(
          label: "Warnings",
          color: AppColors.warning,
          active: _filter == "warning",
          onTap: () => setState(() {
            _filter = _filter == "warning" ? "all" : "warning";
          }),
        ),
        _FilterChip(
          label: "Healthy",
          color: AppColors.success,
          active: _filter == "healthy",
          onTap: () => setState(() {
            _filter = _filter == "healthy" ? "all" : "healthy";
          }),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: const Column(
        children: [
          Icon(Icons.check_circle, size: 48, color: AppColors.success),
          SizedBox(height: 8),
          Text(
            "All Clear!",
            style: TextStyle(
              fontSize: 18,
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2),
          Text(
            "No alerts to show",
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? AppColors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onDismiss});

  final FarmAlert alert;
  final VoidCallback onDismiss;

  Color get bgColor {
    if (alert.type == "critical") return const Color(0xFFFEF2F2);
    if (alert.type == "warning") return const Color(0xFFFFFBEB);
    return const Color(0xFFF0FDF4);
  }

  Color get borderColor {
    if (alert.type == "critical") return const Color(0xFFFECACA);
    if (alert.type == "warning") return const Color(0xFFFDE68A);
    return const Color(0xFFBBF7D0);
  }

  Color get typeColor {
    if (alert.type == "critical") return AppColors.danger;
    if (alert.type == "warning") return AppColors.warning;
    return AppColors.success;
  }

  IconData get icon {
    if (alert.type == "critical") return Icons.error;
    if (alert.type == "warning") return Icons.warning_amber_rounded;
    return Icons.check_circle;
  }

  String get typeLabel {
    if (alert.type == "critical") return "CRITICAL";
    if (alert.type == "warning") return "WARNING";
    return "HEALTHY";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: typeColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${alert.cattleName} (${alert.cattleBreed}) - ${alert.time}",
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!alert.read)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4, right: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              InkWell(
                onTap: onDismiss,
                child: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alert.description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: typeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                child: Text(
                  typeLabel,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (alert.actionRequired)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: const Row(
                    children: [
                      Text(
                        "Action Required",
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
