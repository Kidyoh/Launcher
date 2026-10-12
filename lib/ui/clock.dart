import 'dart:async';

import 'package:flutter/material.dart';

import '../native.dart';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Wakes once per minute, exactly on the minute, and not at all while the
/// launcher is in the background.
class Clock extends StatefulWidget {
  const Clock({
    super.key,
    required this.showTime,
    required this.showDate,
    required this.crossAxisAlignment,
    required this.scale,
  });

  final bool showTime;
  final bool showDate;
  final CrossAxisAlignment crossAxisAlignment;
  final double scale;

  @override
  State<Clock> createState() => _ClockState();
}

class _ClockState extends State<Clock> with WidgetsBindingObserver {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tick();
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _schedule() {
    _timer?.cancel();
    final now = DateTime.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _timer = Timer(next.difference(now), _tick);
  }

  void _tick() {
    setState(() => _now = DateTime.now());
    _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final hour = use24
        ? _now.hour
        : (_now.hour % 12 == 0 ? 12 : _now.hour % 12);
    final minute = _now.minute.toString().padLeft(2, '0');
    final time = use24
        ? '${hour.toString().padLeft(2, '0')}:$minute'
        : '$hour:$minute';
    final date =
        '${_weekdays[_now.weekday - 1]}, ${_months[_now.month - 1]} ${_now.day}';

    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      children: [
        if (widget.showTime)
          GestureDetector(
            onTap: () => Native.open('alarms'),
            child: Text(
              time,
              style: TextStyle(
                fontSize: 76 * widget.scale,
                fontWeight: FontWeight.w200,
                height: 1.05,
                letterSpacing: -2,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        if (widget.showDate)
          GestureDetector(
            onTap: () => Native.open('calendar'),
            child: Padding(
              padding: const EdgeInsets.only(top: 4, left: 3, right: 3),
              child: Text(
                date,
                style: TextStyle(
                  fontSize: 16 * widget.scale,
                  letterSpacing: 0.3,
                  color: color.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
