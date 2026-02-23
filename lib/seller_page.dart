import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SellerPage extends StatefulWidget {
  final String keyToken;

  const SellerPage({super.key, required this.keyToken});

  @override
  State<SellerPage> createState() => _SellerPageState();
}

class _SellerPageState extends State<SellerPage> {
  final _newUser = TextEditingController();
  final _newPass = TextEditingController();
  final _days = TextEditingController();
  final _editUser = TextEditingController();
  final _editDays = TextEditingController();
  bool loading = false;

  // --- API Logic (Tidak berubah) ---
  Future<void> _create() async {
    final u = _newUser.text.trim(), p = _newPass.text.trim(), d = _days.text.trim();
    if (u.isEmpty || p.isEmpty || d.isEmpty) return _showNotification("Semua field wajib diisi", isError: true);
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse(
          "https://tapops.fanzhosting.my.id/api/user/createAccount?key=${widget.keyToken}&newUser=$u&pass=$p&day=$d"));
      final data = jsonDecode(res.body);
      if (data['created'] == true) {
        _showNotification("Akun berhasil dibuat!");
        _newUser.clear(); _newPass.clear(); _days.clear();
        Navigator.pop(context); // Tutup dialog setelah sukses
      } else {
        _showNotification(data['message'] ?? 'Gagal membuat akun.', isError: true);
      }
    } catch (e) {
      _showNotification("Terjadi kesalahan: ${e.toString()}", isError: true);
    }
    setState(() => loading = false);
  }

  Future<void> _edit() async {
    final u = _editUser.text.trim(), d = _editDays.text.trim();
    if (u.isEmpty || d.isEmpty) return _showNotification("Username dan durasi wajib diisi", isError: true);
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse(
          "https://tapops.fanzhosting.my.id/api/user/editUser?key=${widget.keyToken}&username=$u&addDays=$d"));
      final data = jsonDecode(res.body);
      if (data['edited'] == true) {
        _showNotification("Durasi berhasil diperbarui.");
        _editUser.clear(); _editDays.clear();
        Navigator.pop(context); // Tutup dialog setelah sukses
      } else {
        _showNotification(data['message'] ?? 'Gagal mengubah durasi.', isError: true);
      }
    } catch (e) {
      _showNotification("Terjadi kesalahan: ${e.toString()}", isError: true);
    }
    setState(() => loading = false);
  }

  void _showNotification(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade900 : Colors.grey.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // --- UI Widgets ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF4ADE80)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _mainActionButton("Buat Akun Baru", Icons.person_add, _showCreateAccountDialog),
              const SizedBox(height: 20),
              _mainActionButton("Ubah Durasi Akun", Icons.edit_calendar, _showEditDurationDialog),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mainActionButton(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4ADE80).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF4ADE80), size: 28),
            const SizedBox(width: 16),
            Text(title, style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // --- Dialogs ---

  void _showCreateAccountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Tidak bisa ditutup dengan klik di luar
      builder: (_) => _buildDialog(
        title: "Buat Akun Baru",
        fields: [
          _inputField("Username", _newUser),
          _inputField("Password", _newPass),
          _inputField("Durasi (hari)", _days, type: TextInputType.number),
        ],
        onConfirm: _create,
      ),
    );
  }

  void _showEditDurationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildDialog(
        title: "Ubah Durasi Akun",
        fields: [
          _inputField("Username", _editUser),
          _inputField("Tambah Durasi (hari)", _editDays, type: TextInputType.number),
        ],
        onConfirm: _edit,
      ),
    );
  }

  Widget _buildDialog({required String title, required List<Widget> fields, required VoidCallback onConfirm}) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFF4ADE80).withOpacity(0.3))
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ...fields,
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(context),
                  child: const Text("BATAL", style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: loading ? null : onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ADE80),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: SizedBox(
                    width: 80,
                    height: 20,
                    child: Center(
                      child: loading
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                          : const Text("KONFIRMASI", style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController c, {TextInputType type = TextInputType.text}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: c,
            keyboardType: type,
            style: const TextStyle(color: Color(0xFF4ADE80)),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: const Color(0xFF4ADE80).withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF4ADE80), width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}