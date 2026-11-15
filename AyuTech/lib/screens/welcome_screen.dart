// lib/screens/welcome_screen.dart
import 'package:flutter/material.dart';
import 'admin_page.dart';
import 'admin_login_screen.dart';
import 'admin_signup_screen.dart';
import 'doctor_login_screen.dart';
import 'staff_login_screen.dart';
import 'patient_login_screen.dart'; // ✅ added import

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _panelController;
  late final AnimationController _logoController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _panelController, curve: Curves.easeInOutCubic));

    _logoController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnimation = CurvedAnimation(parent: _logoController, curve: Curves.easeIn);
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    // start the panel and logo animations
    _panelController.forward().whenComplete(() => _logoController.forward());
  }

  @override
  void dispose() {
    _panelController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  // NAVIGATION helpers — simple direct navigation (no popup)
 void _openAdminPage() {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
  );
}


  void _openDoctorFlow() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorLoginScreen()));
  }

  void _openStaffFlow() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffLoginScreen()));
  }

  void _openPatientFlow() { // ✅ added
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientLoginScreen()));
  }

  Animation<double> _scale_animation_safe() => _scaleAnimation;

  Widget _roleButton({
    required String label,
    required IconData icon,
    required Color background,
    required Color textColor,
    required VoidCallback onTap,
    double height = 60,
    bool showShadow = false,
  }) {
    final isDark = background.computeLuminance() < 0.5;
    final circleBg = isDark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.10);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: height,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(36),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 18),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: circleBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: textColor, size: 20),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textColor),
              ),
            ),
            const SizedBox(width: 18),
          ],
        ),
      ),
    );
  }

  Widget _leftContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Headline with subtle shader on AYUTECH
        RichText(
          text: TextSpan(
            text: 'Welcome To ',
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              fontFamily: 'Jomolhari',
              color: Colors.black87,
            ),
            children: [
              TextSpan(
                text: 'AYUTECH',
                style: TextStyle(
                  foreground: Paint()
                    ..shader = const LinearGradient(
                      colors: [Color(0xFF2F5C56), Color(0xFF2F5C56)],
                    ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),
        const Text(
          'Empowering Ayurvedic Intelligence',
          style: TextStyle(fontSize: 18, color: Colors.black54),
        ),

        const SizedBox(height: 18),

        // Subtle info card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white.withOpacity(0.92),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
            child: Row(
              children: const [
                Icon(Icons.health_and_safety, color: Color(0xFF466643)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Choose your role to continue — secure sign-in for staff, doctors and administrators.',
                    style: TextStyle(color: Colors.black87),
                  ),
                )
              ],
            ),
          ),
        ),

        const SizedBox(height: 36),

        // Buttons group
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _roleButton(
                label: 'Admin',
                icon: Icons.admin_panel_settings,
                background:  const Color(0xFF2F5C56),

                textColor: const Color(0xFFF3E8FF),
                onTap: _openAdminPage,
                height: 64,
                showShadow: true,
              ),
              const SizedBox(height: 18),
              _roleButton(
                label: 'Doctor',
                icon: Icons.medical_services_outlined,
                background: const Color(0xFFF3F3F3),
                textColor: Colors.black87,
                onTap: _openDoctorFlow,
                height: 62,
                showShadow: true,
              ),
              const SizedBox(height: 18),
              _roleButton(
                label: 'Staff',
                icon: Icons.people_outline,
                background: const Color(0xFFFFFFFF),
                textColor: Colors.black87,
                onTap: _openStaffFlow,
                height: 62,
                showShadow: true,
              ),
              const SizedBox(height: 18),
              // ✅ added Patients button
              _roleButton(
                label: 'Patients',
                icon: Icons.person_outline,
                background: const Color(0xFFFFFFFF),
                textColor: Colors.black87,
                onTap: _openPatientFlow,
                height: 62,
                showShadow: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final rightPanelWidth = screenW * 0.48;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFFAFAF8),
        child: Row(
          children: [
            Expanded(
              flex: 52,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36.0),
                    child: _leftContent(),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ClipPath(
                    clipper: MediumCurveClipper(),
                    child: Container(
                      width: rightPanelWidth,
                      color: const Color(0xFF2F5C56), // 0xFF2F5C56

                      child: Center(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scale_animation_safe(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset('assets/images/logo.png',
                                    width: 260, height: 260, color: Colors.white),
                                const SizedBox(height: 8),
                                const Text('Herbal Health Solutions',
                                    style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class MediumCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width * 0.22, 0);
    path.quadraticBezierTo(size.width * 0.05, size.height / 2, size.width * 0.22, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
