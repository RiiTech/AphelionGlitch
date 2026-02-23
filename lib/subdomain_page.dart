import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SubdomainPage extends StatefulWidget {
  const SubdomainPage({super.key});

  @override
  State<SubdomainPage> createState() => _SubdomainPageState();
}

class _SubdomainPageState extends State<SubdomainPage> {
  final TextEditingController _controller =
  TextEditingController(text: "google.com");

  bool isLoading = false;
  List<Map<String, dynamic>> subdomains = [];

  Future<void> fetchSubdomains() async {
    final domain = _controller.text.trim();
    if (domain.isEmpty) return;

    setState(() {
      isLoading = true;
      subdomains.clear();
    });

    try {
      final uri = Uri.parse(
          "https://api.siputzx.my.id/api/tools/subdomains?domain=$domain");
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (data["data"] is List) {
          final List subs = data["data"];

          // tampilkan dulu list dengan status loading
          setState(() {
            subdomains = subs
                .map((s) => {
              "sub": s,
              "status": "⏳ Checking...",
              "statusColor": Colors.orange,
              "title": "Loading...",
              "loading": true,
            })
                .toList();
          });

          // cek tiap subdomain paralel
          for (int i = 0; i < subs.length; i++) {
            checkSubdomain(subs[i], i);
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetch: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> checkSubdomain(String sub, int index) async {
    String status = "❌ Inactive";
    Color statusColor = Colors.red;
    String title = "N/A";

    for (var scheme in ["https://", "http://"]) {
      final url = "$scheme$sub";
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 5));

        // 🔥 Semua status code diterima
        status = "✅ Active (${res.statusCode})";
        statusColor = Colors.green;

        // ambil <title> kalau ada
        final regex = RegExp(r"<title>(.*?)</title>",
            caseSensitive: false, dotAll: true);
        final match = regex.firstMatch(res.body);
        if (match != null) {
          title = match.group(1)!.trim();
        }
        break;
      } catch (_) {}
    }

    setState(() {
      subdomains[index]["status"] = status;
      subdomains[index]["statusColor"] = statusColor;
      subdomains[index]["title"] = title;
      subdomains[index]["loading"] = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Enter Domain",
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white12,
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text("Find Subdomains"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: fetchSubdomains,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.purpleAccent,
                ),
              )
                  : subdomains.isEmpty
                  ? const Center(
                child: Text(
                  "No subdomains found.",
                  style: TextStyle(color: Colors.white70),
                ),
              )
                  : ListView.builder(
                itemCount: subdomains.length,
                itemBuilder: (context, index) {
                  final sub = subdomains[index];
                  return Card(
                    color: Colors.white10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(
                        sub["sub"],
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          sub["loading"] == true
                              ? Row(
                            children: const [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.orange,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Checking...",
                                style: TextStyle(
                                    color: Colors.orange),
                              ),
                            ],
                          )
                              : Text(
                            "Status: ${sub["status"]}",
                            style: TextStyle(
                                color: sub["statusColor"]),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Title: ${sub["title"]}",
                            style: const TextStyle(
                                color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
