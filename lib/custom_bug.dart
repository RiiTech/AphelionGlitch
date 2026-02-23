import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'dart:ui';

class CustomAttackPage extends StatefulWidget {
  final String username;
  final String password;
  final String sessionKey;
  final List<Map<String, dynamic>> listPayload;
  final String role;
  final String expiredDate;

  const CustomAttackPage({
    super.key,
    required this.username,
    required this.password,
    required this.sessionKey,
    required this.listPayload,
    required this.role,
    required this.expiredDate,
  });

  @override
  State<CustomAttackPage> createState() => _CustomAttackPageState();
}

class _CustomAttackPageState extends State<CustomAttackPage> with TickerProviderStateMixin {
  final targetController = TextEditingController();
  final qtyController = TextEditingController(text: "5");
  final delayController = TextEditingController(text: "100");
  static const String baseUrl = "https://tapops.fanzhosting.my.id";

  // Animation controllers
  late AnimationController _buttonController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _glowAnimation;

  // Video controllers
  late VideoPlayerController _videoController;
  bool _videoInitialized = false;
  bool _videoError = false;

  // State variables
  List<String> selectedBugs = [];
  String _senderType = "global"; // "global" or "private"
  bool _isSending = false;
  Map<String, String> _senderTypeLimits = {};
  int _activeStep = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeVideoController();
    _setSenderTypeLimits();
    _setDefaultBugs();
    _startAnimations();
  }

  void _initializeAnimations() {
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  void _startAnimations() {
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
  }

  void _setSenderTypeLimits() {
    // Set limits based on sender type
    _senderTypeLimits = {
      "global": "Max Qty: 10, Delay: 500ms (Fixed)",
      "private": "Max Qty: 200, Min Delay: 10ms",
    };
  }

  void _setDefaultBugs() {
    // Select first bug by default if list is not empty
    if (widget.listPayload.isNotEmpty) {
      selectedBugs.add(widget.listPayload[0]['bug_id']);
    }
  }

  void _initializeVideoController() {
    try {
      _videoController = VideoPlayerController.asset('assets/videos/banner.mp4')
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _videoInitialized = true;
            });
            _videoController.setLooping(true);
            _videoController.play();
            _videoController.setVolume(0);
          }
        }).catchError((error) {
          print('Video initialization error: $error');
          if (mounted) {
            setState(() {
              _videoError = true;
            });
          }
        });
    } catch (e) {
      print('Video controller creation error: $e');
      if (mounted) {
        setState(() {
          _videoError = true;
        });
      }
    }
  }

  String? formatPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.startsWith('0') || cleaned.length < 8) return null;
    return cleaned;
  }

  void _toggleBugSelection(String bugId) {
    setState(() {
      if (selectedBugs.contains(bugId)) {
        selectedBugs.remove(bugId);
      } else {
        selectedBugs.add(bugId);
      }
    });
  }

  Future<void> _sendCustomBug() async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
      _activeStep = 1;
    });

    _buttonController.forward().then((_) {
      _buttonController.reverse();
    });

    final rawInput = targetController.text.trim();
    final target = formatPhoneNumber(rawInput);
    final key = widget.sessionKey;
    final qty = int.tryParse(qtyController.text) ?? 1;
    final delay = int.tryParse(delayController.text) ?? 100;

    if (target == null || key.isEmpty) {
      _showAlert("❌ Invalid Number", "Gunakan nomor internasional (misal: +62, 1, 44), bukan 08xxx.");
      setState(() {
        _isSending = false;
        _activeStep = 0;
      });
      return;
    }

    if (selectedBugs.isEmpty) {
      _showAlert("❌ No Payload Selected", "Please select at least one payload to send.");
      setState(() {
        _isSending = false;
        _activeStep = 0;
      });
      return;
    }

    try {
      // Create comma-separated list of bugs
      final bugsParam = selectedBugs.join(',');

      final res = await http.get(Uri.parse("$baseUrl/api/whatsapp/customBug?key=$key&target=$target&bug=$bugsParam&qty=$qty&delay=$delay&senderType=$_senderType"));
      final data = jsonDecode(res.body);

      if (data["valid"] == false) {
        _showAlert("❌ Failed", data["message"] ?? "Failed to send custom bug.");
      } else {
        setState(() {
          _activeStep = 2;
        });
        _showSuccessPopup(target, data["details"]);
      }
    } catch (_) {
      _showAlert("❌ Error", "Terjadi kesalahan. Coba lagi.");
    } finally {
      setState(() {
        _isSending = false;
        if (_activeStep != 2) _activeStep = 0;
      });
    }
  }

  void _showSuccessPopup(String target, Map<String, dynamic> details) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomSuccessDialog(
        target: target,
        details: details,
        onDismiss: () {
          Navigator.of(context).pop();
          setState(() {
            _activeStep = 0;
          });
        },
      ),
    );
  }

  void _showAlert(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: const Color(0xFF4ADE80).withOpacity(0.3), width: 1),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron')),
        content: Text(msg, style: const TextStyle(color: Colors.white70, fontFamily: 'ShareTechMono')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Color(0xFF4ADE80))),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only allow access to VIP and Owner roles
    if (!["vip", "owner"].contains(widget.role.toLowerCase())) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1 + 0.1 * _glowAnimation.value),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3 + 0.2 * _glowAnimation.value),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.2 * _glowAnimation.value),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      FontAwesomeIcons.lock,
                      color: Colors.red,
                      size: 60,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                "ACCESS DENIED",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "This feature is only available for VIP and Owner users",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated background
          _buildAnimatedBackground(),

          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.85),
                  Colors.black,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // User info header with glassmorphism
                        _buildUserInfoHeader(),

                        const SizedBox(height: 20),

                        // Progress indicator
                        _buildProgressIndicator(),

                        const SizedBox(height: 20),

                        // Main content cards
                        _buildTargetInputCard(),

                        const SizedBox(height: 14),

                        _buildPayloadSelectionCard(),

                        const SizedBox(height: 14),

                        _buildSenderTypeCard(),

                        const SizedBox(height: 14),

                        _buildQuantityDelayCard(),

                        const SizedBox(height: 20),

                        _buildStatusIndicators(),

                        const SizedBox(height: 20),

                        _buildSendButton(),

                        const SizedBox(height: 14),

                        _buildFooterInfo(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return _videoInitialized && !_videoError
        ? SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoController.value.size.width,
          height: _videoController.value.size.height,
          child: VideoPlayer(_videoController),
        ),
      ),
    )
        : Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0A0A0A),
            Color(0xFF121212),
            Color(0xFF1A1A1A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Animated particles with green theme
          ...List.generate(15, (index) {
            final size = (index % 5 + 1) * 2.0;
            final opacity = (index % 5 + 1) / 10.0;
            return AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Positioned(
                  left: (index * 73.0) % MediaQuery.of(context).size.width,
                  top: (index * 137.0) % MediaQuery.of(context).size.height,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ADE80).withOpacity(opacity * _glowAnimation.value),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              _buildStepIndicator(0, "Input", FontAwesomeIcons.edit),
              _buildProgressLine(),
              _buildStepIndicator(1, "Process", FontAwesomeIcons.cogs),
              _buildProgressLine(),
              _buildStepIndicator(2, "Complete", FontAwesomeIcons.checkCircle),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    final isActive = _activeStep >= step;
    final isCurrent = _activeStep == step;

    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? (isCurrent
                  ? const Color(0xFF4ADE80).withOpacity(0.2)
                  : const Color(0xFF4ADE80).withOpacity(0.2))
                  : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? (isCurrent
                    ? const Color(0xFF4ADE80).withOpacity(0.5)
                    : const Color(0xFF4ADE80).withOpacity(0.5))
                    : Colors.white.withOpacity(0.2),
                width: 2,
              ),
              boxShadow: isCurrent
                  ? [
                BoxShadow(
                  color: const Color(0xFF4ADE80).withOpacity(0.2 * _glowAnimation.value),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ]
                  : null,
            ),
            child: Icon(
              icon,
              color: isActive
                  ? (isCurrent ? Colors.white : const Color(0xFF4ADE80))
                  : Colors.white.withOpacity(0.4),
              size: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive
                  ? (isCurrent ? Colors.white : const Color(0xFF4ADE80))
                  : Colors.white.withOpacity(0.4),
              fontSize: 11,
              fontFamily: 'Orbitron',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressLine() {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _activeStep > 0
                ? [const Color(0xFF4ADE80), const Color(0xFF4ADE80).withOpacity(0.3)]
                : [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.1)],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              // User avatar with glow effect
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF4ADE80).withOpacity(0.3 * _glowAnimation.value),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4ADE80).withOpacity(0.1 * _glowAnimation.value),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  widget.role.toLowerCase() == "vip"
                      ? FontAwesomeIcons.crown
                      : FontAwesomeIcons.userShield,
                  color: const Color(0xFF4ADE80),
                  size: 20,
                ),
              );
            },
          ),

          const SizedBox(width: 14),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Orbitron',
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF4ADE80).withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    widget.role.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF4ADE80),
                      fontSize: 11,
                      fontFamily: 'ShareTechMono',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expiry date
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  FontAwesomeIcons.calendarAlt,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(height: 2),
                Text(
                  "EXP",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 9,
                    fontFamily: 'ShareTechMono',
                  ),
                ),
                Text(
                  widget.expiredDate,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'ShareTechMono',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildTargetInputCard() {
  return ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.04),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.phone,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Target Number",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: targetController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: "e.g. +62xxxxxxxxx",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF4ADE80), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.globe,
                    color: Colors.white70,
                    size: 16,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Use international format without 0 or +",
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
                fontFamily: 'ShareTechMono',
              ),
            ),
          ],
        ),          // menutup Column
      ),            // menutup Container
    ),              // menutup BackdropFilter
  );                // menutup ClipRRect
}

  Widget _buildPayloadSelectionCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.04),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      FontAwesomeIcons.bug,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Select Payloads",
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ADE80).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF4ADE80).withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      "${selectedBugs.length} ON",
                      style: const TextStyle(
                        color: Color(0xFF4ADE80),
                        fontSize: 11,
                        fontFamily: 'ShareTechMono',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Switch list per payload
              ...widget.listPayload.map((bug) {
                final bugId = bug['bug_id'];
                final bugName = bug['bug_name'];
                final description = bug['description'];
                final isSelected = selectedBugs.contains(bugId);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4ADE80).withOpacity(0.12)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF4ADE80).withOpacity(0.5)
                            : Colors.white.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Payload icon
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF4ADE80).withOpacity(0.2)
                                : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            FontAwesomeIcons.virus,
                            color: isSelected ? const Color(0xFF4ADE80) : Colors.white54,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Name & description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bugName,
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFF4ADE80) : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'ShareTechMono',
                                ),
                              ),
                              if (description != null && description.toString().isNotEmpty)
                                Text(
                                  description.toString(),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.45),
                                    fontSize: 10,
                                    fontFamily: 'ShareTechMono',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        // Switch
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: isSelected,
                            onChanged: (_) => _toggleBugSelection(bugId),
                            activeColor: const Color(0xFF4ADE80),
                            activeTrackColor: const Color(0xFF4ADE80).withOpacity(0.3),
                            inactiveThumbColor: Colors.white38,
                            inactiveTrackColor: Colors.white.withOpacity(0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    FontAwesomeIcons.infoCircle,
                    color: Colors.white.withOpacity(0.4),
                    size: 11,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Toggle payloads for a combined attack",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                        fontFamily: 'ShareTechMono',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSenderTypeCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.04),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  FontAwesomeIcons.server,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Sender Type",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _senderType = "global"),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _senderType == "global"
                          ? const Color(0xFF4ADE80).withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _senderType == "global"
                            ? const Color(0xFF4ADE80)
                            : Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _glowController,
                          builder: (context, child) {
                            return Icon(
                              FontAwesomeIcons.globe,
                              color: _senderType == "global"
                                  ? const Color(0xFF4ADE80)
                                  : Colors.white70,
                              size: 20,
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Global",
                          style: TextStyle(
                            color: _senderType == "global" ? const Color(0xFF4ADE80) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _senderTypeLimits["global"]!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _senderType = "private"),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _senderType == "private"
                          ? const Color(0xFF4ADE80).withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _senderType == "private"
                            ? const Color(0xFF4ADE80)
                            : Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _glowController,
                          builder: (context, child) {
                            return Icon(
                              FontAwesomeIcons.user,
                              color: _senderType == "private"
                                  ? const Color(0xFF4ADE80)
                                  : Colors.white70,
                              size: 20,
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Private",
                          style: TextStyle(
                            color: _senderType == "private" ? const Color(0xFF4ADE80) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _senderTypeLimits["private"]!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityDelayCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.04),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  FontAwesomeIcons.slidersH,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Quantity & Delay",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    labelText: "Quantity",
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    hintText: "1-200",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4ADE80)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: delayController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  enabled: _senderType == "private", // Disable for global sender
                  decoration: InputDecoration(
                    labelText: "Delay (ms)",
                    labelStyle: TextStyle(
                      color: _senderType == "private"
                          ? Colors.white.withOpacity(0.7)
                          : Colors.white.withOpacity(0.3),
                    ),
                    hintText: "10-1000",
                    hintStyle: TextStyle(
                      color: _senderType == "private"
                          ? Colors.white.withOpacity(0.5)
                          : Colors.white.withOpacity(0.3),
                    ),
                    filled: true,
                    fillColor: _senderType == "private"
                        ? Colors.white.withOpacity(0.1)
                        : Colors.white.withOpacity(0.05),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: _senderType == "private"
                            ? Colors.white.withOpacity(0.3)
                            : Colors.white.withOpacity(0.1),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: _senderType == "private"
                            ? const Color(0xFF4ADE80)
                            : Colors.white.withOpacity(0.2),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
          if (_senderType == "global")
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(
                    FontAwesomeIcons.infoCircle,
                    color: Colors.white.withOpacity(0.5),
                    size: 12,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Note: Delay is fixed at 500ms for Global sender",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                        fontFamily: 'ShareTechMono',
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
          ),
        ),
      ),
    );
  }

