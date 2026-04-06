import 'package:flutter/material.dart';
import 'package:logon/login/page/login_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async{ 
  WidgetsFlutterBinding.ensureInitialized();
await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = true; // Default to dark mode
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final database = FirebaseDatabase.instance.ref();
        // Listen to theme changes in real-time
        database.child('profiling').child(user.uid).child('isDarkMode').onValue.listen((event) {
          if (event.snapshot.exists && mounted) {
            setState(() {
              _isDarkMode = event.snapshot.value as bool? ?? true;
            });
          }
        });
        
        // Load initial value
        final snapshot = await database.child('profiling').child(user.uid).child('isDarkMode').get();
        if (snapshot.exists) {
          setState(() {
            _isDarkMode = snapshot.value as bool? ?? true;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      print('Error loading theme: $e');
    }
    setState(() => _isLoading = false);
  }

  // Light theme colors
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.blue,
    scaffoldBackgroundColor: Colors.grey[100],
    colorScheme: ColorScheme.light(
      primary: Colors.blue,
      secondary: Colors.blueAccent,
      surface: Colors.white,
      background: Colors.grey[100]!,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
    ),
    cardColor: Colors.white,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black87),
      bodySmall: TextStyle(color: Colors.black54),
    ),
  );

  // Dark theme colors (current default)
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.blue,
    scaffoldBackgroundColor: const Color(0xFF1A1A1A),
    colorScheme: ColorScheme.dark(
      primary: Colors.blue,
      secondary: Colors.blueAccent,
      surface: const Color(0xFF2A2A2A),
      background: const Color(0xFF1A1A1A),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A1A1A),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardColor: const Color(0xFF2A2A2A),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
      bodySmall: TextStyle(color: Colors.white60),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: _isDarkMode ? const Color(0xFF1A1A1A) : Colors.grey[100],
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      title: 'Gabay Tech',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

