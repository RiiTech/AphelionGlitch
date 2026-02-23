// nik_check_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NIKCheckPage extends StatefulWidget {
  final String sessionKey;

  const NIKCheckPage({super.key, required this.sessionKey});

  @override
  State<NIKCheckPage> createState() => _NIKCheckPageState();
}

class _NIKCheckPageState extends State<NIKCheckPage> {
  final TextEditingController _nikController = TextEditingController();
  Map<String, dynamic>? _nikData;
  bool _isLoading = false;

  Future<void> _checkNIK() async {
    if (_nikController.text.isEmpty) return;
    setState(() {
      _isLoading = true;
      _nikData = null;
    });
    try {
      final response = await http.get(Uri.parse('https://ppl.nullxteam.fun/api/tools/nik-check?key=${widget.sessionKey}&nik=${_nikController.text}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          setState(() {
            _nikData = data;
          });
        } else {
          _showSnackBar('Invalid NIK or server error', isError: true);
        }
      } else {
        _showSnackBar('Failed to connect to NIK service', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red.shade900 : Colors.grey.shade800,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('NIK Check', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade800)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Enter NIK Number', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nikController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    maxLength: 16,
                    decoration: InputDecoration(
                      hintText: 'Enter 16-digit NIK number',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.shade800,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _checkNIK,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                    child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Text('Check NIK'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_nikData != null) _buildNIKResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildNIKResult() {
    final data = _nikData!['data'] as Map<String, dynamic>;
    final nikData = data['data'] as Map<String, dynamic>;
    final metadata = data['metadata'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade800)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NIK Information', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildInfoRow('NIK', nikData['nik'] ?? 'N/A'),
          _buildInfoRow('Name', nikData['nama'] ?? 'N/A'),
          _buildInfoRow('Gender', nikData['kelamin'] ?? 'N/A'),
          _buildInfoRow('Birth Date', nikData['tempat_lahir'] ?? 'N/A'),
          _buildInfoRow('Age', nikData['usia'] ?? 'N/A'),
          _buildInfoRow('Province', nikData['provinsi'] ?? 'N/A'),
          _buildInfoRow('Regency', nikData['kabupaten'] ?? 'N/A'),
          _buildInfoRow('District', nikData['kecamatan'] ?? 'N/A'),
          _buildInfoRow('Sub-district', nikData['kelurahan'] ?? 'N/A'),
          _buildInfoRow('Address', nikData['alamat'] ?? 'N/A'),
          _buildInfoRow('Zodiac', nikData['zodiak'] ?? 'N/A'),
          _buildInfoRow('Next Birthday', nikData['ultah_mendatang'] ?? 'N/A'),
          _buildInfoRow('Pasaran', nikData['pasaran'] ?? 'N/A'),
          const SizedBox(height: 16),
          const Text('Metadata', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildInfoRow('Search Method', metadata['metode_pencarian'] ?? 'N/A'),
          _buildInfoRow('Area Code', metadata['kode_wilayah'] ?? 'N/A'),
          _buildInfoRow('Sequence Number', metadata['nomor_urut'] ?? 'N/A'),
          _buildInfoRow('Age Category', metadata['kategori_usia'] ?? 'N/A'),
          _buildInfoRow('Area Type', metadata['jenis_wilayah'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$label:', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14))),
        ],
      ),
    );
  }
}