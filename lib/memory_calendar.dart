import 'design_system.dart';
import 'package:flutter/material.dart';
import 'store.dart';

/// Seven consecutive Days, counted from the user's chosen Day 0.
class MemoryDayCalendar extends StatefulWidget {
  const MemoryDayCalendar({
    super.key,
    required this.origin,
    required this.selectedDate,
    required this.today,
    required this.originLabel,
    required this.dayBuilder,
    required this.onSelected,
    required this.onSetup,
  });
  final DateTime? origin;
  final DateTime selectedDate;
  final DateTime today;
  final String originLabel;
  final Widget Function(DateTime) dayBuilder;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onSetup;
  @override
  State<MemoryDayCalendar> createState() => _MemoryDayCalendarState();
}

class _MemoryDayCalendarState extends State<MemoryDayCalendar> {
  late PageController controller;
  int get lastPage => daysBetween(widget.origin!, widget.today) ~/ 7;
  int pageOf(DateTime date) =>
      (daysBetween(widget.origin!, date) ~/ 7).clamp(0, lastPage);
  @override
  void initState() {
    super.initState();
    controller = PageController(
      initialPage: widget.origin == null ? 0 : pageOf(widget.selectedDate),
    );
  }

  @override
  void didUpdateWidget(MemoryDayCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.origin == null) return;
    final target = pageOf(widget.selectedDate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.origin != null &&
          controller.hasClients &&
          target == pageOf(widget.selectedDate) &&
          controller.page?.round() != target) {
        controller.jumpToPage(target);
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void move(int page) => controller.animateToPage(
    page,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      key: const ValueKey('memory-day-calendar'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: widget.origin == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '우리의 Day 0',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  '첫 만남 또는 첫 사진부터 함께한 날을 세어요.',
                  style: AppText.caption,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: widget.onSetup,
                  child: const Text('시작 기준 설정'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Day 0 · ${widget.originLabel}\n${dayKey(widget.origin!)}',
                        style: AppText.captionComfortable,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Day 0 설정',
                      onPressed: widget.onSetup,
                      icon: const Icon(Icons.tune, size: 19),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: PageView.builder(
                    key: const ValueKey('memory-weeks'),
                    controller: controller,
                    itemCount: lastPage + 1,
                    onPageChanged: (page) {
                      if (pageOf(widget.selectedDate) == page) return;
                      final offset =
                          daysBetween(
                            widget.origin!,
                            widget.selectedDate,
                          ).clamp(0, 100000) %
                          7;
                      final day = DateTime(
                        widget.origin!.year,
                        widget.origin!.month,
                        widget.origin!.day + page * 7 + offset,
                      );
                      widget.onSelected(
                        day.isAfter(widget.today) ? widget.today : day,
                      );
                    },
                    itemBuilder: (context, page) => Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: '이전 주',
                              onPressed: page > 0 ? () => move(page - 1) : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Text(
                                'Day ${page * 7} – ${page * 7 + 6}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '다음 주',
                              onPressed: page < lastPage
                                  ? () => move(page + 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        Row(
                          children: List.generate(
                            7,
                            (index) => Expanded(
                              child: widget.dayBuilder(
                                DateTime(
                                  widget.origin!.year,
                                  widget.origin!.month,
                                  widget.origin!.day + page * 7 + index,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '사진이 있는 Day만 진하게 · 좌우로 밀어 이동',
                        style: TextStyle(
                          fontSize: AppText.minimumSize,
                          color: primary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onSelected(widget.today),
                      child: const Text('오늘'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
