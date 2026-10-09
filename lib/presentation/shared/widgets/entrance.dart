import 'dart:async';

import 'package:flutter/material.dart';

/// ظهور متحرك (شفافية + انزلاق) مع تأخير اختياري
/// يُستخدم للدخول المتدرج للعناصر في شاشات الـ Onboarding
class Entrance extends StatefulWidget {
  const Entrance({
    required this.child,
    super.key,
    this.delay = Duration.zero,
    this.slideFrom = const Offset(0, 0.06),
  });

  final Widget child;
  final Duration delay;
  final Offset slideFrom;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : widget.slideFrom,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
