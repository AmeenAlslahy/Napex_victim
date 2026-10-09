import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:napex_victim_app/core/constants/app_constants.dart';

/// حقل إدخال رمز OTP — خانات منفصلة تلقائية الانتقال
class OtpInput extends StatefulWidget {
  const OtpInput({
    required this.onCompleted,
    super.key,
    this.length = AppConstants.otpLength,
  });

  final int length;
  final ValueChanged<String> onCompleted;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers =
        List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      // لصق الرمز كاملاً
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      _fillFrom(index, digits);
      return;
    }

    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    _notifyIfComplete();
  }

  void _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  void _fillFrom(int start, String digits) {
    for (var i = 0; i < widget.length; i++) {
      if (i >= start && i - start < digits.length) {
        _controllers[i].text = digits[i - start];
      }
    }
    final lastFilled = (start + digits.length - 1)
        .clamp(0, widget.length - 1);
    _focusNodes[lastFilled].requestFocus();
    _notifyIfComplete();
  }

  void _notifyIfComplete() {
    final code =
        _controllers.map((c) => c.text).join();
    if (code.length == widget.length) {
      widget.onCompleted(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.length, (index) {
          return Container(
            width: 46,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            child: KeyboardListener(
              focusNode: FocusNode(skipTraversal: true),
              onKeyEvent: (event) => _onKey(index, event),
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                decoration: const InputDecoration(counterText: ''),
                onChanged: (value) => _onChanged(index, value),
              ),
            ),
          );
        }),
      ),
    );
  }
}
