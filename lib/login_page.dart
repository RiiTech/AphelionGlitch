import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui';

const String baseUrl = "https://tapops.fanzhosting.my.id";

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final userController = TextEditingController();
  final passController = TextEditingController();
  bool isLoading = false;
  String? androidId;
  bool _isObscure = true; // Tambahan untuk fitur toggle mata password

  late VideoPlayerController _videoController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    initLogin();

    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();

    // Initialize video controller
    _videoController = VideoPlayerController.asset('assets/videos/login.mp4')
      ..initialize().then((_) {
        setState(() {});
        _videoController.setLooping(true);
        _videoController.play();
        _videoController.setVolume(0);
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> initLogin() async {
    androidId = await getAndroidId();

    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString("username");
    final savedPass = prefs.getString("password");
    final savedKey = prefs.getString("key");

    if (savedUser != null && savedPass != null && savedKey != null) {
      final uri = Uri.parse(
        "$baseUrl/api/auth/myInfo?username=$savedUser&password=$savedPass&androidId=$androidId&key=$savedKey",
      );
      try {
        final res = await http.get(uri);
        final data = jsonDecode(res.body);

        if (data['valid'] == true) {
          // DIUBAH: Navigasi ke splash screen setelah auto-login
          Navigator.pushReplacementNamed(
            context,
            '/splash', 
            arguments: {
              'username': savedUser,
              'password': savedPass,
              'role': data['role'],
              'key': data['key'],
              'expiredDate': data['expiredDate'],
              'listBug': data['listBug'] ?? [],
              'listPayload': data['listPayload'] ?? [],
              'listDDoS': data['listDDoS'] ?? [],
              'news': data['news'] ?? [],
            },
          );
        }
      } catch (_) {}
    }
  }

  Future<String> getAndroidId() async {
    final deviceInfo = DeviceInfoPlugin();
    final android = await deviceInfo.androidInfo;
    return android.id ?? "unknown_device";
  }

  Future<void> login() async {
    final username = userController.text.trim();
    final password = passController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showAlert("⚠️ Error", "Username and password are required.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final validate = await http.post(
        Uri.parse("$baseUrl/api/auth/validate"),
        body: {
          "username": username,
          "password": password,
          "androidId": androidId ?? "unknown_device",
        },
      );

      final validData = jsonDecode(validate.body);

      if (validData['expired'] == true) {
        _showAlert("⛔ Access Expired", "Your access has expired.\nPlease renew it.", showContact: true);
      } else if (validData['valid'] != true) {
        _showAlert("🚫 Login Failed", "Invalid username or password.", showContact: true);
      } else {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString("username", username);
        prefs.setString("password", password);
        prefs.setString("key", validData['key']);

        // DIUBAH: Navigasi ke splash screen setelah tombol login ditekan
        Navigator.pushNamed(
          context,
          '/splash',
          arguments: {
            'username': username,
            'password': password,
            'role': validData['role'],
            'key': validData['key'],
            'expiredDate': validData['expiredDate'],
            'listBug': validData['listBug'] ?? [],
            'listPayload': validData['listPayload'] ?? [],
            'listDDoS': validData['listDDoS'] ?? [],
            'news': validData['news'] ?? [],
          },
        );
      }
    } catch (_) {
      _showAlert("🌐 Connection Error", "Failed to connect to the server.");
    }

    setState(() => isLoading = false);
  }

  void _showAlert(String title, String msg, {bool showContact = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                title.contains("Error") || title.contains("Failed")
                    ? Icons.error_outline
                    : title.contains("Expired")
                    ? Icons.timer_off
                    : Icons.info_outline,
                color: title.contains("Error") || title.contains("Failed")
                    ? Colors.redAccent
                    : title.contains("Expired")
                    ? Colors.amber
                    : const Color(0xFFE0E0E0), // Glowing gray
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron',
              ),
            ),
          ],
        ),
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontFamily: 'ShareTechMono',
          ),
        ),
        actions: [
          if (showContact)
            TextButton.icon(
              onPressed: () async {
                final uri = Uri.parse("tg://resolve?domain=RaldzzXyz");
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(Uri.parse("https://t.me/iamrii"),
                      mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.message, size: 18),
              label: const Text(
                "Contact Admin",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFE0E0E0).withOpacity(0.2), // Glowing gray
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "CLOSE",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Fungsi untuk membuka bot Telegram
  Future<void> _openTelegramBot() async {
    final uri = Uri.parse("tg://resolve?domain=permen_md");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(Uri.parse("https://t.me/iamrii"),
          mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505), // Dark mode base
      body: Stack(
        children: [
          // Background video with strong dark overlay
          SizedBox(
            height: double.infinity,
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.cover,
              child: _videoController.value.isInitialized
                  ? SizedBox(
                width: _videoController.value.size.width,
                height: _videoController.value.size.height,
                child: VideoPlayer(_videoController),
              )
                  : Container(color: Colors.black),
            ),
          ),
          // Gradient overlay for screenshot-like darkness
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.4),
                radius: 1.2,
                colors: [
                  const Color(0xFFE0E0E0).withOpacity(0.15), // Subtle gray glow center
                  Colors.black.withOpacity(0.85),
                  Colors.black.withOpacity(0.98),
                ],
              ),
            ),
          ),
          // Login form
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo menyerupai screenshot (Circle dengan glowing outline)
                      Hero(
                        tag: 'logo',
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE0E0E0).withOpacity(0.8), // Gray border
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE0E0E0).withOpacity(0.4), // Gray glow
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 120,
                              width: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Text RONOVA
                      const Text(
                        "Aphelion Glitch",
                        style: TextStyle(
                          color: Color(0xFFE0E0E0), // Glowing gray text
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Orbitron',
                          letterSpacing: 4.0,
                          shadows: [
                            Shadow(
                              color: Color(0xFFE0E0E0),
                              blurRadius: 10,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Text Secure Access System
                      const Text(
                        "Halaman Sebelum Anda Login",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontFamily: 'ShareTechMono',
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Login form container menyerupai desain foto
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F0F0F).withOpacity(0.85), // Dark fill
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFE0E0E0).withOpacity(0.2), // Thin outline
                            width: 1.5,
                          ),
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
                            _neonInput("Username", userController, Icons.person),
                            const SizedBox(height: 16),
                            _neonInput("Password", passController, Icons.lock_outline, isPassword: true),
                            const SizedBox(height: 30),

                            // SIGN IN Button menyerupai di foto
                            Container(
                              width: double.infinity,
                              height: 55,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8A8A8A), // Gray gradient
                                    Color(0xFFE0E0E0), // Glowing gray
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE0E0E0).withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: isLoading ? null : login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.black,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        "SIGN IN",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black, // Dark text for contrast
                                          fontFamily: 'Orbitron',
                                          letterSpacing: 2.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Start Bot Button (Tetap dipertahankan tanpa dihapus)
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: const Color(0xFFE0E0E0).withOpacity(0.3), // Glowing gray border
                            width: 1,
                          ),
                        ),
                        child: OutlinedButton.icon(
                          onPressed: _openTelegramBot,
                          label: const Text(
                            "Buy Account",
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFE0E0E0), // Glowing gray text
                              fontFamily: 'Orbitron',
                              letterSpacing: 1.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            side: BorderSide.none,
                          ),
                          icon: const Icon(Icons.shopping_cart, color: Color(0xFFE0E0E0), size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Desain TextField menyerupai di foto (Dark slot shape)
  Widget _neonInput(String hint, TextEditingController controller, IconData icon,
      {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414), // Sangat gelap menyerupai di screenshot
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _isObscure : false,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: const Color(0xFFE0E0E0), // Glowing gray cursor
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: const Color(0xFFE0E0E0).withOpacity(0.8), // Gray icon
          ),
          // Tambahan mata jika form ini adalah password
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isObscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  onPressed: () {
                    setState(() {
                      _isObscure = !_isObscure;
                    });
                  },
                )
              : null,
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontFamily: 'ShareTechMono',
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFFE0E0E0).withOpacity(0.5), width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
      ),
    );
  }
}
