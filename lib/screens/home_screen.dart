import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'camera_screen.dart';
import 'abp_session_overlay.dart';
import 'prelim_survey_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return "Good Morning";
    } else if (hour < 17) {
      return "Good Afternoon";
    } else {
      return "Good Evening";
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _homeTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER ROW (Greeting + Logout)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                getGreeting(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                ),
                onPressed: _logout,
              ),
            ],
          ),

          const SizedBox(height: 40),

          // PRELIM SURVEY CARD
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrelimSurveyScreen(),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Preliminary Survey",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Register new User profile",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.assignment_rounded,
                    size: 22,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // ABP SESSION CARD
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const AbpSessionOverlay(),
              );
            },
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Nereus",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "ABP Session",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyTab() {
    return const Center(
      child: Text(
        "History Coming Soon",
        style: TextStyle(color: Colors.white54, fontSize: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget currentScreen;

    if (_selectedIndex == 0) {
      currentScreen = _homeTab();
    } else if (_selectedIndex == 1) {
      currentScreen = const CameraScreen();
    } else {
      currentScreen = _historyTab();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: currentScreen,
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            border: Border(
              top: BorderSide(color: Colors.white12, width: 1),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            backgroundColor: Colors.black,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.blueAccent,
            unselectedItemColor: Colors.white54,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            elevation: 0,
            onTap: (index) {
              setState(() => _selectedIndex = index);
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded, size: 28),
                label: "Home",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.camera_alt_rounded, size: 28),
                label: "Camera",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_rounded, size: 28),
                label: "History",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
