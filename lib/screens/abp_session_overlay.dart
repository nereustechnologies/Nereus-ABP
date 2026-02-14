import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'abp_session_runner.dart';

class AbpSessionOverlay extends StatefulWidget {
  const AbpSessionOverlay({super.key});

  @override
  State<AbpSessionOverlay> createState() => _AbpSessionOverlayState();
}

class _AbpSessionOverlayState extends State<AbpSessionOverlay> {
  String? selectedUserId;
  List<Map<String, dynamic>> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    try {
      final supabase = Supabase.instance.client;

      final response =
          await supabase.from("users").select().order("created_at");

      if (!mounted) return;

      setState(() {
        users = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Error fetching users: $e");

      if (!mounted) return;

      setState(() {
        users = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      builder: (_, scrollController) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D0D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 18),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "NEREUS - ABP v1.0",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Ability-Biomechanics-Physiology Protocol\nTotal Duration: ~18 minutes",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // -----------------------------
              // USER DROPDOWN
              // -----------------------------
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: CircularProgressIndicator(color: Colors.white),
                )
              else if (users.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    "No registered users found.\nPlease complete the Preliminary Survey first.",
                    style: TextStyle(color: Colors.white60),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: selectedUserId,
                  dropdownColor: const Color(0xFF111111),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white12,
                    hintText: "Select Registered User",
                    hintStyle: const TextStyle(color: Colors.white60),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: users.map((user) {
                    return DropdownMenuItem<String>(
                      value: user["id"],
                      child: Text(user["name"] ?? "Unknown"),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedUserId = value;
                    });
                  },
                ),

              const SizedBox(height: 20),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: const [
                    _BlockTile(title: "Block 0", subtitle: "Initialization"),
                    _BlockTile(title: "Block 1", subtitle: "Mobility & DOF Scan"),
                    _BlockTile(
                        title: "Block 2", subtitle: "Lower Body Composite"),
                    _BlockTile(
                        title: "Block 3", subtitle: "Upper Body Composite"),
                    _BlockTile(title: "Block 4", subtitle: "Gait (Jog)"),
                    _BlockTile(title: "Block 5", subtitle: "Bracing & Core"),
                    _BlockTile(
                        title: "Block 6", subtitle: "Endurance Finisher"),
                    _BlockTile(
                        title: "Block 7", subtitle: "Cooldown + Psychology"),
                    SizedBox(height: 90),
                  ],
                ),
              ),

              SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedUserId == null
                          ? Colors.grey
                          : Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: selectedUserId == null
                        ? null
                        : () {
                            Navigator.pop(context);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AbpSessionRunner(
                                  userId: selectedUserId!,
                                ),
                              ),
                            );
                          },
                    child: const Text(
                      "Start Session",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BlockTile extends StatelessWidget {
  final String title;
  final String subtitle;

  const _BlockTile({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.fitness_center,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
