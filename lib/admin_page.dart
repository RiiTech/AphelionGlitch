import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminPage extends StatefulWidget {
  final String sessionKey;

  const AdminPage({super.key, required this.sessionKey});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  // --- State Variables ---
  late String sessionKey;
  List<dynamic> fullUserList = [];
  List<dynamic> filteredList = [];
  final List<String> roleOptions = ['vip', 'reseller', 'reseller1', 'owner', 'member'];
  String selectedRole = 'member';
  int currentPage = 1;
  int itemsPerPage = 50; // Ditingkatkan untuk mengurangi halaman
  bool isLoading = false;

  // --- Controllers ---
  final deleteController = TextEditingController();
  final createUsernameController = TextEditingController();
  final createPasswordController = TextEditingController();
  final createDayController = TextEditingController();
  String newUserRole = 'member';

  @override
  void initState() {
    super.initState();
    sessionKey = widget.sessionKey;
    _fetchUsers();
  }

  // --- API Logic ---
  Future<void> _fetchUsers() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse('https://tapops.fanzhosting.my.id/api/user/listUsers?key=$sessionKey'));
      final data = jsonDecode(res.body);
      if (data['valid'] == true && data['authorized'] == true) {
        fullUserList = data['users'] ?? [];
        _filterAndPaginate();
      } else {
        _showSnackBar(data['message'] ?? 'Tidak diizinkan melihat daftar user.', isError: true);
      }
    } catch (_) {
      _showSnackBar("Gagal memuat user list.", isError: true);
    }
    setState(() => isLoading = false);
  }

  void _filterAndPaginate() {
    setState(() {
      currentPage = 1;
      filteredList = fullUserList.where((u) => u['role'] == selectedRole).toList();
    });
  }

  List<dynamic> _getCurrentPageData() {
    if (filteredList.isEmpty) return [];
    final start = (currentPage - 1) * itemsPerPage;
    final end = (start + itemsPerPage);
    return filteredList.sublist(start, end > filteredList.length ? filteredList.length : end);
  }

  int get totalPages => (filteredList.length / itemsPerPage).ceil();

  Future<void> _deleteUser(String username) async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse('https://tapops.fanzhosting.my.id/api/user/deleteUser?key=$sessionKey&username=$username'));
      final data = jsonDecode(res.body);
      if (data['deleted'] == true) {
        _showSnackBar("User '${data['user']['username']}' telah dihapus.");
        _fetchUsers();
      } else {
        _showSnackBar(data['message'] ?? 'Gagal menghapus user.', isError: true);
      }
    } catch (_) {
      _showSnackBar("Tidak dapat menghubungi server.", isError: true);
    }
    setState(() => isLoading = false);
  }

  Future<void> _createAccount() async {
    final username = createUsernameController.text.trim();
    final password = createPasswordController.text.trim();
    final day = createDayController.text.trim();

    if (username.isEmpty || password.isEmpty || day.isEmpty) {
      _showSnackBar("Semua field wajib diisi.", isError: true);
      return;
    }

    setState(() => isLoading = true);
    Navigator.pop(context); // Tutup dialog sebelum memulai request
    try {
      final url = Uri.parse('https://tapops.fanzhosting.my.id/api/user/userAdd?key=$sessionKey&username=$username&password=$password&day=$day&role=$newUserRole');
      final res = await http.get(url);
      final data = jsonDecode(res.body);

      if (data['created'] == true) {
        _showSnackBar("Akun '${data['user']['username']}' berhasil dibuat.");
        _fetchUsers();
      } else {
        _showSnackBar(data['message'] ?? 'Gagal membuat akun.', isError: true);
      }
    } catch (_) {
      _showSnackBar("Gagal menghubungi server.", isError: true);
    }
    setState(() => isLoading = false);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4ADE80)))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildActionCards(),
            const SizedBox(height: 24),
            _buildFilterChips(),
            const SizedBox(height: 24),
            Expanded(child: _buildUserTable()),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCards() {
    return Row(
      children: [
        Expanded(
          child: _buildCard(
            title: 'Create User',
            icon: Icons.person_add,
            onTap: () => _showCreateUserDialog(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildCard(
            title: 'Delete User',
            icon: Icons.person_remove,
            onTap: () => _showDeleteUserDialog(),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required String title, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4ADE80).withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF4ADE80), size: 32),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8.0,
      children: roleOptions.map((role) {
        final isSelected = selectedRole == role;
        return FilterChip(
          label: Text(role.toUpperCase()),
          labelStyle: TextStyle(color: isSelected ? Colors.black : const Color(0xFF4ADE80)),
          selected: isSelected,
          onSelected: (isSelected) {
            setState(() {
              selectedRole = role;
              _filterAndPaginate();
            });
          },
          backgroundColor: Colors.grey[800],
          selectedColor: const Color(0xFF4ADE80),
          checkmarkColor: Colors.black,
          side: BorderSide(color: isSelected ? const Color(0xFF4ADE80) : Colors.grey.shade600),
        );
      }).toList(),
    );
  }

  Widget _buildUserTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4ADE80).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Text(
              'User List (${filteredList.length})',
              style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          // Menggunakan ListView yang lebih compact daripada DataTable
          _buildCompactListView(),
          _buildPaginationControls(),
        ],
      ),
    );
  }

  // Mengganti DataTable dengan ListView yang lebih compact
  Widget _buildCompactListView() {
    if (filteredList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: Text('No users found for this role.', style: TextStyle(color: Colors.grey))),
      );
    }

    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _getCurrentPageData().length,
        separatorBuilder: (context, index) => Divider(
          color: Colors.grey.shade700,
          height: 1,
        ),
        itemBuilder: (context, index) {
          final user = _getCurrentPageData()[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Username
                Expanded(
                  flex: 2,
                  child: Text(
                    user['username'] ?? 'N/A',
                    style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                    decoration: BoxDecoration(
                      color: _getRoleColor(user['role'] ?? 'member'),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      user['role'] ?? 'N/A',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // Expires
                const SizedBox(width: 40),
                Expanded(
                  flex: 2,
                  child: Text(
                    user['parent'] ?? 'SYSTEM',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Action
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFF4ADE80), size: 18),
                  onPressed: () => _showDeleteConfirmationDialog(user['username']),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper method untuk mendapatkan warna berdasarkan role
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'vip':
        return Colors.amber;
      case 'reseller':
        return Colors.blue;
      case 'reseller1':
        return Colors.lightBlue;
      case 'owner':
        return Colors.purple;
      default:
        return const Color(0xFF4ADE80); // Changed from Colors.grey to our green color
    }
  }

  Widget _buildPaginationControls() {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF4ADE80)),
            onPressed: currentPage > 1 ? () => setState(() => currentPage--) : null,
          ),
          Text(
            'Page $currentPage of $totalPages',
            style: const TextStyle(color: Color(0xFF4ADE80)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFF4ADE80)),
            onPressed: currentPage < totalPages ? () => setState(() => currentPage++) : null,
          ),
        ],
      ),
    );
  }

  // --- Dialogs ---
  void _showCreateUserDialog() {
    createUsernameController.clear();
    createPasswordController.clear();
    createDayController.clear();
    newUserRole = 'member';

    showDialog(
      context: context,
      builder: (_) => _buildCreateUserDialog(),
    );
  }

  Widget _buildCreateUserDialog() {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Create New User', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildTextField(controller: createUsernameController, label: 'Username'),
            const SizedBox(height: 16),
            _buildTextField(controller: createPasswordController, label: 'Password'),
            const SizedBox(height: 16),
            _buildTextField(controller: createDayController, label: 'Duration (days)', keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: newUserRole,
              dropdownColor: Colors.grey[800],
              style: const TextStyle(color: Color(0xFF4ADE80)),
              decoration: _inputDecoration('Role'),
              items: roleOptions.map((role) {
                return DropdownMenuItem(value: role, child: Text(role.toUpperCase()));
              }).toList(),
              onChanged: (val) => setState(() => newUserRole = val ?? 'member'),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _createAccount,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4ADE80), foregroundColor: Colors.black),
                  child: const Text('Create'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showDeleteUserDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Delete User', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildTextField(controller: deleteController, label: 'Username to delete'),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteUser(deleteController.text.trim());
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4ADE80)),
                    child: const Text('Delete'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(String username) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Confirm Delete', style: TextStyle(color: Color(0xFF4ADE80))),
        content: Text('Are you sure you want to delete user "$username"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(username);
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFF4ADE80))),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---
  Widget _buildTextField({required TextEditingController controller, required String label, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFF4ADE80)),
      decoration: _inputDecoration(label),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: const Color(0xFF4ADE80).withOpacity(0.7)),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF4ADE80)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF4ADE80)),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}