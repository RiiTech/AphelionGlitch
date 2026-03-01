// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:ui';

import 'telegram.dart';
import 'admin_page.dart';
import 'home_page.dart';
import 'seller_page.dart';
import 'change_password_page.dart';
import 'ddos_page.dart';
import 'chat_page.dart';
import 'login_page.dart';
import 'custom_bug.dart';
import 'bug_group.dart';
import 'ddos_panel.dart';
import 'sender_page.dart';

class DashboardPage extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listPayload;
  final List<Map<String, dynamic>> listDDoS;
  final List<dynamic> news;

  const DashboardPage({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.listBug,
    required this.listPayload,
    required this.listDDoS,
    required this.sessionKey,
    required this.news,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late WebSocketChannel channel;

  late String sessionKey;
  late String username;
  late String password;
  late String role;
  late String expiredDate;
  late List<Map<String, dynamic>> listBug;
  late List<Map<String, dynamic>> listPayload;
  late List<Map<String, dynamic>> listDDoS;
  late List<dynamic> newsList;
  String androidId = "unknown";

  int _selectedIndex = 0;
  Widget _selectedPage = const Placeholder();

  // Global key untuk mendapatkan posisi tombol Bug
  final GlobalKey _bugButtonKey = GlobalKey();

  // Controller for news page view
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentNewsIndex = 0;

  // Activity log state
  List<Map<String, dynamic>> _activityLogs = [];
  bool _isLoadingActivityLogs = false;
  bool _hasActivityLogsError = false;

  @override
  void initState() {
    super.initState();
    sessionKey = widget.sessionKey;
    username = widget.username;
    password = widget.password;
    role = widget.role;
    expiredDate = widget.expiredDate;
    listBug = widget.listBug;
    listPayload = widget.listPayload;
    listDDoS = widget.listDDoS;
    newsList = widget.news;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    _selectedPage = _buildNewsPage();

    _initAndroidIdAndConnect();

    // Fetch activity logs when the page is first loaded
    _fetchActivityLogs();
  }

  Future<void> _initAndroidIdAndConnect() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    androidId = deviceInfo.id;
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    channel = WebSocketChannel.connect(Uri.parse('wss://tapops.fanzhosting.my.id'));
    channel.sink.add(jsonEncode({
      "type": "validate",
      "key": sessionKey,
      "androidId": androidId,
    }));

    channel.sink.add(jsonEncode({"type": "stats"}));

    channel.stream.listen((event) {
      final data = jsonDecode(event);

      if (data['type'] == 'myInfo') {
        if (data['valid'] == false) {
          if (data['reason'] == 'androidIdMismatch') {
            _handleInvalidSession("Your account has logged on another device.");
          } else if (data['reason'] == 'keyInvalid') {
            _handleInvalidSession("Key is not valid. Please login again.");
          }
        }
      }
    });
  }

  // Fetch activity logs from API
  Future<void> _fetchActivityLogs() async {
    setState(() {
      _isLoadingActivityLogs = true;
      _hasActivityLogsError = false;
    });

    try {
      final response = await http.get(
        Uri.parse('https://tapops.fanzhosting.my.id/api/user/getActivityLogs?key=$sessionKey'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['valid'] == true && data['logs'] != null) {
          setState(() {
            _activityLogs = List<Map<String, dynamic>>.from(data['logs']);
            _isLoadingActivityLogs = false;
          });
        } else {
          setState(() {
            _isLoadingActivityLogs = false;
            _hasActivityLogsError = true;
          });
        }
      } else {
        setState(() {
          _isLoadingActivityLogs = false;
          _hasActivityLogsError = true;
        });
      }
    } catch (e) {
      print('Error fetching activity logs: $e');
      setState(() {
        _isLoadingActivityLogs = false;
        _hasActivityLogsError = true;
      });
    }
  }

  void _handleInvalidSession(String message) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: const Color(0xFFE53935), width: 1),
        ),
        title: const Text("⚠️ Session Expired", style: TextStyle(color: Colors.white, fontFamily: "Orbitron")),
        content: Text(message, style: const TextStyle(color: Colors.white70, fontFamily: "ShareTechMono")),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
              );
            },
            child: const Text("OK", style: TextStyle(color: const Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
      _controller.reset();
      _controller.forward();

      if (index == 0) {
        _selectedPage = _buildNewsPage();
      } else if (index == 1) {
        // Jika bukan VIP/Owner, langsung buka halaman Bug
        if (!["vip", "owner"].contains(role.toLowerCase())) {
          _selectedPage = AttackPage(
            username: username,
            password: password,
            listBug: listBug,
            role: role,
            expiredDate: expiredDate,
            sessionKey: sessionKey,
          );
        } else {
          // Untuk VIP/Owner, tampilkan popup menu
          _showBugMenu();
        }
      } else if (index == 2) {
        _selectedPage = TelegramSpamPage(sessionKey: sessionKey);
      } else if (index == 3) {
        _selectedPage = AttackPanel(sessionKey: sessionKey, listDDoS: listDDoS);
      } else if (index == 4) {
        _selectedPage = ToolsPage(sessionKey: sessionKey, userRole: role);
      }
    });
  }

  // Fungsi untuk menampilkan popup menu Bug
  void _showBugMenu() {
    // Dapatkan posisi dan ukuran tombol Bug
    final RenderBox renderBox = _bugButtonKey.currentContext?.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    // Tentukan opsi berdasarkan role
    List<Map<String, dynamic>> options = [];

    if (["vip", "owner"].contains(role.toLowerCase())) {
      options = [
        {
          'title': 'Custom Bug',
          'icon': FontAwesomeIcons.squareWhatsapp,
        },
        {
          'title': 'Group Bug',
          'icon': FontAwesomeIcons.users,
        },
        {
          'title': 'Bug',
          'icon': FontAwesomeIcons.whatsapp,
        },
      ];
    }

    // Tampilkan popup menu
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy - size.height * 2, // Posisikan di atas tombol
        offset.dx + size.width,
        offset.dy,
      ),
      items: options.map((option) {
        return PopupMenuItem(
          value: option['title'],
          child: Row(
            children: [
              Icon(option['icon'], color: Colors.white70, size: 20),
              const SizedBox(width: 10),
              Text(
                option['title'],
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      }).toList(),
      color: const Color(0xFF0D0D0D),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF7A1A1A), width: 1),
      ),
    ).then((value) {
      // Handle pilihan dari popup menu
      if (value != null) {
        setState(() {
          if (value == 'Custom Bug') {
            _selectedPage = CustomAttackPage(
              username: username,
              password: password,
              listPayload: listPayload,
              role: role,
              expiredDate: expiredDate,
              sessionKey: sessionKey,
            );
          } else if (value == 'Group Bug') {
            _selectedPage = GroupBugPage(
              username: username,
              password: password,
              role: role,
              expiredDate: expiredDate,
              sessionKey: sessionKey,
            );
          } else if (value == 'Bug') {
            _selectedPage = AttackPage(
              username: username,
              password: password,
              listBug: listBug,
              role: role,
              expiredDate: expiredDate,
              sessionKey: sessionKey,
            );
          }
        });
      }
    });
  }

  void _selectFromDrawer(String page) {
    Navigator.pop(context);
    setState(() {
      if (page == 'reseller') {
        _selectedPage = SellerPage(keyToken: sessionKey);
      } else if (page == 'admin') {
        _selectedPage = AdminPage(sessionKey: sessionKey);
      } else if (page == 'sender') {
        _selectedPage = SenderPage(sessionKey: sessionKey);
      }
    });
  }

  Widget _buildNewsPage() {
    return RefreshIndicator(
      color: const Color(0xFFE53935),
      onRefresh: () async {
        // Refresh activity logs when user pulls to refresh
        await _fetchActivityLogs();
        // Simulate refreshing other data
        await Future.delayed(const Duration(seconds: 1));
        setState(() {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Welcome Section

            // News Carousel
            _buildNewsCarousel(),
            _buildWelcomeSection(),

            // Quick Actions Grid
            _buildQuickActionsGrid(),

            // Recent Activity
            _buildRecentActivity(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityLogsPage() {
    return RefreshIndicator(
      color: const Color(0xFFE53935),
      onRefresh: () async {
        await _fetchActivityLogs();
      },
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF1E1E1E),
              border: Border.all(
                color: const Color(0xFFE53935),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  color: const Color(0xFFE53935),
                  size: 30,
                ),
                const SizedBox(width: 15),
                const Text(
                  "Activity History",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Orbitron",
                  ),
                ),
              ],
            ),
          ),

          // Activity logs content
          Expanded(
            child: _isLoadingActivityLogs
                ? const Center(
              child: CircularProgressIndicator(color: const Color(0xFFE53935)),
            )
                : _hasActivityLogsError
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.withOpacity(0.7),
                    size: 50,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "Failed to load activity logs",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: _fetchActivityLogs,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("Try Again"),
                  ),
                ],
              ),
            )
                : _activityLogs.isEmpty
                ? const Center(
              child: Text(
                "No activity logs available",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _activityLogs.length,
              itemBuilder: (context, index) {
                final log = _activityLogs[index];
                final timestamp = DateTime.tryParse(log['timestamp'] ?? '') ?? DateTime.now();
                final formattedTime = _formatDateTime(timestamp);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: const Color(0xFF1A1A1A),
                    border: Border.all(
                      color: _getActivityColor(log['activity']).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getActivityColor(log['activity']).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getActivityIcon(log['activity']),
                              color: _getActivityColor(log['activity']),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log['activity'] ?? 'Unknown Activity',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  formattedTime,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (log['details'] != null)
                        _buildActivityDetails(log['details']),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityDetails(Map<String, dynamic> details) {
    return Container(
      margin: const EdgeInsets.only(top: 8, left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: details.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${entry.key}:",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    entry.value.toString(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getActivityColor(String? activity) {
    if (activity == null) return Colors.grey;

    if (activity.contains('Bug') || activity.contains('Attack')) {
      return Colors.red;
    } else if (activity.contains('Call')) {
      return Colors.orange;
    } else if (activity.contains('Create') || activity.contains('Add')) {
      return Colors.green;
    } else if (activity.contains('Delete') || activity.contains('Failed')) {
      return Colors.red;
    } else if (activity.contains('Edit') || activity.contains('Change')) {
      return Colors.blue;
    } else if (activity.contains('Cooldown')) {
      return Colors.amber;
    }

    return const Color(0xFFE53935);
  }

  IconData _getActivityIcon(String? activity) {
    if (activity == null) return Icons.info;

    if (activity.contains('Bug') || activity.contains('Attack')) {
      return Icons.bug_report;
    } else if (activity.contains('Call')) {
      return Icons.phone;
    } else if (activity.contains('Create') || activity.contains('Add')) {
      return Icons.person_add;
    } else if (activity.contains('Delete')) {
      return Icons.delete;
    } else if (activity.contains('Edit') || activity.contains('Change')) {
      return Icons.edit;
    } else if (activity.contains('Cooldown')) {
      return Icons.timer;
    } else if (activity.contains('DDOS')) {
      return Icons.flash_on;
    }

    return Icons.info;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF1E1E1E),
        border: Border.all(
          color: const Color(0xFFE53935),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF3D1010),
                radius: 30,
                child: const Icon(
                  Icons.person,
                  color: const Color(0xFFE53935),
                  size: 30,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome back,",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: "ShareTechMono",
                      ),
                    ),
                    Text(
                      username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: "Orbitron",
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  color: _getRoleColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getRoleColor().withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: TextStyle(
                    color: _getRoleColor(),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Icon(
                Icons.date_range,
                color: const Color(0xFFE53935),
                size: 16,
              ),
              const SizedBox(width: 5),
              Text(
                "Account expires: $expiredDate",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontFamily: "ShareTechMono",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRoleColor() {
    switch (role.toLowerCase()) {
      case 'owner':
        return Colors.red;
      case 'vip':
        return Colors.amber;
      case 'reseller':
        return Colors.blue;
      default:
        return const Color(0xFFE53935);
    }
  }

  Widget _buildNewsCarousel() {
    if (newsList.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF1A1A1A),
          border: Border.all(
            color: const Color(0xFF2A1414),
            width: 1,
          ),
        ),
        child: const Center(
          child: Text(
            "No news available",
            style: TextStyle(
              color: Colors.white54,
              fontFamily: "ShareTechMono",
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: newsList.length,
            onPageChanged: (index) {
              setState(() {
                _currentNewsIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final item = newsList[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFF1A1A1A),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (item['image'] != null && item['image'].toString().isNotEmpty)
                        NewsMedia(url: item['image']),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xBB000000),
                              Colors.transparent
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] ?? 'No Title',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontFamily: "Orbitron",
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['desc'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontFamily: "ShareTechMono"),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (newsList.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              newsList.length,
                  (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                height: 8,
                width: _currentNewsIndex == index ? 24 : 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _currentNewsIndex == index
                      ? const Color(0xFFE53935)
                      : const Color(0xFF4A4A4A),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActionsGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Actions",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: "Orbitron",
            ),
          ),
          const SizedBox(height: 15),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1.2,
            children: [
              _buildActionCard(
                icon: FontAwesomeIcons.telegram,
                title: "Join Channel",
                subtitle: "Get updates",
                onTap: () async {
                  final uri = Uri.parse("tg://resolve?domain=aphelionlabs");
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    await launchUrl(Uri.parse("https://t.me/aphelionlabs"),
                        mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _buildActionCard(
                icon: Icons.phone_android,
                title: "Manage Senders",
                subtitle: "Configure devices",
                onTap: () {
                  setState(() {
                    _selectedPage = SenderPage(sessionKey: sessionKey);
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF1A1A1A),
          border: Border.all(
            color: const Color(0xFF2A1414),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: const Color(0xFFE53935),
              size: 30,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Statistics",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: "Orbitron",
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: "Active Bugs",
                  value: listBug.length.toString(),
                  icon: FontAwesomeIcons.bug,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildStatCard(
                  title: "DDoS Attacks",
                  value: listDDoS.length.toString(),
                  icon: FontAwesomeIcons.server,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: "Custom Payloads",
                  value: listPayload.length.toString(),
                  icon: FontAwesomeIcons.code,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildStatCard(
                  title: "News Updates",
                  value: newsList.length.toString(),
                  icon: FontAwesomeIcons.newspaper,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A1A1A),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Orbitron",
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Activity",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Orbitron",
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 4; // Activity logs tab index
                    _selectedPage = _buildActivityLogsPage();
                  });
                },
                child: const Text(
                  "View All",
                  style: TextStyle(
                    color: const Color(0xFFE53935),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (_isLoadingActivityLogs)
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: const Color(0xFF1A1A1A),
                border: Border.all(
                  color: const Color(0xFF2A1414),
                  width: 1,
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: const Color(0xFFE53935)),
              ),
            )
          else if (_hasActivityLogsError)
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: const Color(0xFF1A1A1A),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Center(
                child: Text(
                  "Failed to load activity logs",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else if (_activityLogs.isEmpty)
              Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: const Color(0xFF1A1A1A),
                  border: Border.all(
                    color: const Color(0xFF2A1414),
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Text(
                    "No activity logs available",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              ..._activityLogs.take(3).map((log) {
                final timestamp = DateTime.tryParse(log['timestamp'] ?? '') ?? DateTime.now();
                final formattedTime = _formatDateTime(timestamp);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: const Color(0xFF1A1A1A),
                      border: Border.all(
                        color: _getActivityColor(log['activity']).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getActivityColor(log['activity']).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getActivityIcon(log['activity']),
                            color: _getActivityColor(log['activity']),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log['activity'] ?? 'Unknown Activity',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (log['details'] != null && log['details']['target'] != null)
                                Text(
                                  "Target: ${log['details']['target']}",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
        ],
      ),
    );
  }

  // Glassmorphism card widget
  Widget _glassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1A1A1A),
        border: Border.all(
          color: const Color(0xFF2A1414),
          width: 1,
        ),

      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }

  // Glassmorphism button widget
  Widget _glassButton({required Icon icon, required Text label, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      icon: icon,
      label: label,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFE53935),
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: const Color(0xFFE53935), width: 1),
        ),
      ),
      onPressed: onPressed,
    );
  }

  void _showAccountMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _glassCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Account Info", style: TextStyle(color: Colors.white, fontSize: 20, fontFamily: "Orbitron")),
                const SizedBox(height: 12),
                _infoCard(Icons.person, "Username", username),
                _infoCard(Icons.date_range, "Expired", expiredDate),
                _infoCard(Icons.security, "Role", role),
                const SizedBox(height: 20),
                _glassButton(
                  icon: const Icon(Icons.lock_reset),
                  label: const Text("Change Password"),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangePasswordPage(
                          username: username,
                          sessionKey: sessionKey,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _glassButton(
                  icon: const Icon(Icons.logout),
                  label: const Text("Logout"),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A1414), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE53935)),
          const SizedBox(width: 10),
          Text("$label:", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontFamily: "ShareTechMono")),
        ],
      ),
    );
  }

  // Widget untuk menampilkan logo PNG
  Widget _buildLogo({double height = 40}) {
    return Image.asset(
      'assets/images/title.png',
      height: height,
      fit: BoxFit.contain,
    );
  }

  // PERUBAHAN: Buat daftar item bottom navigation bar berdasarkan role
  List<BottomNavigationBarItem> _buildBottomNavBarItems() {
    List<BottomNavigationBarItem> items = [
      BottomNavigationBarItem(
        icon: Image.asset('assets/images/home.png', width: 50, height: 50),
        label: "Home",
      ),
      // Hanya ada satu menu Bug untuk semua role
      BottomNavigationBarItem(
        key: _bugButtonKey, // Tambahkan key untuk mendapatkan posisi tombol
        icon: Image.asset('assets/images/wa.png', width: 50, height: 50),
        label: "Bug",
      ),
      BottomNavigationBarItem(
        icon: Image.asset('assets/images/tele.png', width: 50, height: 50),
        label: "Telegram",
      ),
      BottomNavigationBarItem(
        icon: Image.asset('assets/images/ddos.png', width: 50, height: 50),
        label: "DDoS",
      ),
      BottomNavigationBarItem(
        icon: Image.asset('assets/images/tools.png', width: 50, height: 50),
        label: "Tools",
      ),
    ];

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: _buildLogo(height: 40),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            border: Border(
              bottom: BorderSide(color: const Color(0xFF7A1A1A), width: 1),
            ),
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Color(0xFFE53935)),
            onPressed: _showAccountMenu,
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            border: Border(
              right: BorderSide(color: const Color(0xFF7A1A1A), width: 1),
            ),
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: ListView(
                padding: const EdgeInsets.all(0),
                children: [
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0605),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 15),
                          _buildLogo(height: 40),
                          const SizedBox(height: 15),
                          // Menggunakan card kecil untuk info username dan role
                          _infoCard(Icons.person, "Username", username),
                          _infoCard(Icons.admin_panel_settings, "Role", role),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (role == "reseller" || role == "owner")
                    ListTile(
                      leading: const Icon(Icons.person_add, color: const Color(0xFFE53935)),
                      title: const Text("Reseller Page", style: TextStyle(color: Colors.white70)),
                      onTap: () => _selectFromDrawer('reseller'),
                    ),
                  if (role == "owner")
                    ListTile(
                      leading: const Icon(Icons.settings, color: const Color(0xFFE53935)),
                      title: const Text("Admin Page", style: TextStyle(color: Colors.white70)),
                      onTap: () => _selectFromDrawer('admin'),
                    ),
                  // Tambahkan menu untuk Sender Management
                  ListTile(
                    leading: const Icon(Icons.phone_android, color: const Color(0xFFE53935)),
                    title: const Text("Sender Management", style: TextStyle(color: Colors.white70)),
                    onTap: () => _selectFromDrawer('sender'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: const Color(0xFF0A0A0A),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _animation,
            child: _selectedPage,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border(
            top: BorderSide(color: const Color(0xFF7A1A1A), width: 1),
          ),
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              selectedItemColor: const Color(0xFFE53935),
              unselectedItemColor: Colors.white54,
              currentIndex: _selectedIndex,
              onTap: _onTabSelected,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              items: _buildBottomNavBarItems(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    channel.sink.close(status.goingAway);
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }
}

/// Widget Media (gambar/video dengan audio)
class NewsMedia extends StatefulWidget {
  final String url;
  const NewsMedia({super.key, required this.url});

  @override
  State<NewsMedia> createState() => _NewsMediaState();
}

class _NewsMediaState extends State<NewsMedia> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (_isVideo(widget.url)) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          setState(() {});
          _controller?.setLooping(true);
          _controller?.setVolume(1.0);
          _controller?.play();
        });
    }
  }

  bool _isVideo(String url) {
    return url.endsWith(".mp4") ||
        url.endsWith(".webm") ||
        url.endsWith(".mov") ||
        url.endsWith(".mkv");
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideo(widget.url)) {
      if (_controller != null && _controller!.value.isInitialized) {
        return AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        );
      } else {
        return const Center(
            child: CircularProgressIndicator(color: const Color(0xFFE53935)));
      }
    } else {
      return Image.network(
        widget.url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.black26),
      );
    }
  }
}
