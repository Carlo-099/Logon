import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logon/login/page/login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  Future<void> register() async {
    // Validate that passwords match
    if (passwordController.text.trim() != confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate password length
    if (passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 6 characters!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      
      // Firebase signs the user in after registration; sign out so they must log in next.
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account created successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to login page after successful registration
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } catch (e) {
      String errorMessage = "Registration failed. Please try again.";
      
      if (e is FirebaseAuthException) {
        if (e.code == 'weak-password') {
          errorMessage = "The password provided is too weak.";
        } else if (e.code == 'email-already-in-use') {
          errorMessage = "An account already exists for that email.";
        } else if (e.code == 'invalid-email') {
          errorMessage = "The email address is not valid.";
        }
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const darkGreen = Color(0xFF00441B);
    const bgBottom = darkGreen;
    const pillRadius = 30.0;
    const pillHeight = 56.0;

    return Scaffold(
      backgroundColor: bgBottom,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final frameWidth = constraints.maxWidth < 360 ? constraints.maxWidth : 360.0;
            return Center(
              child: SingleChildScrollView(
                child: SizedBox(
                  width: frameWidth,
                  height: 670,
                  child: Stack(
                    children: [
                      // Background image
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/eldery.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(color: bgBottom);
                          },
                        ),
                      ),
                      // Dark green overlay for readability
                      Positioned.fill(
                        child: Container(
                          color: bgBottom.withOpacity(0.78),
                        ),
                      ),
                      // Top white section with diagonal edge
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: ClipPath(
                          clipper: _TopDiagonalClipper(),
                          child: Container(
                            color: Colors.white,
                            height: 260,
                          ),
                        ),
                      ),
                      // Screen content
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 44),
                              const Text(
                                'Register',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: darkGreen,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Create Your Account',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: darkGreen,
                                ),
                              ),
                              const SizedBox(height: 34),
                              // Pill inputs
                              _PillInput(
                                height: pillHeight,
                                radius: pillRadius,
                                prefixIcon: Icons.person_outline,
                                prefixColor: darkGreen,
                                hintText: 'Enter Fullname',
                                textColor: Colors.black,
                              ),
                              const SizedBox(height: 16),
                              _PillInput(
                                height: pillHeight,
                                radius: pillRadius,
                                prefixIcon: Icons.email_outlined,
                                prefixColor: darkGreen,
                                hintText: 'Enter Your Email',
                                textColor: Colors.black,
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 16),
                              _PillInput(
                                height: pillHeight,
                                radius: pillRadius,
                                prefixIcon: Icons.lock_outline,
                                prefixColor: darkGreen,
                                hintText: 'Password',
                                textColor: Colors.black,
                                controller: passwordController,
                                obscureText: _obscurePassword,
                                suffixIcon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: darkGreen,
                                ),
                                onSuffixTap: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                                onChanged: (value) {
                                  // Keep confirm password in sync so existing registration validation still works.
                                  if (confirmPasswordController.text != value) {
                                    confirmPasswordController.text = value;
                                  }
                                },
                              ),
                              const SizedBox(height: 22),
                              // Register button (pill)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: register,
                                  borderRadius: BorderRadius.circular(pillRadius),
                                  child: Container(
                                    height: 52,
                                      width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.96),
                                      borderRadius: BorderRadius.circular(pillRadius),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        )
                                      ],
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Register',
                                        style: TextStyle(
                                          fontFamily: 'Georgia',
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: darkGreen,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              // Forgot password (right aligned)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.85),
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Georgia',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              // Divider row with centered label
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(color: Colors.white24, thickness: 1),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      'Or continue with',
                                      style: TextStyle(
                                        color: Colors.white70.withOpacity(0.95),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Georgia',
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(color: Colors.white24, thickness: 1),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Social icons row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _SocialCircle(
                                    diameter: 52,
                                    background: const Color(0xFF1877F2),
                                    child: const Text(
                                      'f',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontFamily: 'Georgia',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  _SocialCircle(
                                    diameter: 52,
                                    background: Colors.white,
                                    child: const Icon(
                                      Icons.mail_outline,
                                      size: 24,
                                      color: darkGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  _SocialCircle(
                                    diameter: 52,
                                    background: Colors.transparent,
                                    borderColor: Colors.white,
                                    borderWidth: 2,
                                    child: const Icon(
                                      Icons.send,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // Bottom text
                              Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Already have an account? ',
                                      style: TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (context) => const LoginPage()),
                                        );
                                      },
                                      child: const Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontFamily: 'Georgia',
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          decoration: TextDecoration.underline,
                                          decorationThickness: 2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopDiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    // Creates a diagonal edge like the mockup: white area goes slightly down to the right.
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.68);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _PillInput extends StatelessWidget {
  const _PillInput({
    required this.height,
    required this.radius,
    required this.prefixIcon,
    required this.prefixColor,
    required this.hintText,
    required this.textColor,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.onSuffixTap,
    this.onChanged,
  });

  final double height;
  final double radius;
  final IconData prefixIcon;
  final Color prefixColor;
  final String hintText;
  final Color textColor;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final VoidCallback? onSuffixTap;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(prefixIcon, color: prefixColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                obscureText: obscureText,
                keyboardType: keyboardType,
                style: TextStyle(color: textColor, fontSize: 15),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: hintText,
                  hintStyle: TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                    fontFamily: 'Georgia',
                  ),
                ),
              ),
            ),
            if (suffixIcon != null)
              IconButton(
                onPressed: onSuffixTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: suffixIcon!,
              ),
          ],
        ),
      ),
    );
  }
}

class _SocialCircle extends StatelessWidget {
  const _SocialCircle({
    required this.diameter,
    required this.background,
    required this.child,
    this.borderColor,
    this.borderWidth = 0,
  });

  final double diameter;
  final Color background;
  final Widget child;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(color: borderColor ?? Colors.white, width: borderWidth)
            : null,
      ),
      child: Center(child: child),
    );
  }
}





