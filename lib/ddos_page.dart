// tools_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'chat_ai_page.dart';
import 'nik_check_page.dart';
import 'phone_lookup.dart'; // Tambahkan import untuk PhoneLookupPage
import 'subdomain_finder_page.dart';
import 'anime.dart';

class ToolsPage extends StatefulWidget {
  final String sessionKey;
  final String userRole;

  const ToolsPage({
    super.key,
    required this.sessionKey,
    required this.userRole,
  });

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _listController;
  late Animation<double> _headerAnimation;
  late List<Animation<double>> _itemAnimations;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _listController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _headerAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutBack),
    );

    _itemAnimations = List.generate(
      5, // Perbarui menjadi 5 karena kita menambahkan tool baru
          (index) => Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _listController,
          curve: Interval(
            index * 0.1,
            0.5 + (index * 0.1),
            curve: Curves.easeOutBack,
          ),
        ),
      ),
    );

    _headerController.forward();
    _listController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _headerController,
              builder: (context, child) {
                return Opacity(
                  opacity: _headerAnimation.value * 0.05,
                  child: CustomPaint(
                    painter: GridPatternPainter(),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAnimatedHeader(),
                const SizedBox(height: 24),
                Expanded(child: _buildToolsList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedHeader() {
    return AnimatedBuilder(
      animation: _headerAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _headerAnimation.value) * 30),
          child: Opacity(
            opacity: _headerAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black,
                border: Border.all(
                  color: const Color(0xFF00FF00).withOpacity(0.2), // Hijau muda cerah dengan opacity
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF00).withOpacity(0.2), // Hijau muda cerah dengan opacity
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.apps, color: Color(0xFF00FF00), size: 24), // Hijau muda cerah
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Digital Tools",
                        style: TextStyle(
                          color: Color(0xFF00FF00), // Hijau muda cerah
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Select a tool to begin",
                    style: TextStyle(
                      color: const Color(0xFF00FF00).withOpacity(0.7), // Hijau muda cerah dengan opacity
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolsList() {
    final tools = [
      {'icon': Icons.chat, 'label': 'Chat AI', 'description': 'AI-powered conversation assistant'},
      {'icon': Icons.badge, 'label': 'NIK Check', 'description': 'Validate Indonesian identity numbers'},
      {'icon': Icons.phone, 'label': 'Phone Lookup', 'description': 'Find information about phone numbers'}, // Tambahkan tool baru
      {'icon': Icons.language, 'label': 'Subdomain Finder', 'description': 'Discover subdomains of any domain'},
      {'icon': Icons.movie_filter_outlined, 'label': 'Anime', 'description': 'Tempat Nya Para Wibu Marathon Anime'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final tool = tools[index];
        return _buildAnimatedToolItem(
          icon: tool['icon'] as IconData,
          label: tool['label'] as String,
          description: tool['description'] as String,
          animation: _itemAnimations[index],
          onTap: () => _navigateToTool(tool['label'] as String),
        );
      },
    );
  }

  void _navigateToTool(String toolName) {
    Widget page;
    switch (toolName) {
      case 'Chat AI':
        page = ChatAIPage(sessionKey: widget.sessionKey);
        break;
      case 'NIK Check':
        page = NIKCheckPage(sessionKey: widget.sessionKey);
        break;
      case 'Phone Lookup': // Tambahkan case untuk Phone Lookup
        page = PhoneLookupPage(sessionKey: widget.sessionKey);
        break;
      case 'Anime': // Tambahkan case untuk Phone Lookup
        page = HomeAnimePage();
        break;
      case 'Subdomain Finder':
        page = SubdomainFinderPage(sessionKey: widget.sessionKey);
        break;
      default:
        return;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Widget _buildAnimatedToolItem({
    required IconData icon,
    required String label,
    required String description,
    required Animation<double> animation,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset((1 - animation.value) * 50, 0),
          child: Opacity(
            opacity: animation.value,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _InteractiveToolItem(icon: icon, label: label, description: description, onTap: onTap),
            ),
          ),
        );
      },
    );
  }
}

class _InteractiveToolItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _InteractiveToolItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  State<_InteractiveToolItem> createState() => _InteractiveToolItemState();
}

class _InteractiveToolItemState extends State<_InteractiveToolItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isPressed
                      ? const Color(0xFF00FF00).withOpacity(0.5) // Hijau muda cerah dengan opacity saat ditekan
                      : const Color(0xFF00FF00).withOpacity(0.2), // Hijau muda cerah dengan opacity
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF00).withOpacity(0.2), // Hijau muda cerah dengan opacity
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, color: const Color(0xFF00FF00), size: 24), // Hijau muda cerah
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                              color: Color(0xFF00FF00), // Hijau muda cerah
                              fontSize: 16,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.description,
                          style: TextStyle(
                              color: const Color(0xFF00FF00).withOpacity(0.7), // Hijau muda cerah dengan opacity
                              fontSize: 12
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: const Color(0xFF00FF00).withOpacity(0.5), // Hijau muda cerah dengan opacity
                    size: 16,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00FF00) // Hijau muda cerah
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    const gridSize = 30.0;
    for (double x = 0; x < size.width; x += gridSize) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += gridSize) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}