import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BuyAccountPage extends StatelessWidget {
  const BuyAccountPage({super.key});

  final List<Map<String, String>> priceList = const [
    {
      "title": "Member Account",
      "monthly": "20K IDR / Month",
      "permanent": "25K IDR / Permanent",
    },
    {
      "title": "Reseller Account",
      "monthly": "40K IDR / Month",
      "permanent": "50K IDR / Permanent",
    },
    {
      "title": "VIP Account",
      "monthly": "30K IDR / Month",
      "permanent": "40K IDR / Permanent",
    },
  ];

  Future<void> _showContactDialog(BuildContext context, String plan) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black87,
        title: Text(
          "Buy $plan",
          style: const TextStyle(
            color: Colors.purpleAccent,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "Choose a contact method to continue your purchase:",
          style: TextStyle(color: Colors.white70, fontFamily: 'ShareTechMono'),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.telegram, color: Colors.lightBlueAccent),
            label: const Text("Telegram",
                style: TextStyle(color: Colors.lightBlueAccent)),
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse("tg://resolve?domain=Zenithoffc");
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                await launchUrl(Uri.parse("https://t.me/Zenithoffc"),
                    mode: LaunchMode.externalApplication);
              }
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.chat, color: Colors.green),
            label:
            const Text("WhatsApp", style: TextStyle(color: Colors.green)),
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse(
                  "https://wa.me/6283823030055?text=Hello%20I%20want%20to%20buy%20$plan");
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE",
                style: TextStyle(color: Colors.white70)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "Buy Account",
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.purpleAccent),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: priceList.length,
        itemBuilder: (context, index) {
          final item = priceList[index];
          return Card(
            color: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.purpleAccent, width: 1.2),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item["title"]!,
                    style: const TextStyle(
                      color: Colors.purpleAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item["monthly"]!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'ShareTechMono',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item["permanent"]!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontFamily: 'ShareTechMono',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        _showContactDialog(context, item["title"]!);
                      },
                      child: const Text(
                        "BUY",
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
