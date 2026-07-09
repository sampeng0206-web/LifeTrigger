import 'dart:async';
import 'package:flutter/material.dart';

class CountdownDisplay extends StatefulWidget {
  final DateTime deadline;

  const CountdownDisplay({super.key, required this.deadline});

  @override
  State<CountdownDisplay> createState() => _CountdownDisplayState();
}

class _CountdownDisplayState extends State<CountdownDisplay> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateRemaining();
    });
  }

  @override
  void didUpdateWidget(covariant CountdownDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateRemaining();
  }

  void _updateRemaining() {
    if (!mounted) return;
    setState(() {
      _remaining = widget.deadline.difference(DateTime.now());
      if (_remaining.isNegative) {
        _remaining = Duration.zero;
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) {
      return const Text(
        '已過確認時間',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.redAccent,
        ),
      );
    }

    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;

    String text;
    if (days > 0) {
      text = '距離下次確認還有\n$days天$hours小時$minutes分鐘';
    } else {
      text = '距離下次確認還有\n$hours小時$minutes分鐘';
    }

    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        height: 1.4,
      ),
    );
  }
}
