import "package:flutter/material.dart";
import "package:material_design_icons_flutter/material_design_icons_flutter.dart";

import "../state/app_state.dart";
import "../theme/app_colors.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _emailLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F5E8), Color(0xFFEDE8D0), Color(0xFFF5F5E8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 28, 24, 20 + bottomInset),
            child: Column(
              children: [
                _buildLogoSection(),
                _buildDemoLoginButton(),
                const SizedBox(height: 12),
                const Text(
                  "OR use Email Login",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(height: 16),
                _buildEmailCard(),
                const SizedBox(height: 28),
                _buildFeatureRow(),
                const SizedBox(height: 18),
                const Text(
                  "By continuing, you agree to our Terms & Privacy Policy",
                  style: TextStyle(fontSize: 11, color: AppColors.textLight),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(MdiIcons.cow, size: 36, color: AppColors.primary),
              const SizedBox(width: 4),
              const Text(
                "PRANA",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "G",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Welcome to PRANA-G AI",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Hardware-less Livestock Health Monitoring",
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          widget.appState.demoLogin();
        },
        icon: const Icon(Icons.check_circle, size: 20),
        label: const Text("Demo Login (No Database)"),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: AppColors.white,
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailCard() {
    final emailReady =
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Email Login",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: "farmer@email.com",
              hintStyle: const TextStyle(color: AppColors.textLight),
              prefixIcon: const Icon(Icons.mail_outline,
                  size: 18, color: AppColors.textSecondary),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: "Password",
              hintStyle: const TextStyle(color: AppColors.textLight),
              prefixIcon: const Icon(Icons.lock_outline,
                  size: 18, color: AppColors.textSecondary),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: emailReady && !_emailLoading
                  ? () async {
                      setState(() {
                        _emailLoading = true;
                      });
                      try {
                        await widget.appState.signInWithEmail(
                          email: _emailController.text.trim(),
                          password: _passwordController.text.trim(),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Login failed: $e")),
                        );
                      } finally {
                        if (mounted) {
                          setState(() {
                            _emailLoading = false;
                          });
                        }
                      }
                    }
                  : null,
              icon: const Icon(Icons.lock_open, size: 18),
              label: Text(_emailLoading ? "Signing in..." : "Login / Sign Up"),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                foregroundColor: AppColors.white,
                backgroundColor:
                    emailReady ? AppColors.primaryDark : const Color(0xFFD4D4D4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _MiniFeature(
          icon: Icons.shield_outlined,
          iconColor: AppColors.primary,
          bgColor: Color(0xFFE8F5E9),
          label: "Secure Login",
        ),
        SizedBox(width: 28),
        _MiniFeature(
          icon: Icons.mic_none,
          iconColor: AppColors.accent,
          bgColor: Color(0xFFFFF3E0),
          label: "Voice-First",
        ),
        SizedBox(width: 28),
        _MiniFeature(
          icon: Icons.phone_android,
          iconColor: Color(0xFF9C27B0),
          bgColor: Color(0xFFF3E5F5),
          label: "No Hardware",
        ),
      ],
    );
  }
}

class _MiniFeature extends StatelessWidget {
  const _MiniFeature({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
