import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';

class ChatPage extends StatefulWidget {
  final String sessionKey;

  const ChatPage({super.key, required this.sessionKey});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late IOWebSocketChannel channel;
  List<String> chatUsers = [];
  String? selectedUser;
  List<Map<String, dynamic>> messages = [];
  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    channel = IOWebSocketChannel.connect('wss://ws.nullxteam.fun');

    channel.sink.add(jsonEncode({"type": "auth", "key": widget.sessionKey}));

    channel.stream.listen((event) {
      final data = jsonDecode(event);

      switch (data['type']) {
        case 'chatList':
          setState(() => chatUsers = List<String>.from(data['users']));
          break;
        case 'chat':
          if (selectedUser == data['message']['from'] ||
              selectedUser == data['message']['to']) {
            setState(() => messages.add(Map<String, dynamic>.from(data['message'])));
            _scrollToBottom();
          }
          break;
        case 'messages':
          setState(() => messages = List<Map<String, dynamic>>.from(data['messages']));
          _scrollToBottom();
          break;
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _loadMessages(String user) {
    setState(() {
      selectedUser = user;
      messages.clear();
    });
    channel.sink.add(jsonEncode({
      "type": "getMessages",
      "with": user,
    }));
  }

  void _sendMessage() {
    final msg = messageController.text.trim();
    if (msg.isEmpty || msg.length > 250 || selectedUser == null) return;

    channel.sink.add(jsonEncode({
      "type": "chat",
      "to": selectedUser,
      "message": msg,
    }));

    messageController.clear();
  }

  void _startNewChat() {
    String newUser = '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("New Chat", style: TextStyle(color: Colors.white)),
        content: TextField(
          onChanged: (val) => newUser = val,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter username...",
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(color: Colors.purpleAccent)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Start", style: TextStyle(color: Colors.purpleAccent)),
            onPressed: () {
              Navigator.pop(context);
              if (newUser.isNotEmpty) {
                setState(() => selectedUser = newUser);
                messages.clear();
                channel.sink.add(jsonEncode({"type": "getMessages", "with": newUser}));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _chatBubble(Map msg) {
    final isMe = msg['fromMe'] == true;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
            colors: [Colors.purpleAccent, Colors.deepPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : const LinearGradient(
            colors: [Colors.grey, Colors.black54],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  msg['from'] ?? '',
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ),
            Text(msg['message'],
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    channel.sink.close();
    messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: selectedUser == null ? _buildChatList() : _buildChatScreen(),
    );
  }

  // 🔹 List Chat View
  Widget _buildChatList() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black87, Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: const Text(
              "💬 Chats",
              style: TextStyle(
                fontSize: 18,
                fontFamily: "Orbitron",
                fontWeight: FontWeight.bold,
                color: Colors.purpleAccent,
              ),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, color: Colors.white, size: 16),
            label: const Text("New", style: TextStyle(color: Colors.white)),
            onPressed: _startNewChat,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: chatUsers.length,
              itemBuilder: (context, index) {
                final user = chatUsers[index];
                return Card(
                  color: Colors.white10,
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purpleAccent,
                      child: Text(user[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(user,
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                    onTap: () => _loadMessages(user),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Chat Screen View
  Widget _buildChatScreen() {
    return Column(
      children: [
        // Header dengan tombol back
        Container(
          padding: const EdgeInsets.all(14),
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.black, Colors.black],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.purpleAccent.withOpacity(0.4), blurRadius: 6)
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    selectedUser = null;
                    messages.clear();
                  });
                },
              ),
              CircleAvatar(
                backgroundColor: Colors.purpleAccent,
                child: const Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Chatting with @$selectedUser",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
        ),

        // Chat body
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Colors.black],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 300),
                  child: _chatBubble(msg),
                );
              },
            ),
          ),
        ),

        // Input pesan
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            border:
            const Border(top: BorderSide(color: Colors.purple, width: 0.4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 250,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: "Type message...",
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.purpleAccent,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
