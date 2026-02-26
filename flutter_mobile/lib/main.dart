import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "screens/login_screen.dart";
import "screens/tabs_shell.dart";
import "state/app_state.dart";
import "theme/app_colors.dart";

void main() {
  runApp(const PranaGApp());
}

class PranaGApp extends StatefulWidget {
  const PranaGApp({super.key});

  @override
  State<PranaGApp> createState() => _PranaGAppState();
}

class _PranaGAppState extends State<PranaGApp> {
  final AppState _appState = AppState();

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light(useMaterial3: false);
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "PRANA-G",
      theme: base.copyWith(
        scaffoldBackgroundColor: AppColors.background,
        textTheme: textTheme,
        colorScheme: base.colorScheme.copyWith(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
        ),
      ),
      home: AnimatedBuilder(
        animation: _appState,
        builder: (context, _) {
          if (!_appState.isReady) {
            return const _BootstrapScreen();
          }
          if (_appState.isLoggedIn) {
            return TabsShell(appState: _appState);
          }
          return LoginScreen(appState: _appState);
        },
      ),
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
