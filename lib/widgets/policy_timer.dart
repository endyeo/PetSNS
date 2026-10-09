import 'dart:async';
import 'package:flutter/material.dart';
import '../store.dart';

class PolicyBuilder extends StatefulWidget {
  const PolicyBuilder({
    super.key,
    required this.store,
    required this.builder,
    required this.dates,
  });
  final PetStore store;
  final WidgetBuilder builder;
  final Iterable<DateTime> Function() dates;
  @override
  State<PolicyBuilder> createState() => _PolicyBuilderState();
}

class _PolicyBuilderState extends State<PolicyBuilder>
    with WidgetsBindingObserver, PolicyTimer<PolicyBuilder> {
  @override
  PetStore get timeStore => widget.store;
  @override
  Iterable<DateTime> get policyDates => widget.dates();
  @override
  void initState() {
    super.initState();
    startPolicyTimer();
  }

  @override
  void dispose() {
    stopPolicyTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

// Wake at a policy boundary, and recheck after the app resumes.
mixin PolicyTimer<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  PetStore get timeStore;
  Timer? _policyTimer;

  Iterable<DateTime> get policyDates sync* {
    for (final meeting in timeStore.rows('meetings')) {
      if (meeting['canceled'] == true) continue;
      final at = DateTime.parse(meeting['at']);
      yield meetingDeadline(at);
      yield at.toUtc();
      yield chatClose(at);
    }
    final today = korea(timeStore.clock());
    yield DateTime.utc(
      today.year,
      today.month,
      today.day + 1,
    ).subtract(const Duration(hours: 9));
  }

  void startPolicyTimer() {
    WidgetsBinding.instance.addObserver(this);
    timeStore.addListener(refreshPolicy);
    _schedulePolicy();
  }

  void stopPolicyTimer() {
    WidgetsBinding.instance.removeObserver(this);
    timeStore.removeListener(refreshPolicy);
    _policyTimer?.cancel();
  }

  void _schedulePolicy() {
    _policyTimer?.cancel();
    final now = timeStore.clock().toUtc();
    final dates = policyDates.where((date) => date.isAfter(now)).toList()
      ..sort();
    if (dates.isNotEmpty) {
      _policyTimer = Timer(dates.first.difference(now), refreshPolicy);
    }
  }

  void refreshPolicy() {
    if (!mounted) return;
    _schedulePolicy();
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshPolicy();
  }
}
