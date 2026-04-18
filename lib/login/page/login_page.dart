import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logon/home/page/home_page.dart';
import 'package:logon/register/page/register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailcontroler = TextEditingController();
  final passwordcontroler = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

Future<void> login() async{
  try{
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: emailcontroler.text.trim(), 
      password: passwordcontroler.text.trim()
    );
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));     

  } catch (e) {
    String errorMessage = "Login failed. Please try again.";
    
    if (e is FirebaseAuthException) {
      if (e.code == 'user-not-found') {
        errorMessage = "No user found for that email.";
      } else if (e.code == 'wrong-password') {
        errorMessage = "Wrong password provided.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "The email address is not valid.";
      }
    }
    
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
    emailcontroler.dispose();
    passwordcontroler.dispose();
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
                  height: 640,
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
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 26),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.blue, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.accessible_forward,
                                      color: Colors.blue,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'GABAY',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Georgia',
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'TECH',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Georgia',
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Log in',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: darkGreen,
                                ),
                              ),
                              const SizedBox(height: 26),
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
                                    child: const Text(
                                      'G',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                        fontFamily: 'Georgia',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  _SocialCircle(
                                    diameter: 52,
                                    background: const Color(0xFF2E8B57),
                                    child: const Icon(
                                      Icons.phone,
                                      size: 22,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              const Text(
                                'Use your account to log in',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 26),
                              _PillInput(
                                height: pillHeight,
                                radius: pillRadius,
                                prefixIcon: Icons.mail_outline,
                                prefixColor: darkGreen,
                                hintText: 'Email',
                                textColor: Colors.black,
                                controller: emailcontroler,
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
                                controller: passwordcontroler,
                                obscureText: _obscurePassword,
                                suffixIcon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: darkGreen,
                                ),
                                onSuffixTap: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: _rememberMe,
                                          onChanged: (value) {
                                            setState(() {
                                              _rememberMe = value ?? false;
                                            });
                                          },
                                          activeColor: Colors.blue,
                                          side: const BorderSide(color: Colors.white70),
                                        ),
                                        const Text(
                                          'Remember me?',
                                          style: TextStyle(
                                            fontFamily: 'Georgia',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      // UI only - no functionality
                                    },
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        fontFamily: 'Georgia',
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: login,
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
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Log in',
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
                              const Spacer(),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 22),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Don't have an account? ",
                                      style: TextStyle(
                                        fontFamily: 'Georgia',
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const RegisterPage(),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Create an account',
                                        style: TextStyle(
                                          fontFamily: 'Georgia',
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
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
  });

  final double diameter;
  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      child: Center(child: child),
    );
  }
}