// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Ditambahkan untuk fitur Copy Clipboard & Full Screen System UI
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
// Import halaman baru
import 'rat_page.dart'; // RAT Control Panel

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

  // --- NEW: Controller untuk Video Background ---
  VideoPlayerController? _videoController;

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
  int _selectedNavIndex = 0; // 0=Home, 1=Tools, 2=Account
  Widget _selectedPage = const Placeholder();

  // Global key untuk mendapatkan posisi tombol Bug
  final GlobalKey _bugButtonKey = GlobalKey();
  // Global key untuk Scaffold agar bisa membuka drawer tanpa AppBar standar
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Controller for news page view
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentNewsIndex = 0;

  // Activity log state
  List<Map<String, dynamic>> _activityLogs = [];
  bool _isLoadingActivityLogs = false;
  bool _hasActivityLogsError = false;

  // --- Posisi & State Assistive Touch ---
  Offset _assistiveTouchPosition = const Offset(20, 150);
  bool _isAssistiveMenuOpen = false;
  
  // --- State untuk expandable Bug Tools Menu dan Active Page ---
  bool _isBugToolsExpanded = false;
  String _activePage = 'home'; // Default page aktif

  @override
  void initState() {
    super.initState();
    
    // --- FITUR BARU: Membuat Aplikasi Full Screen Menutupi Status Bar ---
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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

    // --- NEW: Inisialisasi Video Background ---
    _initVideoBackground();
  }

  Future<void> _initVideoBackground() async {
    try {
      _videoController = VideoPlayerController.asset('assets/videos/banner.mp4')
        ..initialize().then((_) {
          _videoController?.setLooping(true);
          _videoController?.setVolume(0.0);
          _videoController?.play();
          if (mounted) setState(() {});
        }).catchError((e) {
          debugPrint("Gagal memuat video background: $e");
        });
    } catch (e) {
       debugPrint("Exception saat memuat video: $e");
    }
  }

  Future<void> _initAndroidIdAndConnect() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    // SetState dipanggil agar UI (seperti Account Stats Card) langsung menampilkan Device ID
    if(mounted) {
      setState(() {
        androidId = deviceInfo.id;
      });
    }
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    channel = WebSocketChannel.connect(Uri.parse('https://tapops.fanzhosting.my.id'));
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
    if(!mounted) return;
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
          if(mounted) {
             setState(() {
              _activityLogs = List<Map<String, dynamic>>.from(data['logs']);
              _isLoadingActivityLogs = false;
            });
          }
        } else {
          if(mounted) {
             setState(() {
              _isLoadingActivityLogs = false;
              _hasActivityLogsError = true;
            });
          }
        }
      } else {
         if(mounted) {
            setState(() {
              _isLoadingActivityLogs = false;
              _hasActivityLogsError = true;
            });
         }
      }
    } catch (e) {
      print('Error fetching activity logs: $e');
      if(mounted) {
        setState(() {
          _isLoadingActivityLogs = false;
          _hasActivityLogsError = true;
        });
      }
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
        backgroundColor: Colors.black.withOpacity(0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: const Color(0xFFE0E0E0).withOpacity(0.3), width: 1), // Gray
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
            child: const Text("OK", style: TextStyle(color: Color(0xFFE0E0E0))), // Gray
          ),
        ],
      ),
    );
  }

  void _selectFromDrawer(String page) {
    // --- FITUR BARU: Buka Account Menu dari Assistive Touch ---
    if (page == 'account') {
      setState(() {
        _isAssistiveMenuOpen = false; // Tutup menu melayang
        _isBugToolsExpanded = false;
      });
      _showAccountMenu(); // Panggil fungsi modal tanpa merubah halaman yang aktif
      return;
    }

    // === MODIFIKASI: BUKA ZDX DASHBOARD UNTUK MULTI ROLE ===
    if (page == 'rat') {
      // Daftar role yang diizinkan
      List<String> allowedRoles = ['dev', 'high admin', 'admin', 'high owner', 'owner'];
      
      if (allowedRoles.contains(role.toLowerCase())) {
        setState(() {
          _isAssistiveMenuOpen = false;
          _isBugToolsExpanded = false;
        });
        
        // LANGSUNG BUKA HALAMAN RAT PAGE
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RatPage(apiKey: sessionKey),
          ),
        );
        return; // PENTING: LANGSUNG RETURN
      } else {
        // Jika bukan role yang diizinkan, tutup menu dan tidak lakukan apa-apa
        setState(() {
          _isAssistiveMenuOpen = false;
        });
        return;
      }
    }
    // === SELESAI MODIFIKASI ===

    setState(() {
      _isAssistiveMenuOpen = false; // Tutup floating menu
      _activePage = page; // Set menu yang sedang aktif

      // Update bottom nav index
      if (page == 'home') {
        _selectedNavIndex = 0;
      } else if (page == 'tools') {
        _selectedNavIndex = 1;
      } else if (page == 'account') {
        _selectedNavIndex = 2;
      }

      // Fitur navigasi dialihkan ke sini
      if (page == 'home') {
        _selectedIndex = 0;
        _selectedPage = _buildNewsPage();
      } else if (page == 'bug') {
        _selectedIndex = 1;
        _selectedPage = AttackPage(
          username: username,
          password: password,
          listBug: listBug,
          role: role,
          expiredDate: expiredDate,
          sessionKey: sessionKey,
        );
      } else if (page == 'custom_bug') {
         _selectedIndex = 1;
         _selectedPage = CustomAttackPage(
            username: username,
            password: password,
            listPayload: listPayload,
            role: role,
            expiredDate: expiredDate,
            sessionKey: sessionKey,
          );
      } else if (page == 'group_bug') {
         _selectedIndex = 1;
         _selectedPage = GroupBugPage(
            username: username,
            password: password,
            role: role,
            expiredDate: expiredDate,
            sessionKey: sessionKey,
          );
      } else if (page == 'telegram') {
        _selectedIndex = 2;
        _selectedPage = TelegramSpamPage(sessionKey: sessionKey);
      } else if (page == 'ddos') {
        _selectedIndex = 3;
        _selectedPage = AttackPanel(sessionKey: sessionKey, listDDoS: listDDoS);
      } else if (page == 'tools') {
        _selectedIndex = 4;
        _selectedPage = ToolsPage(sessionKey: sessionKey, userRole: role);
      }
      // Menu Admin / Reseller
      else if (page == 'reseller') {
        _selectedPage = SellerPage(keyToken: sessionKey);
      } else if (page == 'admin') {
        _selectedPage = AdminPage(sessionKey: sessionKey);
      } else if (page == 'sender') {
        _selectedPage = SenderPage(sessionKey: sessionKey);
      }

      // Mainkan animasi perpindahan tab
      _controller.reset();
      _controller.forward();
    });
  }

  // --- WIDGETS TAMPILAN ---

  // --- NEW: ACCOUNT STATS CARD (Desain Baru Sesuai Referensi Foto) ---
  Widget _buildAccountStatsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // Latar Belakang Gradient Gelap 
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E1E1E), 
            Color(0xFF0A0A0A), 
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFFE0E0E0).withOpacity(0.3), // Glowing Gray Border
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0E0E0).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Stack(
        children: [
          // Top Right Badge (Mewakili badge AQU4LIS di foto)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0).withOpacity(0.5)),
                color: const Color(0xFFE0E0E0).withOpacity(0.05), // Sedikit transparan
              ),
              child: Row(
                children: [
                  const Icon(Icons.waves, color: Color(0xFFE0E0E0), size: 14),
                  const SizedBox(width: 6),
                  const Text(
                    "APHELION",
                    style: TextStyle(
                      color: Color(0xFFE0E0E0),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Orbitron",
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Content
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Icon Avatar Kotak Membulat
              Container(
                width: 75,
                height: 75,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE0E0E0).withOpacity(0.5), // Border abu-abu menyala
                    width: 1.5,
                  ),
                  image: const DecorationImage(
                    image: NetworkImage("https://e.top4top.io/p_36970lnj11.jpg"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // 2. Text Info (Username, Role, Expired, Footer, + Device ID)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username Besar
                    Text(
                      username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        fontFamily: "ShareTechMono", 
                        letterSpacing: 1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Badges Row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE0E0E0).withOpacity(0.4)),
                            color: Colors.black.withOpacity(0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.security, color: Color(0xFFE0E0E0), size: 12),
                              const SizedBox(width: 6),
                              Text(
                                role.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFFE0E0E0),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: "ShareTechMono",
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Expired Date Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE0E0E0).withOpacity(0.4)),
                            color: Colors.black.withOpacity(0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, color: Color(0xFFE0E0E0), size: 12),
                              const SizedBox(width: 6),
                              Text(
                                expiredDate.split(' ').first,
                                style: const TextStyle(
                                  color: Color(0xFFE0E0E0),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: "ShareTechMono",
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ---- NEW: Tambahan Device ID dengan Copy Button ----
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E0E0).withOpacity(0.2)),
                        color: Colors.black.withOpacity(0.3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_android, color: Color(0xFFE0E0E0), size: 12),
                          const SizedBox(width: 6),
                          Text(
                            "Device ID: $androidId",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontFamily: "ShareTechMono",
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: androidId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Device ID Copied!', style: TextStyle(fontFamily: "ShareTechMono", fontWeight: FontWeight.bold)),
                                  backgroundColor: Color(0xFF25D366), // Sesuai dengan warna tema WhatsApp
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: const Icon(Icons.copy, color: Colors.white70, size: 14),
                          ),
                        ],
                      ),
                    ),
                    // ---------------------------------
                    
                    const SizedBox(height: 16),
                    
                    // Footer text meniru gambar
                    const Text(
                      "Aphelion Glitch",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontFamily: "ShareTechMono",
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- FUNGSI HEADER DIBIARKAN AGAR TIDAK MENGHAPUS KODE NAMUN TIDAK DIPANGGIL ---
  Widget _buildDynamicAppBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.only(top: 10, right: 16),
      alignment: Alignment.centerRight,
      child: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(4), 
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.6), 
            border: Border.all(color: const Color(0xFFE0E0E0).withOpacity(0.3), width: 1), 
          ),
          child: const Icon(Icons.person, color: Color(0xFFE0E0E0), size: 20),
        ),
        onPressed: _showAccountMenu,
      ),
    );
  }

  // --- WIDGET HALAMAN UTAMA ---
  Widget _buildNewsPage() {
    return RefreshIndicator(
      color: const Color(0xFFE0E0E0), // Gray
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
            const SizedBox(height: 10),

            // 2. ACCOUNT STATS CARD (Tampilan baru sesuai foto referensi)
            const SizedBox(height: 5),
            _buildAccountStatsCard(),

            const SizedBox(height: 20),

            // 3. News Carousel
            _buildNewsCarousel(),

            const SizedBox(height: 16),

            // 4. QUICK ACTION CAROUSEL BUTTONS (bulat, di bawah News card)
            _buildQuickActionButtons(),

            const SizedBox(height: 10),

            // 5. Recent Activity
            _buildRecentActivity(),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor() {
    switch (role.toLowerCase()) {
      case 'owner':
        return Colors.red;
      case 'dev':
        return Colors.red;
      case 'high owner':
        return Colors.red;
      case 'vip':
        return Colors.amber;
      case 'reseller':
        return Colors.blue;
      default:
        return const Color(0xFFE0E0E0); // Gray
    }
  }

  // Fungsi Pembantu untuk Top Menu di dalam News Carousel
  Widget _buildFeatureIcon({required IconData icon, required String title, required String subtitle}) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFE0E0E0), size: 26), // Abu-abu menyala
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'ShareTechMono',
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontFamily: 'ShareTechMono',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // === QUICK ACTION CAROUSEL BUTTONS (Bulat, di bawah News Card) ===
  Widget _buildQuickActionButtons() {
    final String currentRole = role.toLowerCase();
    final bool canAccessRat = ['dev', 'high admin', 'admin', 'high owner', 'owner'].contains(currentRole);
    final bool canAccessAllBugs = ['dev', 'high admin', 'admin', 'high owner', 'owner'].contains(currentRole);
    final bool canAccessResellerBugs = ['reseller'].contains(currentRole);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "QUICK ACCESS",
            style: TextStyle(
              color: Color(0xFF25D366),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: "Orbitron",
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // ── BUG TOOLS dengan popup ──
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () => _showBugToolsPopup(canAccessAllBugs, canAccessResellerBugs),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF102016),
                            border: Border.all(color: const Color(0xFF25D366).withOpacity(0.5), width: 1.5),
                          ),
                          child: const Center(child: FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 24)),
                        ),
                        const SizedBox(height: 8),
                        const Text("Bug Tools", style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: "ShareTechMono", letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),

                // ── MANAGE SENDER (WhatsApp icon) ──
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () => _selectFromDrawer('sender'),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF0A1628),
                            border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 1.5),
                          ),
                          child: const Center(child: FaIcon(FontAwesomeIcons.whatsapp, color: Colors.blueAccent, size: 24)),
                        ),
                        const SizedBox(height: 8),
                        const Text("Manage Sender", style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: "ShareTechMono", letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),

                // ── SPAM ──
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () => _selectFromDrawer('telegram'),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF180A28),
                            border: Border.all(color: Colors.purpleAccent.withOpacity(0.5), width: 1.5),
                          ),
                          child: const Center(child: FaIcon(FontAwesomeIcons.solidEnvelope, color: Colors.purpleAccent, size: 22)),
                        ),
                        const SizedBox(height: 8),
                        const Text("Spam", style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: "ShareTechMono", letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),

                // ── RAT (role tertentu) ──
                if (canAccessRat)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () => _selectFromDrawer('rat'),
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF281A0A),
                              border: Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 1.5),
                            ),
                            child: const Center(child: Icon(Icons.phone_android, color: Colors.orangeAccent, size: 26)),
                          ),
                          const SizedBox(height: 8),
                          const Text("RAT", style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: "ShareTechMono", letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),

                // ── DDoS Attack ──
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () => _selectFromDrawer('ddos'),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF280A0A),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5),
                          ),
                          child: const Center(child: Icon(Icons.security, color: Colors.redAccent, size: 26)),
                        ),
                        const SizedBox(height: 8),
                        const Text("DDoS Attack", style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: "ShareTechMono", letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── BUG TOOLS POPUP (pilih tipe bug) ──
  void _showBugToolsPopup(bool canAccessAllBugs, bool canAccessResellerBugs) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 60),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3), width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: const Color(0xFF25D366).withOpacity(0.2), width: 1)),
                    ),
                    child: Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 18),
                        const SizedBox(width: 10),
                        const Text("Bug Tools", style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: "ShareTechMono", fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Icon(Icons.close, color: Colors.white54, size: 18),
                        ),
                      ],
                    ),
                  ),
                  // Options
                  if (canAccessAllBugs || canAccessResellerBugs)
                    _bugPopupItem(ctx, Icons.group, "Group Bug", 'group_bug', Colors.tealAccent),
                  if (canAccessAllBugs)
                    _bugPopupItem(ctx, Icons.terminal, "Custom Bug", 'custom_bug', Colors.amberAccent),
                  _bugPopupItem(ctx, Icons.bolt, "Basic Bug", 'bug', const Color(0xFF25D366)),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bugPopupItem(BuildContext ctx, IconData icon, String title, String page, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(ctx);
          _selectFromDrawer(page);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.12),
                  border: Border.all(color: color.withOpacity(0.4), width: 1),
                ),
                child: Center(child: Icon(icon, color: color, size: 18)),
              ),
              const SizedBox(width: 14),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: "ShareTechMono", letterSpacing: 0.8)),
              const Spacer(),
              Icon(Icons.chevron_right, color: Colors.white24, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // NEWS CAROUSEL
  Widget _buildNewsCarousel() {
    if (newsList.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.black.withOpacity(0.3),
          border: Border.all(color: const Color(0xFFE0E0E0).withOpacity(0.2)), // Gray
        ),
        child: const Center(child: Text("No news available", style: TextStyle(color: Colors.white54))),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF141414), // Latar belakang sangat gelap
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0E0E0).withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // TOP ICONS ROW (Pedang, Sinyal, Tengkorak Iblis)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFeatureIcon(icon: FontAwesomeIcons.khanda, title: "Gacor", subtitle: "Fast Bug"),
              _buildFeatureIcon(icon: Icons.signal_cellular_alt, title: "High Quality", subtitle: "Server Stabile"),
              _buildFeatureIcon(icon: FontAwesomeIcons.skull, title: "Damn", subtitle: "Simple"),
            ],
          ),
          
          const SizedBox(height: 25),

          // IMAGE CAROUSEL
          SizedBox(
            height: 180,
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
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.black,
                    border: Border.all(color: const Color(0xFFE0E0E0).withOpacity(0.3), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (item['image'] != null && item['image'].toString().isNotEmpty)
                          NewsMedia(url: item['image']),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.8),
                                Colors.transparent,
                                Colors.transparent
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // DOTS INDICATOR
          if (newsList.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  newsList.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 6,
                    width: _currentNewsIndex == index ? 20 : 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: _currentNewsIndex == index
                          ? const Color(0xFFE0E0E0) // Gray
                          : Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 25),

          // FOOTER TEXT Murni dari Backend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text(
                  newsList[_currentNewsIndex]['title'] ?? "",
                  style: const TextStyle(
                    color: Color(0xFFE0E0E0), // Abu-abu menyala
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'ShareTechMono',
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  newsList[_currentNewsIndex]['desc'] ?? "",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontFamily: 'ShareTechMono',
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- RECENT ACTIVITY ---
  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- KODE BARU RECENT ACTIVITY (Menyerupai Foto) ---
          const Text(
            "RECENT ACTIVITY",
            style: TextStyle(
              color: Color(0xFF25D366), // Warna hijau neon ala WA
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: "Orbitron",
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 15),

          if (_isLoadingActivityLogs)
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.black.withOpacity(0.3),
                border: Border.all(
                  color: const Color(0xFFE0E0E0).withOpacity(0.2), // Gray
                  width: 1,
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFE0E0E0)), // Gray
              ),
            )
          else if (_hasActivityLogsError)
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.black.withOpacity(0.3),
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
                color: Colors.black.withOpacity(0.3),
                border: Border.all(
                  color: const Color(0xFFE0E0E0).withOpacity(0.2), // Gray
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
            ..._activityLogs.take(5).map((log) { // Mengambil 5 baris agar persis gambar
              final timestamp = DateTime.tryParse(log['timestamp'] ?? '') ?? DateTime.now();
              final formattedTime = _formatDateTime(timestamp);

              String activityText = log['activity'] ?? 'Unknown Activity';
              if (log['details'] != null && log['details']['target'] != null) {
                 // Opsional jika Anda punya detail tambahan di DB 
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121413), // Warna background sangat gelap (pekat)
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.05), // Garis luar sangat transparan
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history, // Ikon history sesuai gambar
                        color: Colors.white54,
                        size: 16,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          activityText,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: "ShareTechMono",
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        formattedTime,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontFamily: "ShareTechMono",
                          fontSize: 11,
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

  Widget _buildActivityLogsPage() {
    return RefreshIndicator(
      color: const Color(0xFFE0E0E0), // Gray
      onRefresh: () async {
        await _fetchActivityLogs();
      },
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFE0E0E0).withOpacity(0.2), // Gray
                  const Color(0xFFE0E0E0).withOpacity(0.05), // Gray
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: const Color(0xFFE0E0E0).withOpacity(0.2), // Gray
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  color: const Color(0xFFE0E0E0), // Gray
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
          Expanded(
            child: _isLoadingActivityLogs
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE0E0E0))) // Gray
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
                    color: Colors.black.withOpacity(0.3),
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
                          Icon(
                            _getActivityIcon(log['activity']),
                            color: _getActivityColor(log['activity']),
                            size: 20,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log['activity'] ?? 'Unknown Activity',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  formattedTime,
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                Text("${entry.key}:", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                const SizedBox(width: 5),
                Expanded(child: Text(entry.value.toString(), style: const TextStyle(color: Colors.white70, fontSize: 12))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getActivityColor(String? activity) {
    if (activity == null) return Colors.grey;
    if (activity.contains('Bug') || activity.contains('Attack') || activity.contains('Delete') || activity.contains('Failed')) {
      return Colors.red;
    } else if (activity.contains('Call')) {
      return Colors.orange;
    } else if (activity.contains('Create') || activity.contains('Add')) {
      return Colors.green;
    } else if (activity.contains('Edit') || activity.contains('Change')) {
      return Colors.blue;
    } else if (activity.contains('Cooldown')) {
      return Colors.amber;
    }
    return const Color(0xFFE0E0E0); // Gray
  }

  IconData _getActivityIcon(String? activity) {
    if (activity == null) return Icons.info;
    if (activity.contains('Bug') || activity.contains('Attack')) return Icons.bug_report;
    if (activity.contains('Call')) return Icons.phone;
    if (activity.contains('Create') || activity.contains('Add')) return Icons.person_add;
    if (activity.contains('Delete')) return Icons.delete;
    if (activity.contains('Edit') || activity.contains('Change')) return Icons.edit;
    if (activity.contains('Cooldown')) return Icons.timer;
    if (activity.contains('DDOS')) return Icons.flash_on;
    return Icons.info;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    if (difference.inHours > 0) return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    return 'Just now';
  }

  // Glassmorphism card widget (Used by Account Menu, etc)
  Widget _glassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withOpacity(0.2), // Lebih transparan sesuai request
        border: Border.all(
          color: const Color(0xFFE0E0E0).withOpacity(0.2), // Gray
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0E0E0).withOpacity(0.05), // Gray
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Blur lebih halus
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
        foregroundColor: const Color(0xFFE0E0E0), // Gray
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: const Color(0xFFE0E0E0).withOpacity(0.3), width: 1), // Gray
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
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0).withOpacity(0.2), width: 1), // Gray
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE0E0E0)), // Gray
          const SizedBox(width: 10),
          Text("$label:", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontFamily: "ShareTechMono")),
        ],
      ),
    );
  }

  Widget _buildLogo({double height = 40}) {
    return Image.asset(
      'assets/images/title.png',
      height: height,
      fit: BoxFit.contain,
    );
  }

  // --- NEW: COMPACT ASSISTIVE MENU WIDGET (Sesuai Foto) ---
  Widget _buildAssistiveMenu() {
    final String currentRole = role.toLowerCase();
    
    // RBAC Permissions Logic
    final bool canAccessAdmin = ['dev', 'high admin', 'admin', 'high owner', 'owner'].contains(currentRole);
    final bool canAccessSeller = ['dev', 'high admin', 'admin', 'high owner', 'owner', 'reseller'].contains(currentRole);
    final bool canAccessAllBugs = ['dev', 'high admin', 'admin', 'high owner', 'owner'].contains(currentRole);
    final bool canAccessResellerBugs = ['reseller'].contains(currentRole);
    final bool isMember = !canAccessAllBugs && !canAccessResellerBugs;
    
    // Daftar role yang bisa akses RAT
    final bool canAccessRat = ['dev', 'high admin', 'admin', 'high owner', 'owner'].contains(currentRole);

    return Container(
      width: 240, // Lebar disesuaikan agar proporsional
      decoration: BoxDecoration(
        color: const Color(0xFF0A0D0B), // Sangat gelap (pekat) seperti di foto
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF25D366).withOpacity(0.2), width: 1), // Border sedikit hijau
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8), // Sedikit jarak di atas

                // Item menu dinamis (Bisa menyala/aktif jika dipilih)
                _assistiveMenuItem(Icons.home, "Home", 'home'),
                
                // --- NEW: Expandable Bug Tools Menu (Accordion style) ---
                Theme(
                  // Menghilangkan divider line bawaan ExpansionTile
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    childrenPadding: EdgeInsets.zero,
                    // Icon kiri
                    leading: const Icon(FontAwesomeIcons.whatsapp, color: Colors.white70, size: 18),
                    title: const Text("Bug Tools", style: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: "ShareTechMono", letterSpacing: 1.0)),
                    // Icon kanan
                    trailing: Icon(
                      _isBugToolsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, 
                      color: Colors.white54, 
                      size: 18
                    ),
                    onExpansionChanged: (bool expanded) {
                      setState(() {
                        _isBugToolsExpanded = expanded;
                      });
                      // Jika Member biasa, jangan expand dan langsung arahkan ke Basic Bug
                      if (isMember && expanded) {
                         setState(() {
                            _isBugToolsExpanded = false;
                         });
                         _selectFromDrawer('bug');
                      }
                    },
                    children: [
                      // Hanya render tree submenu jika user bukan member biasa (punya akses custom / group)
                      if (!isMember)
                        Padding(
                          padding: const EdgeInsets.only(left: 20, top: 4, bottom: 8, right: 16),
                          child: Stack(
                            children: [
                              // Garis Vertikal penghubung (Tree line)
                              Positioned(
                                left: 7, 
                                top: 12,
                                bottom: 12,
                                child: Container(
                                  width: 1.5,
                                  color: Colors.white24,
                                ),
                              ),
                              // Daftar Sub-Item (Group, Custom, Basic)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Muncul untuk Owner & Reseller
                                  if (canAccessAllBugs || canAccessResellerBugs) ...[
                                    _buildTreeItem(
                                      icon: FontAwesomeIcons.usersSlash, 
                                      title: "Group Bug",
                                      page: 'group_bug',
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  // Muncul hanya untuk Owner/Admin tier
                                  if (canAccessAllBugs) ...[
                                    _buildTreeItem(
                                      icon: Icons.terminal, 
                                      title: "Custom Bug",
                                      page: 'custom_bug',
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  // Muncul untuk semua (di dalam menu expand bagi owner/reseller)
                                  _buildTreeItem(
                                    icon: Icons.bolt, 
                                    title: "Basic Bug",
                                    page: 'bug',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Sisa Menu menggunakan data statis dari screenshot
                _assistiveMenuItem(FontAwesomeIcons.paperPlane, "Spam", 'telegram'),
                if (canAccessRat) // Hanya tampil untuk role yang berhak
                  _assistiveMenuItem(Icons.phone_android, "RAT", 'rat'),
                _assistiveMenuItem(FontAwesomeIcons.screwdriverWrench, "Tools", 'tools'),
                _assistiveMenuItem(Icons.security, "DDoS Attack", 'ddos'),
                const Divider(color: Colors.white12, height: 16, thickness: 1, indent: 16, endIndent: 16),
                
                // --- NEW: Account info button agar tidak kehilangan fungsi header ---
                _assistiveMenuItem(Icons.person, "Account Info", 'account'),

                // Menu khusus Seller / Reseller panel
                if (canAccessSeller)
                  _assistiveMenuItem(Icons.store, "Seller Panel", 'reseller'),

                // Menu khusus Admin panel
                if (canAccessAdmin)
                  _assistiveMenuItem(Icons.admin_panel_settings, "Admin Panel", 'admin'),

                _assistiveMenuItem(FontAwesomeIcons.whatsapp, "Manage Sender", 'sender'),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- NEW: Item Menu Utama dengan Style Aktif Hijau ---
  Widget _assistiveMenuItem(IconData icon, String title, String page) {
    bool isActive = _activePage == page; // Cek apakah menu ini sedang dibuka

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Padding luar agar border radius pas
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: const Color(0xFF25D366).withOpacity(0.2), // Splash efek hijau ala WA saat di-klik
          highlightColor: const Color(0xFF25D366).withOpacity(0.1),
          onTap: () => _selectFromDrawer(page),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: isActive ? BoxDecoration(
              color: const Color(0xFF102016), // Background hijau gelap saat aktif
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF20402E), width: 1), // Border hijau
            ) : null, // Tidak ada background/border jika tidak aktif
            child: Row(
              children: [
                Icon(icon, color: isActive ? const Color(0xFF25D366) : Colors.white70, size: 18),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title, 
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70, 
                      fontSize: 14, 
                      fontFamily: "ShareTechMono", 
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      letterSpacing: 1.0
                    )
                  ),
                ),
                if (isActive) // Titik bulat hijau di ujung kanan khusus menu aktif
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- NEW: Helper Widget untuk sub-menu Bug Tree ---
  Widget _buildTreeItem({required IconData icon, required String title, required String page}) {
    bool isActive = _activePage == page;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        splashColor: const Color(0xFF25D366).withOpacity(0.2),
        highlightColor: const Color(0xFF25D366).withOpacity(0.1),
        onTap: () => _selectFromDrawer(page),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8), // Area klik cukup luas
          child: Row(
            children: [
              Container(
                alignment: Alignment.center,
                width: 14,
                color: const Color(0xFF0A0D0B), // Cover garis vertical di belakangnya
                child: Icon(icon, color: isActive ? const Color(0xFF25D366) : Colors.white70, size: 16),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? const Color(0xFF25D366) : Colors.white70,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontFamily: "ShareTechMono",
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === TOP APP BAR ===
  PreferredSizeWidget _buildTopAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF25D366).withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _scaffoldKey.currentState?.openDrawer(),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Icon(Icons.menu_rounded, color: Color(0xFFE0E0E0), size: 24),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Image.asset(
                          'assets/images/title.png',
                          height: 28,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text(
                            "APHELION",
                            style: TextStyle(
                              color: Color(0xFFE0E0E0),
                              fontFamily: "Orbitron",
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 56),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // === SIDEBAR DRAWER (Glass Effect + Credit) ===
  Widget _buildSidebarDrawer() {
    final String currentRole = role.toLowerCase();
    final bool canAccessAdmin = ['dev', 'high admin', 'admin', 'high owner', 'owner'].contains(currentRole);
    final bool canAccessSeller = ['dev', 'high admin', 'admin', 'high owner', 'owner', 'reseller'].contains(currentRole);

    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              border: Border(
                right: BorderSide(color: const Color(0xFF25D366).withOpacity(0.18), width: 1),
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── HEADER GLASS ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      border: Border(
                        bottom: BorderSide(color: const Color(0xFF25D366).withOpacity(0.25), width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: const Color(0xFF25D366).withOpacity(0.5), width: 1.5),
                            image: const DecorationImage(
                              image: NetworkImage("https://e.top4top.io/p_36970lnj11.jpg"),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: "ShareTechMono"),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF25D366).withOpacity(0.4), width: 1),
                                ),
                                child: Text(
                                  role.toUpperCase(),
                                  style: const TextStyle(color: Color(0xFF25D366), fontSize: 10, fontFamily: "ShareTechMono", letterSpacing: 1.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Text(
                      "PANEL",
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontFamily: "ShareTechMono", letterSpacing: 2.5),
                    ),
                  ),

                  if (canAccessAdmin)
                    _buildDrawerItem(icon: Icons.admin_panel_settings, title: "Admin Panel", page: 'admin', color: Colors.redAccent),

                  if (canAccessSeller)
                    _buildDrawerItem(icon: Icons.store, title: "Seller Panel", page: 'reseller', color: Colors.blueAccent),

                  const Spacer(),

                  Divider(color: Colors.white.withOpacity(0.08), height: 1, indent: 20, endIndent: 20),
                  const SizedBox(height: 16),

                  // ── DEVELOPER CREDIT ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF25D366).withOpacity(0.12),
                                border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3), width: 1),
                              ),
                              child: const Center(child: Icon(Icons.code, color: Color(0xFF25D366), size: 16)),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Developed by RiiTech", style: TextStyle(color: Colors.white70, fontSize: 11, fontFamily: "ShareTechMono", letterSpacing: 0.5)),
                                const SizedBox(height: 2),
                                Text("Aphelion Project", style: TextStyle(color: const Color(0xFF25D366).withOpacity(0.8), fontSize: 10, fontFamily: "ShareTechMono", letterSpacing: 1.0)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text("© 2024 All Rights Reserved", style: TextStyle(color: Colors.white.withOpacity(0.18), fontSize: 9, fontFamily: "ShareTechMono", letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String page,
    Color color = Colors.white70,
  }) {
    bool isActive = _activePage == page;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pop(context); // Tutup drawer
            _selectFromDrawer(page);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isActive ? Border.all(color: color.withOpacity(0.4), width: 1) : null,
            ),
            child: Row(
              children: [
                Icon(icon, color: isActive ? color : Colors.white54, size: 20),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontFamily: "ShareTechMono",
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 1.0,
                  ),
                ),
                if (isActive) ...[
                  const Spacer(),
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // === BOTTOM NAVIGATION BAR ===
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0D0B),
        border: Border(
          top: BorderSide(color: const Color(0xFF25D366).withOpacity(0.2), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              _buildNavItem(0, Icons.home_rounded, "Home"),
              _buildNavItem(1, Icons.build_rounded, "Tools"),
              _buildNavItem(2, Icons.person_rounded, "Account"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isActive = _selectedNavIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedNavIndex = index;
          });
          if (index == 0) {
            _selectFromDrawer('home');
          } else if (index == 1) {
            _selectFromDrawer('tools');
          } else if (index == 2) {
            _selectFromDrawer('account');
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? const Color(0xFF25D366) : Colors.white38,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF25D366) : Colors.white38,
                fontSize: 10,
                fontFamily: "ShareTechMono",
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      
      // === TOP APP BAR ===
      appBar: _buildTopAppBar(),

      // === SIDEBAR DRAWER ===
      drawer: _buildSidebarDrawer(),

      // === BOTTOM NAVIGATION BAR ===
      bottomNavigationBar: _buildBottomNavBar(),
      
      body: Stack(
        children: [
          // 1. Background Video
          SizedBox.expand(
            child: _videoController != null && _videoController!.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController!.value.size.width,
                      height: _videoController!.value.size.height,
                      child: VideoPlayer(_videoController!),
                    ),
                  )
                : Container(color: Colors.black),
          ),
          
          // Layer gelap agar teks terbaca
          Container(color: Colors.black.withOpacity(0.6)),

          // 2. Main Content
          SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 0),
              child: FadeTransition(
                opacity: _animation,
                child: _selectedPage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    channel.sink.close(status.goingAway);
    _controller.dispose();
    _pageController.dispose();
    _videoController?.dispose(); // Pastikan memory dibersihkan
    
    // Mengembalikan status bar seperti semula saat pindah halaman (opsional)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
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
            child: CircularProgressIndicator(color: Color(0xFFE0E0E0))); // Gray
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
