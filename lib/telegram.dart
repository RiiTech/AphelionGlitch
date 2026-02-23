import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TelegramSpamPage extends StatefulWidget {
  final String sessionKey;

  const TelegramSpamPage({super.key, required this.sessionKey});

  @override
  State<TelegramSpamPage> createState() => _TelegramSpamPageState();
}

class _TelegramSpamPageState extends State<TelegramSpamPage>
    with SingleTickerProviderStateMixin {
  // --- Controllers ---
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _authController = TextEditingController(); // Mengganti OTP dan password controller
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _reportTextController = TextEditingController(
    text: "This account is violating Telegram's terms of service through spam and scam activities.",
  );
  final TextEditingController _reportLinkController = TextEditingController();
  final TextEditingController _reportCountController = TextEditingController(text: "50");

  // Controller untuk password manual di session
  final Map<String, TextEditingController> _sessionPasswordControllers = {};

  // --- State Variables ---
  List<TelegramSession> _sessions = [];
  bool _isLoading = false;
  bool _isLoggingIn = false;
  bool _isRefreshing = false;
  bool _isReporting = false;

  // State untuk login
  String _currentLoginPhone = "";
  String _currentLoginId = "";
  String _loginErrorMessage = "";
  String _currentLoginStep = "wait_code"; // wait_code, wait_password, completed
  bool _canResendOtp = true;
  int _resendOtpCooldown = 30;

  // Report State
  int _reportProgress = 0;
  int _reportTotal = 0;
  String _reportStatus = "";
  String _currentReportId = "";
  Timer? _statusCheckTimer;
  Timer? _resendOtpTimer;
  Timer? _loginStatusTimer; // Timer untuk memeriksa status login

  // --- UI Controller ---
  late TabController _tabController;

  // --- Color Scheme ---
  static const Color _primaryGreen = Color(0xFF4ADE80);
  static const Color _darkBg = Color(0xFF0A0A0A);
  static const Color _cardBg = Color(0xFF1A1A1A);
  static const Color _inputBg = Color(0xFF252525);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSessions();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _resendOtpTimer?.cancel();
    _loginStatusTimer?.cancel();
    _tabController.dispose();
    _phoneController.dispose();
    _authController.dispose();
    _targetController.dispose();
    _reportTextController.dispose();
    _reportLinkController.dispose();
    _reportCountController.dispose();

    // Dispose session password controllers
    for (var controller in _sessionPasswordControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // --- API Calls ---
  Future<void> _loadSessions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://tapops.fanzhosting.my.id/api/tools/telegram/sessions?key=${widget.sessionKey}'),
      );

      print('Sessions response: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['valid'] == true) {
          setState(() {
            _sessions = (data['sessions'] as List)
                .map((session) => TelegramSession.fromJson(session))
                .toList();
            _isLoading = false;
          });

          // Initialize password controllers for new sessions
          for (var session in _sessions) {
            _sessionPasswordControllers.putIfAbsent(
                session.phone,
                    () => TextEditingController()
            );
          }
        } else {
          if (mounted) _showSnackBar(data['message'] ?? 'Failed to load sessions', isError: true);
          setState(() => _isLoading = false);
        }
      } else {
        if (mounted) _showSnackBar('Server error: ${response.statusCode}', isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Load sessions error: $e'); // Debug log
      if (mounted) _showSnackBar('Error loading sessions: ${e.toString()}', isError: true);
      setState(() => _isLoading = false);
    }
  }

  // --- PERBAIKAN: Fungsi initiate login dengan endpoint baru ---
  Future<void> _initiateLogin({bool isResend = false}) async {
    if (!isResend && _phoneController.text.trim().isEmpty) {
      setState(() => _loginErrorMessage = "Please enter a phone number.");
      return;
    }
    setState(() {
      _isLoggingIn = true;
      _loginErrorMessage = "";
    });

    try {
      final phone = _currentLoginPhone.isEmpty ? _phoneController.text.trim() : _currentLoginPhone;
      final response = await http.get(
        Uri.parse('https://tapops.fanzhosting.my.id/api/tools/telegram/login?key=${widget.sessionKey}&phone=$phone'),
      );

      print('Init login response: ${response.body}'); // Debug log

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data['valid'] == true) {
          setState(() {
            _currentLoginPhone = phone;
            _currentLoginId = data['loginId'];
            _currentLoginStep = data['step'] ?? 'wait_code';
            _isLoggingIn = false;
          });
          _authController.clear();
          if (isResend) {
            if (mounted) _showSnackBar('OTP code resent');
          } else {
            if (mounted) _showSnackBar('OTP code sent to your phone');
            Navigator.of(context).pop();
            _showAuthDialog();
          }
          // Start checking login status
          _startLoginStatusPolling();
        } else {
          setState(() {
            _loginErrorMessage = data['message'] ?? 'Failed to initiate login';
            _isLoggingIn = false;
          });
        }
      } else {
        setState(() {
          _loginErrorMessage = 'Server error: ${response.statusCode}';
          _isLoggingIn = false;
        });
      }
    } catch (e) {
      print('Init login error: $e'); // Debug log
      setState(() {
        _loginErrorMessage = 'Error: ${e.toString()}';
        _isLoggingIn = false;
      });
    }
  }

  // --- PERBAIKAN: Fungsi submit auth (OTP atau password) dengan endpoint baru ---
  Future<void> _submitAuth() async {
    if (_authController.text.trim().isEmpty) {
      setState(() => _loginErrorMessage = "Please enter the code or password.");
      return;
    }
    setState(() {
      _isLoggingIn = true;
      _loginErrorMessage = "";
    });

    try {
      final response = await http.get(
        Uri.parse('https://tapops.fanzhosting.my.id/api/tools/telegram/auth?key=${widget.sessionKey}&loginId=$_currentLoginId&input=${_authController.text.trim()}'),
      );

      print('Submit auth response: ${response.body}'); // Debug log

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data['valid'] == true) {
          setState(() {
            _currentLoginStep = data['step'] ?? 'completed';
            _isLoggingIn = false;
          });

          if (_currentLoginStep == 'wait_password') {
            _authController.clear();
            if (mounted) _showSnackBar('OTP verified. Please enter your 2FA password.');
            return; // Tetap di dialog yang sama, ganti judul dan hint
          } else if (_currentLoginStep == 'completed') {
            _handleLoginSuccess();
            return;
          }
        } else {
          setState(() {
            _loginErrorMessage = data['message'] ?? 'Failed to verify';
            _isLoggingIn = false;
          });
        }
      } else {
        setState(() {
          _loginErrorMessage = 'Server error: ${response.statusCode}';
          _isLoggingIn = false;
        });
      }
    } catch (e) {
      print('Submit auth error: $e'); // Debug log
      setState(() {
        _loginErrorMessage = 'Error: ${e.toString()}';
        _isLoggingIn = false;
      });
    }
  }

  // --- BARU: Fungsi untuk memeriksa status login ---
  void _startLoginStatusPolling() {
    _loginStatusTimer?.cancel();
    _loginStatusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final response = await http.get(
          Uri.parse('https://tapops.fanzhosting.my.id/api/tools/telegram/status?key=${widget.sessionKey}&loginId=$_currentLoginId'),
        );
        final data = jsonDecode(response.body);
        if (data['valid'] == true && data['completed'] == true) {
          timer.cancel();
          _handleLoginSuccess();
        }
      } catch (e) {
        // Continue polling on error
      }
    });
  }

  // --- BARU: Fungsi untuk verifikasi 2FA manual pada session ---
  Future<void> _verifySessionPassword(String phone) async {
    final passwordController = _sessionPasswordControllers[phone];
    if (passwordController == null || passwordController.text.trim().isEmpty) {
      _showSnackBar('Please enter 2FA password', isError: true);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://tapops.fanzhosting.my.id/api/tools/telegram/verify-session-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'key': widget.sessionKey,
          'phone': phone,
          'password': passwordController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);
      if (data['valid'] == true) {
        _showSnackBar('Session verified successfully');
        passwordController.clear();
        _loadSessions(); // Refresh sessions
      } else {
        _showSnackBar(data['message'] ?? 'Failed to verify session', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    }
  }

  void _handleLoginSuccess() {
    _loginStatusTimer?.cancel();
    if (mounted) _showSnackBar('Login successful! Session saved.');
    _phoneController.clear();
    _authController.clear();
    Navigator.of(context).pop();
    _resetLoginState();
    _loadSessions();
  }

  void _resetLoginState() {
    _loginStatusTimer?.cancel();
    setState(() {
      _currentLoginPhone = "";
      _currentLoginId = "";
      _currentLoginStep = "wait_code";
      _isLoggingIn = false;
      _loginErrorMessage = "";
    });
  }

  void _startResendOtpCooldown() {
    setState(() {
      _canResendOtp = false;
    });
    _resendOtpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendOtpCooldown--;
      });
      if (_resendOtpCooldown <= 0) {
        timer.cancel();
        setState(() {
          _canResendOtp = true;
          _resendOtpCooldown = 30;
        });
      }
    });
  }

  Future<void> _refreshSessions() async {
    setState(() => _isRefreshing = true);
    try {
      final response = await http.get(
        Uri.parse('https://tapops.fanzhosting.my.id/api/tools/telegram/refresh-sessions?key=${widget.sessionKey}'),
      );
      final data = jsonDecode(response.body);
      if (data['valid'] == true) {
        if (mounted) _showSnackBar('Sessions refreshed. ${data['inactiveSessions'].length} inactive sessions removed.');
        _loadSessions();
      } else {
        if (mounted) _showSnackBar(data['message'] ?? 'Failed to refresh sessions', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: ${e.toString()}', isError: true);
    }
    setState(() => _isRefreshing = false);
  }

  Future<void> _deleteSession(String phone) async {
    try {
      final response = await http.get(
        Uri.parse('https://tapops.fanzhosting.my.id/api/tools/telegram/remove-ses?key=${widget.sessionKey}&phone=$phone'),
      );
      final data = jsonDecode(response.body);
      if (data['valid'] == true) {
        if (mounted) _showSnackBar('Session deleted');
        // Remove password controller when session is deleted
        _sessionPasswordControllers.remove(phone)?.dispose();
        _loadSessions();
      } else {
        if (mounted) _showSnackBar(data['message'] ?? 'Failed to delete session', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: ${e.toString()}', isError: true);
    }
  }

  Future<void> _startSpamReport() async {
    if (_targetController.text.trim().isEmpty) {
      _showSnackBar('Please enter a target (username or user ID)', isError: true);
      return;
    }
    if (_sessions.isEmpty) {
      _showSnackBar('No active sessions available', isError: true);
      return;
    }

    final reportCount = int.tryParse(_reportCountController.text) ?? 50;
    if (reportCount <= 0 || reportCount > 1000) {
      _showSnackBar('Report count must be between 1 and 1000', isError: true);
      return;
    }

    setState(() {
      _isReporting = true;
      _reportProgress = 0;
      _reportTotal = _sessions.length * 10;
      _reportStatus = "Initializing...";
    });

    try {
      final response = await http.post(
        Uri.parse('https://tapops.fanzhosting.my.id/api/tools/telegram/spam-report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'key': widget.sessionKey,
          'target': _targetController.text.trim(),
          'count': reportCount,
          'message': _reportTextController.text.trim(),
          'link': _reportLinkController.text.trim(),
        }),
      );
      final data = jsonDecode(response.body);
      if (data['valid'] == true) {
        setState(() => _currentReportId = data['reportId']);
        _startStatusPolling();
        if (mounted) _showSnackBar('Spam report started successfully!');
      } else {
        if (mounted) _showSnackBar(data['message'] ?? 'Failed to start spam report', isError: true);
        setState(() => _isReporting = false);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: ${e.toString()}', isError: true);
      setState(() => _isReporting = false);
    }
  }

  void _startStatusPolling() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final response = await http.get(
          Uri.parse('https://tapops.fanzhosting.my.id/api/tools/telegram/report-status?key=${widget.sessionKey}&reportId=$_currentReportId'),
        );
        final data = jsonDecode(response.body);
        if (data['valid'] == true) {
          final report = data['report'];
          if (mounted) {
            setState(() {
              _reportProgress = report['progress'] ?? 0;
              _reportTotal = report['total'] ?? 0;
              _reportStatus = report['status'] ?? "Processing...";
            });
          }
          if (report['completed'] == true) {
            timer.cancel();
            setState(() => _isReporting = false);
            if (mounted) _showCompletionDialog(report['status']);
          }
        }
      } catch (e) {
        // Continue polling on error
      }
    });
  }

  // --- UI Helpers ---
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade900 : _primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showCompletionDialog(String status) {
    final bool isBanned = status.contains('frozen') || status.contains('banned');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _primaryGreen.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(
              isBanned ? Icons.check_circle : Icons.info,
              color: isBanned ? _primaryGreen : Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text("Report Completed", style: TextStyle(color: _primaryGreen)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(status, style: const TextStyle(color: Colors.white70)),
            if (isBanned) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _primaryGreen.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.celebration, color: _primaryGreen, size: 20),
                    SizedBox(width: 8),
                    Text("Target successfully frozen!", style: TextStyle(color: _primaryGreen, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: _primaryGreen)),
          ),
        ],
      ),
    );
  }

  // --- UI Builders ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        elevation: 0,
        title: const Text('TG Spam Tool', style: TextStyle(color: _primaryGreen, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: _primaryGreen),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _primaryGreen,
          labelColor: _primaryGreen,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'SESSIONS', icon: Icon(Icons.phone_android)),
            Tab(text: 'REPORT', icon: Icon(Icons.report)),
          ],
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _primaryGreen, strokeWidth: 2))
                : const Icon(Icons.refresh, color: _primaryGreen),
            onPressed: _isRefreshing ? null : _refreshSessions,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSessionsTab(),
          _buildReportTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.black,
        onPressed: _isReporting ? null : () => _tabController.animateTo(1),
        child: _isReporting
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.black,
            strokeWidth: 3,
          ),
        )
            : const Icon(Icons.send),
      ),
    );
  }

  Widget _buildSessionsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Active Sessions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showPhoneDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Session'),
                style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen, foregroundColor: Colors.black),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _primaryGreen))
              : _sessions.isEmpty
              ? _buildEmptyState('No Sessions', 'Add a Telegram account to start.', Icons.phone_android)
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _sessions.length,
            itemBuilder: (context, index) {
              final session = _sessions[index];
              return SessionCard(
                session: session,
                onDelete: () => _deleteSession(session.phone),
                passwordController: _sessionPasswordControllers[session.phone] ?? TextEditingController(),
                onVerifyPassword: () => _verifySessionPassword(session.phone),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReportInputCard(
            targetController: _targetController,
            reportTextController: _reportTextController,
            reportLinkController: _reportLinkController,
            reportCountController: _reportCountController,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isReporting ? null : _startSpamReport,
            icon: _isReporting
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
            )
                : const Icon(Icons.play_arrow),
            label: Text(_isReporting ? 'Reporting...' : 'Start Spam Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (_isReporting) ...[
            const SizedBox(height: 20),
            ReportProgressCard(
              progress: _reportProgress,
              total: _reportTotal,
              status: _reportStatus,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white24, size: 80),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.white38), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _showPhoneDialog() {
    _resetLoginState();
    _phoneController.clear();
    _authController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildPhoneDialog(),
    );
  }

  // Ganti fungsi _showAuthDialog yang lama dengan ini
  void _showAuthDialog() {
    _loginErrorMessage = "";
    _authController.clear();
    _startResendOtpCooldown();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // Bungkus dengan StatefulBuilder agar dialog bisa rebuild
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            // Variabel ini akan membaca state terbaru dari widget induk
            final isPasswordStep = _currentLoginStep == 'wait_password';

            return Dialog(
              backgroundColor: _cardBg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: _primaryGreen.withOpacity(0.3))
              ),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header akan berubah berdasarkan isPasswordStep
                    _buildDialogHeader(
                        isPasswordStep ? 'Verify 2FA Password' : 'Verify OTP',
                        isPasswordStep ? Icons.password : Icons.lock
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Teks juga berubah
                          Text(
                              isPasswordStep
                                  ? '2FA Password Required for $_currentLoginPhone'
                                  : 'Code sent to $_currentLoginPhone',
                              style: const TextStyle(color: Colors.white70)
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _authController,
                            // Tipe input dan obfuscate berubah
                            keyboardType: isPasswordStep ? TextInputType.text : TextInputType.number,
                            obscureText: isPasswordStep,
                            style: const TextStyle(color: _primaryGreen),
                            decoration: _inputDecoration(
                                isPasswordStep ? 'Password' : 'OTP Code',
                                isPasswordStep ? 'Enter your 2FA password' : 'Enter 5-digit code',
                                isPasswordStep ? Icons.password : Icons.lock
                            ),
                            onSubmitted: (_) => _submitAuth(),
                          ),
                        ],
                      ),
                    ),
                    if (_loginErrorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0).copyWith(bottom: 10),
                        child: Text(_loginErrorMessage, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                      ),
                    // Tombol dan aksi juga berubah
                    _buildDialogActions(
                        _submitAuth,
                        isPasswordStep ? 'LOGIN' : 'VERIFY',
                        showResendButton: !isPasswordStep
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPhoneDialog() {
    return Dialog(
      backgroundColor: _cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _primaryGreen.withOpacity(0.3))),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogHeader('Add New Session', Icons.login),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: _primaryGreen),
                decoration: _inputDecoration('Phone Number', 'e.g., +628123456789', Icons.phone),
              ),
            ),
            if (_loginErrorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0).copyWith(bottom: 10),
                child: Text(_loginErrorMessage, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
              ),
            _buildDialogActions(_initiateLogin, 'SEND OTP'),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(String title, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryGreen.withOpacity(0.1),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _primaryGreen),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: _primaryGreen, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDialogActions(VoidCallback onPressed, String buttonText, {bool showResendButton = false}) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (showResendButton) ...[
            IconButton(
              icon: _isLoggingIn || !_canResendOtp
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
              )
                  : const Icon(Icons.refresh, color: Colors.white70),
              onPressed: _isLoggingIn || !_canResendOtp ? null : () {
                _initiateLogin(isResend: true);
              },
              tooltip: _canResendOtp ? 'Resend OTP' : 'Wait $_resendOtpCooldown seconds',
            ),
            const Spacer(),
          ],
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetLoginState();
            },
            child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isLoggingIn ? null : onPressed,
            style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen, foregroundColor: Colors.black),
            child: _isLoggingIn
                ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(buttonText == 'SEND OTP' ? 'SENDING...' : buttonText == 'VERIFY' ? 'VERIFYING...' : 'LOGGING IN...'),
              ],
            )
                : Text(buttonText),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      labelStyle: const TextStyle(color: _primaryGreen),
      prefixIcon: Icon(icon, color: _primaryGreen),
      filled: true,
      fillColor: _inputBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryGreen)),
    );
  }
}

