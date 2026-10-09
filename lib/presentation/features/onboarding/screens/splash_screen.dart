import 'package:flutter/material.dart';

import 'package:napex_victim_app/presentation/shared/widgets/entrance.dart';

/// شاشة انتظار — استعادة الجلسة بتصميم متدرج
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const _gradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF0D3B66), Color(0xFF092A4A), Color(0xFF061C31)],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _gradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Entrance(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E5A96), Color(0xFF0D3B66)],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B998B).withValues(alpha: 0.3),
                        blurRadius: 44,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Entrance(
                delay: Duration(milliseconds: 180),
                child: Text(
                  'NAP-EX',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 5,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Entrance(
                delay: Duration(milliseconds: 320),
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
