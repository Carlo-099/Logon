import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logon/login/page/login_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
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
  bool _isDarkMode = true;
  String _textSize = 'medium'; // medium | large — stored at profiling/{uid}/textSize
  bool _isLoading = true;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DatabaseEvent>? _themeSub;
  StreamSubscription<DatabaseEvent>? _textSub;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthUserChanged);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _themeSub?.cancel();
    _textSub?.cancel();
    super.dispose();
  }

  Future<void> _onAuthUserChanged(User? user) async {
    _themeSub?.cancel();
    _textSub?.cancel();

    if (user == null) {
      if (mounted) {
        setState(() {
          _isDarkMode = true;
          _textSize = 'medium';
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    final ref = FirebaseDatabase.instance.ref().child('profiling').child(user.uid);

    try {
      final dm = await ref.child('isDarkMode').get();
      final ts = await ref.child('textSize').get();
      if (!mounted) return;
      setState(() {
        _isDarkMode = dm.exists ? (dm.value as bool? ?? true) : true;
        final raw = ts.exists ? (ts.value?.toString() ?? 'medium') : 'medium';
        _textSize = raw == 'large' ? 'large' : 'medium';
      });
    } catch (e) {
      debugPrint('Error loading app preferences: $e');
    }

    if (mounted) setState(() => _isLoading = false);

    _themeSub = ref.child('isDarkMode').onValue.listen((event) {
      if (!mounted) return;
      setState(() {
        if (event.snapshot.exists) {
          _isDarkMode = event.snapshot.value as bool? ?? true;
        } else {
          _isDarkMode = true;
        }
      });
    });

    _textSub = ref.child('textSize').onValue.listen((event) {
      if (!mounted) return;
      setState(() {
        if (event.snapshot.exists) {
          final raw = event.snapshot.value?.toString() ?? 'medium';
          _textSize = raw == 'large' ? 'large' : 'medium';
        } else {
          _textSize = 'medium';
        }
      });
    });
  }

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

  double get _textScale => _textSize == 'large' ? 1.18 : 1.0;

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
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(_textScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const LoginPage(),
    );
  }
}
