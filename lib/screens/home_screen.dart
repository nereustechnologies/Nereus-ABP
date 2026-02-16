import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'camera_screen.dart';
import 'abp_session_overlay.dart';
import 'prelim_survey_screen.dart';
import 'login_screen.dart';
import 'polar_connect_overlay.dart';
import '../services/polar_data_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
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
    final polarConnected = PolarDataService.instance.isConnected;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  Icons.settings_rounded,
                  color: Colors.white,
                ),
                onPressed: () async {
                  final result = await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _SettingsOverlay(
                      onLogout: _logout,
                    ),
                  );

                  if (!mounted) return;

                  setState(() {});

                  if (result == "connected") {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            "Polar device connected successfully"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }

                  if (result == "disconnected") {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text("Polar device disconnected"),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 40),

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
              padding: const EdgeInsets.symmetric(
                  vertical: 22, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Preliminary Survey",
                        style: TextStyle(
                            fontSize: 18,
                            color: Colors.white),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Register new User profile",
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.white60),
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

          GestureDetector(
            onTap: polarConnected
                ? () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor:
                          Colors.transparent,
                      builder: (_) =>
                          const AbpSessionOverlay(),
                    );
                  }
                : null,
            child: Opacity(
              opacity: polarConnected ? 1.0 : 0.4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 22, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius:
                      BorderRadius.circular(18),
                  border: Border.all(
                    color: polarConnected
                        ? Colors.white.withOpacity(0.08)
                        : Colors.red.withOpacity(0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Nereus",
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.white),
                        ),
                        Icon(
                          polarConnected
                              ? Icons.arrow_forward_ios_rounded
                              : Icons.lock_outline_rounded,
                          size: 18,
                          color: Colors.white
                              .withOpacity(0.6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      polarConnected
                          ? "ABP Session"
                          : "Connect Polar device to start",
                      style: TextStyle(
                        fontSize: 14,
                        color: polarConnected
                            ? Colors.white60
                            : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
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
        style: TextStyle(
            color: Colors.white54, fontSize: 18),
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
              top: BorderSide(
                  color: Colors.white12, width: 1),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            backgroundColor: Colors.black,
            type: BottomNavigationBarType.fixed,
            selectedItemColor:
                Colors.blueAccent,
            unselectedItemColor:
                Colors.white54,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            elevation: 0,
            onTap: (index) {
              setState(() =>
                  _selectedIndex = index);
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded,
                    size: 28),
                label: "Home",
              ),
              BottomNavigationBarItem(
                icon: Icon(
                    Icons.camera_alt_rounded,
                    size: 28),
                label: "Camera",
              ),
              BottomNavigationBarItem(
                icon: Icon(
                    Icons.bar_chart_rounded,
                    size: 28),
                label: "History",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsOverlay extends StatefulWidget {
  final VoidCallback onLogout;

  const _SettingsOverlay({
    required this.onLogout,
  });

  @override
  State<_SettingsOverlay> createState() =>
      _SettingsOverlayState();
}

class _SettingsOverlayState
    extends State<_SettingsOverlay> {
  @override
  Widget build(BuildContext context) {
    final polarConnected =
        PolarDataService.instance.isConnected;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 24, vertical: 28),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin:
                  const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius:
                    BorderRadius.circular(2),
              ),
            ),

            GestureDetector(
              onTap: () async {
                if (polarConnected) {
                  await PolarDataService
                      .instance
                      .disconnect();
                  if (!mounted) return;
                  Navigator.pop(
                      context, "disconnected");
                } else {
                  final result =
                      await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor:
                        Colors.transparent,
                    builder: (_) =>
                        const PolarConnectOverlay(),
                  );

                  if (!mounted) return;

                  if (result == true) {
                    Navigator.pop(
                        context, "connected");
                  }
                }
              },
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color: polarConnected
                        ? Colors.red
                            .withOpacity(0.4)
                        : Colors.white
                            .withOpacity(0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        polarConnected
                            ? "Disconnect Polar Device"
                            : "Connect Polar Device",
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          color: polarConnected
                              ? Colors.redAccent
                              : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      polarConnected
                          ? Icons
                              .bluetooth_disabled_rounded
                          : Icons
                              .bluetooth_rounded,
                      color: polarConnected
                          ? Colors.redAccent
                          : Colors.white70,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                widget.onLogout();
              },
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.red
                        .withOpacity(0.4),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                  children: [
                    Text(
                      "Logout",
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            Colors.redAccent,
                      ),
                    ),
                    Icon(
                      Icons.logout_rounded,
                      color:
                          Colors.redAccent,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
