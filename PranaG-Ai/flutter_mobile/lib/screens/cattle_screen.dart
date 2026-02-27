import "package:flutter/material.dart";

import "../models/app_models.dart";
import "../state/app_state.dart";
import "../theme/app_colors.dart";

class CattleScreen extends StatefulWidget {
  const CattleScreen({
    super.key,
    required this.appState,
    required this.onOpenHealthCheck,
    required this.onOpenAlerts,
  });

  final AppState appState;
  final VoidCallback onOpenHealthCheck;
  final VoidCallback onOpenAlerts;

  @override
  State<CattleScreen> createState() => _CattleScreenState();
}

class _CattleScreenState extends State<CattleScreen> {
  String _filter = "all";
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final query = _searchQuery.trim().toLowerCase();
        final filtered = widget.appState.cattle.where((c) {
          final matchesFilter = () {
            if (_filter == "all") return true;
            if (_filter == "healthy") return c.status == "healthy";
            if (_filter == "attention") {
              return c.status == "attention" || c.status == "critical";
            }
            return true;
          }();

          final matchesSearch = query.isEmpty ||
              c.name.toLowerCase().contains(query) ||
              c.breed.toLowerCase().contains(query) ||
              c.muzzleId.toLowerCase().contains(query) ||
              c.location.toLowerCase().contains(query);

          return matchesFilter && matchesSearch;
        }).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 14),
                  _buildFilterRow(),
                  const SizedBox(height: 10),
                  _buildSearch(),
                  const SizedBox(height: 20),
                  _buildQuickActions(),
                  const SizedBox(height: 20),
                  const Text(
                    "Your Cattle",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    _buildEmptyState()
                  else
                    ...filtered.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CattleCard(
                          cattle: c,
                          onHealthTap: widget.onOpenHealthCheck,
                          onAlertsTap: widget.onOpenAlerts,
                          onRemove: () => _confirmRemove(c),
                          onEdit: () => _openCattleForm(existing: c),
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "My Cattle",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Digital Twin Registry",
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        InkWell(
          onTap: _openCattleForm,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: AppColors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    return Wrap(
      spacing: 8,
      children: [
        _FilterChip(
          label: "Total Cattle",
          active: _filter == "all",
          onTap: () => setState(() => _filter = "all"),
        ),
        _FilterChip(
          label: "Healthy",
          active: _filter == "healthy",
          onTap: () => setState(() => _filter = "healthy"),
        ),
        _FilterChip(
          label: "Attention",
          active: _filter == "attention",
          onTap: () => setState(() => _filter = "attention"),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Actions",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: widget.onOpenHealthCheck,
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.camera_alt, color: AppColors.white, size: 24),
                      SizedBox(height: 6),
                      Text(
                        "Health Scan",
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Start AI diagnostic camera",
                        style: TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: widget.onOpenAlerts,
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [AppColors.gold, Color(0xFFA68B2B)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications,
                              color: AppColors.white, size: 24),
                          Positioned(
                            top: -4,
                            right: -8,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "${widget.appState.unreadAlerts}",
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Early Alerts",
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "48-hour warning system",
                        style: TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: "Search cattle by name, breed, muzzle ID, location",
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textLight),
        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textLight),
        filled: true,
        fillColor: AppColors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: const Column(
        children: [
          Icon(Icons.pets_outlined, size: 48, color: AppColors.textLight),
          SizedBox(height: 8),
          Text(
            "No cattle found",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCattleForm({Cattle? existing}) async {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? "");
    final breedController = TextEditingController(text: existing?.breed ?? "");
    final ageController =
        TextEditingController(text: existing != null ? "${existing.age}" : "");
    final locationController =
        TextEditingController(text: existing?.location ?? "");
    final healthController = TextEditingController(
      text: existing != null ? "${existing.healthScore}" : "80",
    );

    String status = existing?.status ?? "healthy";
    bool digitalTwin = existing?.digitalTwinActive ?? true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                    Text(
                      isEdit ? "Edit Cattle" : "Add Cattle",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FormInput(
                      controller: nameController,
                      label: "Name",
                      hint: "Lakshmi",
                    ),
                    const SizedBox(height: 10),
                    _FormInput(
                      controller: breedController,
                      label: "Breed",
                      hint: "Gir",
                    ),
                    const SizedBox(height: 10),
                    _FormInput(
                      controller: ageController,
                      label: "Age (years)",
                      hint: "4",
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    _FormInput(
                      controller: locationController,
                      label: "Location",
                      hint: "Barn A-12",
                    ),
                    const SizedBox(height: 10),
                    _FormInput(
                      controller: healthController,
                      label: "Health Score (0-100)",
                      hint: "80",
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Status",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        _StatusChip(
                          label: "Healthy",
                          selected: status == "healthy",
                          onTap: () => setSheetState(() => status = "healthy"),
                        ),
                        _StatusChip(
                          label: "Attention",
                          selected: status == "attention",
                          onTap: () =>
                              setSheetState(() => status = "attention"),
                        ),
                        _StatusChip(
                          label: "Critical",
                          selected: status == "critical",
                          onTap: () => setSheetState(() => status = "critical"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "Digital Twin Active",
                        style: TextStyle(fontSize: 13, color: AppColors.text),
                      ),
                      value: digitalTwin,
                      activeThumbColor: AppColors.primary,
                      onChanged: (value) =>
                          setSheetState(() => digitalTwin = value),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final name = nameController.text.trim();
                          final breed = breedController.text.trim();
                          final location = locationController.text.trim();
                          final age = int.tryParse(ageController.text.trim()) ?? 0;
                          final score =
                              int.tryParse(healthController.text.trim()) ?? -1;

                          if (name.isEmpty || breed.isEmpty || location.isEmpty) {
                            _showToast("Please fill all text fields.");
                            return;
                          }
                          if (age <= 0) {
                            _showToast("Age should be a positive number.");
                            return;
                          }
                          if (score < 0 || score > 100) {
                            _showToast("Health score must be between 0 and 100.");
                            return;
                          }

                          if (isEdit) {
                            final current = existing;
                            widget.appState.updateCattle(
                              current.copyWith(
                                name: name,
                                breed: breed,
                                age: age,
                                location: location,
                                healthScore: score,
                                status: status,
                                digitalTwinActive: digitalTwin,
                                alerts: status == "critical"
                                    ? 2
                                    : (status == "attention" ? 1 : 0),
                              ),
                            );
                          } else {
                            widget.appState.addCattle(
                              name: name,
                              breed: breed,
                              age: age,
                              location: location,
                              healthScore: score,
                              status: status,
                              digitalTwinActive: digitalTwin,
                            );
                          }

                          Navigator.of(context).pop();
                          _showToast(isEdit
                              ? "Cattle updated successfully."
                              : "Cattle added successfully.");
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: Text(isEdit ? "Update" : "Add"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    breedController.dispose();
    ageController.dispose();
    locationController.dispose();
    healthController.dispose();
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _confirmRemove(Cattle cattle) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Remove Cattle"),
          content: Text("Are you sure you want to remove ${cattle.name}?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                "Remove",
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      widget.appState.removeCattle(cattle.id);
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
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
          color: active ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
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

class _CattleCard extends StatelessWidget {
  const _CattleCard({
    required this.cattle,
    required this.onHealthTap,
    required this.onAlertsTap,
    required this.onRemove,
    required this.onEdit,
  });

  final Cattle cattle;
  final VoidCallback onHealthTap;
  final VoidCallback onAlertsTap;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  Color get statusColor {
    if (cattle.status == "healthy") return AppColors.success;
    if (cattle.status == "attention") return AppColors.warning;
    return AppColors.danger;
  }

  String get statusLabel {
    if (cattle.status == "healthy") return "Excellent Health";
    if (cattle.status == "attention") return "Needs Attention";
    return "Critical";
  }

  Color get scoreColor {
    if (cattle.healthScore >= 80) return AppColors.success;
    if (cattle.healthScore >= 60) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cattle.muzzleId,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text(
                  cattle.digitalTwinActive
                      ? "Digital Twin Active"
                      : "Twin Inactive",
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cattle.name,
                    style: const TextStyle(
                      fontSize: 20,
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    "${cattle.breed} - ${cattle.age} years",
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    "${cattle.healthScore}",
                    style: TextStyle(
                      fontSize: 32,
                      color: scoreColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    "Health Score",
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (cattle.alerts > 0)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 12,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${cattle.alerts} Alerts",
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: AppColors.textLight),
              const SizedBox(width: 6),
              Text(
                "Last scan: ${cattle.lastScan}",
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.textLight),
              const SizedBox(width: 6),
              Text(
                cattle.location,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ActionButton(
                label: "Scan",
                icon: Icons.camera_alt,
                bg: AppColors.primary,
                onTap: onHealthTap,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                label: "Alerts",
                icon: Icons.notifications,
                bg: AppColors.gold,
                onTap: onAlertsTap,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                label: "Remove",
                icon: Icons.delete,
                bg: AppColors.danger,
                onTap: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onEdit,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.borderLight),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Edit Cattle Details",
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormInput extends StatelessWidget {
  const _FormInput({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.bg,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
