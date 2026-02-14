import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: "https://gtzkcwlrwuylpqqohpnq.supabase.co",
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd0emtjd2xyd3V5bHBxcW9ocG5xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEwODAzNDQsImV4cCI6MjA4NjY1NjM0NH0.EEA-S63xIjc0xN7YpNySC11O5k5fTcLwM2OalSSr_fQ",
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nereus ABP',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        fontFamily: "GoodTimes",
      ),
      home: session == null ? const LoginScreen() : const HomeScreen(),
    );
  }
}