// --- Custom Widget Components ---

class SessionCard extends StatefulWidget {
  final TelegramSession session;
  final VoidCallback onDelete;
  final TextEditingController passwordController;
  final VoidCallback onVerifyPassword;

  const SessionCard({
    super.key,
    required this.session,
    required this.onDelete,
    required this.passwordController,
    required this.onVerifyPassword,
  });

  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard> {
  bool _showPasswordInput = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.session.isActive ? const Color(0xFF4ADE80).withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.phone_android,
              color: widget.session.isActive ? const Color(0xFF4ADE80) : Colors.red,
            ),
            title: Text(
              widget.session.phone,
              style: TextStyle(
                color: widget.session.isActive ? const Color(0xFF4ADE80) : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text('Last active: ${_formatDate(widget.session.lastModified)}', style: const TextStyle(color: Colors.white54)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tombol untuk toggle password input
                IconButton(
                  icon: Icon(
                    _showPasswordInput ? Icons.keyboard_arrow_up : Icons.password,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    setState(() {
                      _showPasswordInput = !_showPasswordInput;
                    });
                  },
                  tooltip: '2FA Password',
                ),
                // Tombol delete
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: widget.onDelete,
                  tooltip: 'Delete Session',
                ),
              ],
            ),
          ),
          // Password input yang muncul saat di-toggle
          if (_showPasswordInput)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Color(0xFF4ADE80)),
                      decoration: InputDecoration(
                        labelText: '2FA Password',
                        hintText: 'Enter 2FA password if needed',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        labelStyle: const TextStyle(color: Color(0xFF4ADE80)),
                        prefixIcon: const Icon(Icons.lock, color: Color(0xFF4ADE80)),
                        filled: true,
                        fillColor: const Color(0xFF252525),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4ADE80))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: widget.onVerifyPassword,
                    icon: const Icon(Icons.verified_user, size: 18),
                    label: const Text('VERIFY'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ADE80),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class ReportInputCard extends StatelessWidget {
  final TextEditingController targetController;
  final TextEditingController reportTextController;
  final TextEditingController reportLinkController;
  final TextEditingController reportCountController;

  const ReportInputCard({
    super.key,
    required this.targetController,
    required this.reportTextController,
    required this.reportLinkController,
    required this.reportCountController,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Report Configuration', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: targetController,
              style: const TextStyle(color: Color(0xFF4ADE80)),
              decoration: _inputDecoration('Target', '@username or user ID', Icons.person),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reportTextController,
              maxLines: 3,
              style: const TextStyle(color: Color(0xFF4ADE80)),
              decoration: _inputDecoration('Report Message', 'Optional custom message', Icons.message),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reportLinkController,
              style: const TextStyle(color: Color(0xFF4ADE80)),
              decoration: _inputDecoration('Report Link', 'Optional evidence link', Icons.link),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reportCountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF4ADE80)),
              decoration: _inputDecoration('Report Count', '1-1000', Icons.numbers),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      labelStyle: const TextStyle(color: Color(0xFF4ADE80)),
      prefixIcon: Icon(icon, color: const Color(0xFF4ADE80)),
      filled: true,
      fillColor: const Color(0xFF252525),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4ADE80))),
    );
  }
}

class ReportProgressCard extends StatelessWidget {
  final int progress;
  final int total;
  final String status;

  const ReportProgressCard({super.key, required this.progress, required this.total, required this.status});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Report Progress', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: total > 0 ? progress / total : 0.0,
              backgroundColor: Colors.grey[700],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Progress: $progress / $total', style: const TextStyle(color: Colors.white70)),
                Flexible(child: Text(status, style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis,)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Data Model ---
class TelegramSession {
  final String phone;
  final DateTime lastModified;
  final bool isActive;

  TelegramSession({required this.phone, required this.lastModified, required this.isActive});

  factory TelegramSession.fromJson(Map<String, dynamic> json) {
    return TelegramSession(
      phone: json['phone'] ?? '',
      lastModified: DateTime.parse(json['lastModified']),
      isActive: json['isActive'] ?? true,
    );
  }
}