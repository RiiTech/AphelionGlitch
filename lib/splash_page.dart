import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();

    // Load video dari assets
    _controller = VideoPlayerController.asset("assets/videos/splash.mp4")
      ..initialize().then((_) {
        setState(() {}); // rebuild setelah video siap
        _controller.play(); // auto play
      });

    _controller.setLooping(false); // splash cuma sekali
    _controller.addListener(() {
      // kalau sudah selesai, pindah ke login
      if (_controller.value.isInitialized &&
          !_controller.value.isPlaying &&
          _controller.value.position >= _controller.value.duration) {
        Navigator.pushReplacementNamed(context, '/');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Video agak kecil
            _controller.value.isInitialized
                ? SizedBox(
              height: 160,
              width: 160,
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
                : const CircularProgressIndicator(
              color: Colors.white,
            ),

            const SizedBox(height: 30),

            // Progress bar
            SizedBox(
              width: 180,
              child: LinearProgressIndicator(
                color: Colors.white,
                backgroundColor: Colors.white12,
                minHeight: 5,
                borderRadius: BorderRadius.circular(8),
              ),
            ),

            const SizedBox(height: 20),

            // Tulisan versi
            Image.asset(
              'assets/images/title.png', // Ganti dengan path ke file logo Anda
              height: 40,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}
