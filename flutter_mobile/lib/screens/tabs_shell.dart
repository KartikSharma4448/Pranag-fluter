import "package:flutter/material.dart";

import "../state/app_state.dart";
import "../theme/app_colors.dart";
import "alerts_screen.dart";
import "cattle_screen.dart";
import "health_check_screen.dart";
import "home_screen.dart";
import "profile_screen.dart";

class TabsShell extends StatefulWidget {
  const TabsShell({super.key, required this.appState});

  final AppState appState;

  @override
  State<TabsShell> createState() => _TabsShellState();
}

class _TabsShellState extends State<TabsShell> {
  int _currentIndex = 0;

  void _openHealthCheck() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HealthCheckScreen(appState: widget.appState),
      ),
    );
  }

  void _openAlertsTab() {
    setState(() {
      _currentIndex = 2;
    });
  }

  Widget _buildIcon(IconData icon, {int badgeCount = 0}) {
    if (badgeCount <= 0) {
      return Icon(icon);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -9,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(9),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
            child: Text(
              badgeCount > 9 ? "9+" : "$badgeCount",
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final pages = <Widget>[
          HomeScreen(
            appState: widget.appState,
            onOpenHealthCheck: _openHealthCheck,
            onOpenAlerts: _openAlertsTab,
          ),
          CattleScreen(
            appState: widget.appState,
            onOpenHealthCheck: _openHealthCheck,
            onOpenAlerts: _openAlertsTab,
          ),
          AlertsScreen(appState: widget.appState),
          ProfileScreen(appState: widget.appState),
        ];

        return Scaffold(
          body: IndexedStack(index: _currentIndex, children: pages),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                backgroundColor: AppColors.white,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: AppColors.textLight,
                selectedLabelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                items: [
                  BottomNavigationBarItem(
                    icon: _buildIcon(Icons.home_outlined),
                    activeIcon: _buildIcon(Icons.home),
                    label: "Home",
                  ),
                  BottomNavigationBarItem(
                    icon: _buildIcon(Icons.pets_outlined),
                    activeIcon: _buildIcon(Icons.pets),
                    label: "My Cattle",
                  ),
                  BottomNavigationBarItem(
                    icon: _buildIcon(
                      Icons.notifications_outlined,
                      badgeCount: widget.appState.unreadAlerts,
                    ),
                    activeIcon: _buildIcon(
                      Icons.notifications,
                      badgeCount: widget.appState.unreadAlerts,
                    ),
                    label: "Alerts",
                  ),
                  BottomNavigationBarItem(
                    icon: _buildIcon(Icons.person_outline),
                    activeIcon: _buildIcon(Icons.person),
                    label: "Profile",
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
