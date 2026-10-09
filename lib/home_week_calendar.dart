import 'design_system.dart';
import 'package:flutter/material.dart';
import 'store.dart';

/// Real dates for weekly memories and appointments; only today has a Day label.
class HomeWeekCalendar extends StatefulWidget {
  const HomeWeekCalendar({
    super.key,
    required this.today,
    required this.origin,
    required this.selectedDate,
    required this.meetingDates,
    required this.onDateSelected,
    this.onSetup,
  });
  final DateTime today;
  final DateTime? origin;
  final DateTime selectedDate;
  final Set<String> meetingDates;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback? onSetup;

  @override
  State<HomeWeekCalendar> createState() => _HomeWeekCalendarState();
}

class _HomeWeekCalendarState extends State<HomeWeekCalendar> {
  int offset = 0;
  double drag = 0;
  DateTime get start => DateTime(
    widget.today.year,
    widget.today.month,
    widget.today.day - widget.today.weekday + 1 + offset * 7,
  );

  @override
  Widget build(BuildContext context) {
    final week = start;
    final end = DateTime(week.year, week.month, week.day + 6);
    return Container(
      key: const ValueKey('home-week-calendar'),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '이전 주',
                onPressed: () => setState(() => offset--),
                icon: const Icon(Icons.chevron_left, size: 20),
              ),
              Expanded(
                child: Text(
                  '${week.month}.${week.day} – ${end.month}.${end.day} · 추억과 약속',
                  textAlign: TextAlign.center,
                  style: AppText.captionStrong,
                ),
              ),
              if (offset != 0)
                TextButton(
                  onPressed: () {
                    setState(() => offset = 0);
                    widget.onDateSelected(widget.today);
                  },
                  child: const Text('오늘', style: AppText.caption),
                ),
              IconButton(
                tooltip: '다음 주',
                onPressed: () => setState(() => offset++),
                icon: const Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => drag = 0,
            onHorizontalDragUpdate: (details) => drag += details.delta.dx,
            onHorizontalDragEnd: (_) {
              if (drag.abs() > 35) setState(() => offset += drag < 0 ? 1 : -1);
            },
            child: Row(
              children: List.generate(7, (index) {
                final date = DateTime(week.year, week.month, week.day + index);
                final today = DateUtils.isSameDay(date, widget.today);
                final selected = DateUtils.isSameDay(date, widget.selectedDate);
                final appointment = widget.meetingDates.contains(dayKey(date));
                final count = widget.origin == null
                    ? null
                    : daysBetween(widget.origin!, date);
                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        const ['월', '화', '수', '목', '금', '토', '일'][index],
                        style: AppText.captionMuted,
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => widget.onDateSelected(date),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          key: ValueKey('home-date-${dayKey(date)}'),
                          width: 34,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: appointment
                                ? AppColors.anniversary
                                : today
                                ? AppColors.today
                                : AppColors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: selected
                                ? Border.all(
                                    color: AppColors.primary,
                                    width: 1.5,
                                  )
                                : today
                                ? Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: .35,
                                    ),
                                  )
                                : null,
                          ),
                          child: Semantics(
                            label:
                                '${dayKey(date)}${today ? ', 오늘' : ''}${appointment ? ', 약속 있음' : ''}',
                            child: Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: today || appointment
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 24,
                        child: today
                            ? count != null && count >= 0
                                  ? Center(
                                      child: Text(
                                        'Day $count',
                                        key: const ValueKey('home-today-day'),
                                        style: AppText.captionPrimary,
                                      ),
                                    )
                                  : InkWell(
                                      onTap: widget.onSetup,
                                      child: const Center(
                                        child: Text(
                                          '기준 설정',
                                          style: TextStyle(
                                            fontSize: AppText.minimumSize,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    )
                            : null,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
