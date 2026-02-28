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

// ─────────────────────────────────────────────
// THEME CONSTANTS  (blue palette, like screenshot)
// ─────────────────────────────────────────────
const _kAccent      = Color(0xFF4B8EFF);   // primary blue
const _kAccentLight = Color(0xFF82B4FF);   // lighter blue
const _kBg          = Color(0xFF0A1628);   // deep navy background
const _kSurface     = Color(0xFF0F2040);   // card surface
const _kBorder      = Color(0xFF1E3A5F);   // border / divider

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

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
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

  // Navbar: 0=Home, 1=Tools, 2=Profile
  int _selectedIndex = 0;
  Widget _selectedPage = const Placeholder();

  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentNewsIndex = 0;

  List<Map<String, dynamic>> _activityLogs = [];
  bool _isLoadingActivityLogs = false;
  bool _hasActivityLogsError = false;

  @override
  void initState() {
    super.initState();
    sessionKey    = widget.sessionKey;
    username      = widget.username;
    password      = widget.password;
    role          = widget.role;
    expiredDate   = widget.expiredDate;
    listBug       = widget.listBug;
    listPayload   = widget.listPayload;
    listDDoS      = widget.listDDoS;
    newsList      = widget.news;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    _selectedPage = _buildNewsPage();
    _initAndroidIdAndConnect();
    _fetchActivityLogs();
  }

  Future<void> _initAndroidIdAndConnect() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    androidId = deviceInfo.id;
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    channel = WebSocketChannel.connect(
        Uri.parse('wss://tapops.fanzhosting.my.id'));
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
            _handleInvalidSession(
                "Your account has logged on another device.");
          } else if (data['reason'] == 'keyInvalid') {
            _handleInvalidSession(
                "Key is not valid. Please login again.");
          }
        }
      }
    });
  }

  Future<void> _fetchActivityLogs() async {
    setState(() {
      _isLoadingActivityLogs = true;
      _hasActivityLogsError = false;
    });
    try {
      final response = await http.get(
        Uri.parse(
            'https://tapops.fanzhosting.my.id/api/user/getActivityLogs?key=$sessionKey'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['valid'] == true && data['logs'] != null) {
          setState(() {
            _activityLogs =
                List<Map<String, dynamic>>.from(data['logs']);
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
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _kAccent.withOpacity(0.3), width: 1),
        ),
        title: const Text("⚠️ Session Expired",
            style: TextStyle(
                color: Colors.white, fontFamily: "Orbitron")),
        content: Text(message,
            style: const TextStyle(
                color: Colors.white70, fontFamily: "ShareTechMono")),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text("OK",
                style: TextStyle(color: _kAccent)),
          ),
        ],
      ),
    );
  }

  // ─── NAVBAR TAB HANDLER ──────────────────────────────────────────────────
  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
      _controller.reset();
      _controller.forward();

      if (index == 0) {
        _selectedPage = _buildNewsPage();
      } else if (index == 1) {
        _selectedPage = ToolsPage(sessionKey: sessionKey, userRole: role);
      } else if (index == 2) {
        // Profile tab – show account bottom sheet and stay on current page
        _showAccountMenu();
        return;
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

  // ─── MAIN HOME PAGE ──────────────────────────────────────────────────────
  Widget _buildNewsPage() {
    return RefreshIndicator(
      color: _kAccent,
      onRefresh: () async {
        await _fetchActivityLogs();
        await Future.delayed(const Duration(seconds: 1));
        setState(() {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            _buildNewsCarousel(),
            // ← Quick actions directly below the thumbnail
            _buildQuickActionsHorizontal(),
            _buildRecentActivity(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─── WELCOME BANNER ──────────────────────────────────────────────────────
  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            _kAccent.withOpacity(0.85),
            const Color(0xFF1A3A6E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: _kAccent.withOpacity(0.25),
              blurRadius: 20,
              spreadRadius: 2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row – icon + title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.grid_view_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Welcome back",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                          fontFamily: "ShareTechMono")),
                  Text("$username Dashboard",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Orbitron")),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stats row
          Row(
            children: [
              Expanded(
                child: _miniStatCard(
                  icon: Icons.people_alt_outlined,
                  label: "Online Users",
                  value: "0",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _miniStatCard(
                  icon: Icons.link,
                  label: "Connections",
                  value: "0",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStatCard(
      {required IconData icon,
      required String label,
      required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11)),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── NEWS CAROUSEL ───────────────────────────────────────────────────────
  Widget _buildNewsCarousel() {
    if (newsList.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _kSurface,
          border: Border.all(color: _kBorder, width: 1),
        ),
        child: const Center(
          child: Text("No news available",
              style: TextStyle(
                  color: Colors.white54, fontFamily: "ShareTechMono")),
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
            onPageChanged: (i) =>
                setState(() => _currentNewsIndex = i),
            itemBuilder: (context, index) {
              final item = newsList[index];
              return Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _kSurface,
                  boxShadow: [
                    BoxShadow(
                        color: _kAccent.withOpacity(0.1),
                        blurRadius: 15,
                        spreadRadius: 2),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (item['image'] != null &&
                          item['image'].toString().isNotEmpty)
                        NewsMedia(url: item['image']),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withOpacity(0.75),
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
                            Text(item['title'] ?? 'No Title',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontFamily: "Orbitron",
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(item['desc'] ?? '',
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontFamily: "ShareTechMono"),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
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
            children: List.generate(newsList.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 6),
                height: 8,
                width: _currentNewsIndex == i ? 24 : 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _currentNewsIndex == i
                      ? _kAccent
                      : Colors.white.withOpacity(0.3),
                ),
              );
            }),
          ),
      ],
    );
  }

  // ─── QUICK ACTIONS – HORIZONTAL SCROLL (below thumbnail) ─────────────────
  Widget _buildQuickActionsHorizontal() {
    final actions = [
      _QuickAction(
        icon: FontAwesomeIcons.telegram,
        label: "Join Channel",
        color: const Color(0xFF26A5E4),
        onTap: () async {
          final uri = Uri.parse("tg://resolve?domain=aphelionlabs");
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri,
                mode: LaunchMode.externalApplication);
          } else {
            await launchUrl(Uri.parse("https://t.me/aphelionlabs"),
                mode: LaunchMode.externalApplication);
          }
        },
      ),
      _QuickAction(
        icon: FontAwesomeIcons.whatsapp,
        label: "WA Bug",
        color: const Color(0xFF25D366),
        onTap: () {
          setState(() {
            _selectedPage = AttackPage(
              username: username,
              password: password,
              listBug: listBug,
              role: role,
              expiredDate: expiredDate,
              sessionKey: sessionKey,
            );
            _selectedIndex = 0;
          });
        },
      ),
      _QuickAction(
        icon: Icons.phone_android,
        label: "Manage Sender",
        color: _kAccentLight,
        onTap: () {
          setState(() {
            _selectedPage = SenderPage(sessionKey: sessionKey);
            _selectedIndex = 0;
          });
        },
      ),
      _QuickAction(
        icon: FontAwesomeIcons.paperPlane,
        label: "Telegram",
        color: const Color(0xFF26A5E4),
        onTap: () {
          setState(() {
            _selectedPage =
                TelegramSpamPage(sessionKey: sessionKey);
            _selectedIndex = 0;
          });
        },
      ),
      _QuickAction(
        icon: FontAwesomeIcons.server,
        label: "DDoS",
        color: Colors.redAccent,
        onTap: () {
          setState(() {
            _selectedPage = AttackPanel(
                sessionKey: sessionKey, listDDoS: listDDoS);
            _selectedIndex = 0;
          });
        },
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 16, bottom: 12),
            child: Text(
              "Quick Actions",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: "Orbitron",
              ),
            ),
          ),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: actions.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 12),
              itemBuilder: (_, i) =>
                  _buildHorizontalActionItem(actions[i]),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildHorizontalActionItem(_QuickAction action) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _kSurface,
          border: Border.all(
              color: action.color.withOpacity(0.35), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: FaIcon(action.icon,
                  color: action.color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── RECENT ACTIVITY ─────────────────────────────────────────────────────
  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Recent Activity",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Orbitron")),
              TextButton(
                onPressed: _fetchActivityLogs,
                child: const Text("Refresh",
                    style:
                        TextStyle(color: _kAccent, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoadingActivityLogs)
            _activityPlaceholder(
                child: const CircularProgressIndicator(
                    color: _kAccent))
          else if (_hasActivityLogsError)
            _activityPlaceholder(
                child: const Text("Failed to load activity logs",
                    style: TextStyle(
                        color: Colors.white54, fontSize: 13)))
          else if (_activityLogs.isEmpty)
            _activityPlaceholder(
                child: const Text("No activity logs available",
                    style: TextStyle(
                        color: Colors.white54, fontSize: 13)))
          else
            ..._activityLogs.take(3).map((log) {
              final ts = DateTime.tryParse(
                      log['timestamp'] ?? '') ??
                  DateTime.now();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _kSurface,
                    border: Border.all(
                        color: _getActivityColor(log['activity'])
                            .withOpacity(0.25),
                        width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getActivityColor(log['activity'])
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                            _getActivityIcon(log['activity']),
                            color: _getActivityColor(
                                log['activity']),
                            size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                                log['activity'] ??
                                    'Unknown Activity',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 13)),
                            if (log['details'] != null &&
                                log['details']['target'] !=
                                    null)
                              Text(
                                  "Target: ${log['details']['target']}",
                                  style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11)),
                          ],
                        ),
                      ),
                      Text(_formatDateTime(ts),
                          style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11)),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _activityPlaceholder({required Widget child}) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _kSurface,
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: Center(child: child),
    );
  }

  // ─── ACTIVITY LOG HELPERS ─────────────────────────────────────────────────
  Color _getActivityColor(String? activity) {
    if (activity == null) return Colors.grey;
    if (activity.contains('Bug') || activity.contains('Attack'))
      return Colors.red;
    if (activity.contains('Call')) return Colors.orange;
    if (activity.contains('Create') || activity.contains('Add'))
      return Colors.green;
    if (activity.contains('Delete') || activity.contains('Failed'))
      return Colors.red;
    if (activity.contains('Edit') || activity.contains('Change'))
      return Colors.blue;
    if (activity.contains('Cooldown')) return Colors.amber;
    return _kAccent;
  }

  IconData _getActivityIcon(String? activity) {
    if (activity == null) return Icons.info;
    if (activity.contains('Bug') || activity.contains('Attack'))
      return Icons.bug_report;
    if (activity.contains('Call')) return Icons.phone;
    if (activity.contains('Create') || activity.contains('Add'))
      return Icons.person_add;
    if (activity.contains('Delete')) return Icons.delete;
    if (activity.contains('Edit') || activity.contains('Change'))
      return Icons.edit;
    if (activity.contains('Cooldown')) return Icons.timer;
    if (activity.contains('DDOS')) return Icons.flash_on;
    return Icons.info;
  }

  String _formatDateTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0)
      return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  // ─── ROLE COLOR ───────────────────────────────────────────────────────────
  Color _getRoleColor() {
    switch (role.toLowerCase()) {
      case 'owner':
        return Colors.redAccent;
      case 'vip':
        return Colors.amber;
      case 'reseller':
        return _kAccentLight;
      default:
        return _kAccent;
    }
  }

  // ─── GLASS HELPERS ────────────────────────────────────────────────────────
  Widget _glassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _kSurface.withOpacity(0.8),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
              color: _kAccent.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 4),
        ],
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

  Widget _glassButton(
      {required Icon icon,
      required Text label,
      required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      icon: icon,
      label: label,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: _kAccent,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side:
              BorderSide(color: _kAccent.withOpacity(0.4), width: 1),
        ),
      ),
      onPressed: onPressed,
    );
  }

  // ─── ACCOUNT BOTTOM SHEET ─────────────────────────────────────────────────
  void _showAccountMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _glassCard(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Account Info",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontFamily: "Orbitron")),
                const SizedBox(height: 16),
                _infoCard(Icons.person, "Username", username),
                _infoCard(
                    Icons.date_range, "Expired", expiredDate),
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
                    final prefs =
                        await SharedPreferences.getInstance();
                    await prefs.clear();
                    if (!mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const LoginPage()),
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
      padding:
          const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _kAccent.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: _kAccent),
          const SizedBox(width: 10),
          Text("$label:",
              style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: _getRoleColor(),
                  fontFamily: "ShareTechMono",
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLogo({double height = 40}) {
    return Image.asset('assets/images/title.png',
        height: height, fit: BoxFit.contain);
  }

  // ─── BOTTOM NAVBAR (Home / Tools / Profile) ───────────────────────────────
  List<BottomNavigationBarItem> _buildBottomNavBarItems() {
    return [
      BottomNavigationBarItem(
        icon: Image.asset('assets/images/home.png',
            width: 28, height: 28),
        label: "Home",
      ),
      BottomNavigationBarItem(
        icon: Image.asset('assets/images/tools.png',
            width: 28, height: 28),
        label: "Tools",
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.account_circle_outlined, size: 28),
        activeIcon: Icon(Icons.account_circle, size: 28),
        label: "Profile",
      ),
    ];
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _kBg,
      appBar: AppBar(
        title: _buildLogo(height: 40),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: _kBg.withOpacity(0.85),
            border: Border(
              bottom: BorderSide(
                  color: _kAccent.withOpacity(0.2), width: 1),
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
            icon: const Icon(Icons.notifications_none_rounded,
                color: Colors.white70),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.account_circle,
                color: _kAccent),
            onPressed: _showAccountMenu,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Container(
        color: _kBg,
        child: SafeArea(
          child: FadeTransition(
            opacity: _animation,
            child: _selectedPage,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _kSurface,
          border: Border(
              top: BorderSide(
                  color: _kBorder, width: 1)),
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              selectedItemColor: _kAccent,
              unselectedItemColor: Colors.white38,
              currentIndex: _selectedIndex,
              onTap: _onTabSelected,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12),
              items: _buildBottomNavBarItems(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: _kSurface.withOpacity(0.95),
          border: Border(
              right: BorderSide(color: _kBorder, width: 1)),
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _kAccent.withOpacity(0.3),
                        Colors.transparent
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        _buildLogo(height: 36),
                        const SizedBox(height: 16),
                        _infoCard(
                            Icons.person, "Username", username),
                        _infoCard(Icons.admin_panel_settings,
                            "Role", role),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (role == "reseller" || role == "owner")
                  _drawerItem(Icons.person_add, "Reseller Page",
                      () => _selectFromDrawer('reseller')),
                if (role == "owner")
                  _drawerItem(Icons.settings, "Admin Page",
                      () => _selectFromDrawer('admin')),
                _drawerItem(Icons.phone_android,
                    "Sender Management",
                    () => _selectFromDrawer('sender')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(
      IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: _kAccent),
      title: Text(title,
          style: const TextStyle(color: Colors.white70)),
      onTap: onTap,
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

// ─── DATA CLASS FOR QUICK ACTION ─────────────────────────────────────────────
class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

// ─── NEWS MEDIA WIDGET ───────────────────────────────────────────────────────
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
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.url))
            ..initialize().then((_) {
              setState(() {});
              _controller?.setLooping(true);
              _controller?.setVolume(1.0);
              _controller?.play();
            });
    }
  }

  bool _isVideo(String url) =>
      url.endsWith(".mp4") ||
      url.endsWith(".webm") ||
      url.endsWith(".mov") ||
      url.endsWith(".mkv");

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
      }
      return const Center(
          child: CircularProgressIndicator(color: _kAccent));
    }
    return Image.network(
      widget.url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Container(color: Colors.black26),
    );
  }
}