Widget _buildStatusIndicators() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.04),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "System Status",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statusIndicator(
                    icon: FontAwesomeIcons.server,
                    label: "Server",
                    isOnline: true,
                  ),
                  _statusIndicator(
                    icon: FontAwesomeIcons.shieldAlt,
                    label: "Security",
                    isOnline: true,
                  ),
                  _statusIndicator(
                    icon: FontAwesomeIcons.database,
                    label: "Database",
                    isOnline: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusIndicator({required IconData icon, required String label, required bool isOnline}) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isOnline
                    ? Colors.white.withOpacity(0.1 + 0.1 * _glowAnimation.value)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOnline
                      ? Colors.white.withOpacity(0.3 + 0.2 * _glowAnimation.value)
                      : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: isOnline
                    ? [
                  BoxShadow(
                    color: const Color(0xFF4ADE80).withOpacity(0.1 * _glowAnimation.value),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
                    : null,
              ),
              child: Icon(
                icon,
                color: isOnline ? Colors.white : Colors.white70,
                size: 20,
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontFamily: 'ShareTechMono',
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 50,
          height: 3,
          decoration: BoxDecoration(
            color: isOnline ? const Color(0xFF4ADE80) : Colors.red.withOpacity(0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildSendButton() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF4ADE80).withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4ADE80).withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ElevatedButton.icon(
              icon: _isSending
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Icon(FontAwesomeIcons.paperPlane, color: Colors.white, size: 18),
              label: Text(
                _isSending ? "SENDING..." : "SEND CUSTOM PAYLOAD",
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isSending ? null : _sendCustomBug,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooterInfo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Icon(
                FontAwesomeIcons.exclamationTriangle,
                color: Colors.white.withOpacity(0.5),
                size: 14,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Custom attack with multiple payloads. Use responsibly.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                    fontFamily: 'ShareTechMono',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _buttonController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _glowController.dispose();
    _videoController.dispose();
    targetController.dispose();
    qtyController.dispose();
    delayController.dispose();
    super.dispose();
  }
}

// Custom success dialog for custom attack
class CustomSuccessDialog extends StatefulWidget {
  final String target;
  final Map<String, dynamic> details;
  final VoidCallback onDismiss;

  const CustomSuccessDialog({
    super.key,
    required this.target,
    required this.details,
    required this.onDismiss,
  });

  @override
  State<CustomSuccessDialog> createState() => _CustomSuccessDialogState();
}

class _CustomSuccessDialogState extends State<CustomSuccessDialog> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Show details after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _showDetails = true;
        });
        _fadeController.forward();
        _scaleController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width * 0.9;
    final dialogHeight = screenSize.height * 0.45;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogHeight,
        ),
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF4ADE80).withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4ADE80).withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Success icon and title
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4ADE80).withOpacity(0.1 + 0.1 * _glowAnimation.value),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: const Color(0xFF4ADE80).withOpacity(0.3 + 0.2 * _glowAnimation.value),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4ADE80).withOpacity(0.2 * _glowAnimation.value),
                                blurRadius: 15,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(
                            FontAwesomeIcons.checkDouble,
                            color: Color(0xFF4ADE80),
                            size: 40,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "CUSTOM ATTACK SENT!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Orbitron',
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // Attack details
              if (_showDetails)
                Positioned(
                  top: 100,
                  left: 20,
                  right: 20,
                  bottom: 80,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Attack Details:",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Orbitron',
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow("Target", widget.target),
                            _buildDetailRow("Sender Type", widget.details["senderType"]),
                            _buildDetailRow("Payloads", widget.details["bugs"].toString()),
                            _buildDetailRow("Quantity", widget.details["qty"].toString()),
                            _buildDetailRow("Delay", "${widget.details["delay"]}ms"),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Close button
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: ElevatedButton(
                  onPressed: widget.onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ADE80).withOpacity(0.1),
                    foregroundColor: const Color(0xFF4ADE80),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: BorderSide(
                        color: const Color(0xFF4ADE80).withOpacity(0.3),
                      ),
                    ),
                  ),
                  child: const Text(
                    "DONE",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Orbitron',
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontFamily: 'ShareTechMono',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF4ADE80),
                fontSize: 12,
                fontFamily: 'ShareTechMono',
              ),
            ),
          ),
        ],
      ),
    );
  }
}