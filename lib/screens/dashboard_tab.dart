import 'package:flutter/material.dart';
import '../store.dart';
import '../design_system.dart';
import '../widgets/common.dart';
import 'home_content.dart';
import 'home_model.dart';
import '../home_week_calendar.dart';
import '../pet_profile_carousel.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({
    super.key,
    required this.model,
    required this.hostContext,
  });
  final HomeModel model;
  final BuildContext hostContext;
  @override
  Widget build(BuildContext context) =>
      _DashboardTabContent(hostContext, model).render();
}

class _DashboardTabContent extends HomeContent {
  _DashboardTabContent(super.context, super.model);
  Widget render() => dashboard();
  Future<void> recordPetMemory(RecordData pet) async {
    setState(() {
      selectedPetId = pet['id'];
      editingMemories = false;
      memoryDate = DateUtils.dateOnly(korea(s.clock()));
      tab = 1;
    });
    await editMemoryPhoto(initialDate: memoryDate, petId: pet['id']);
  }

  Widget dashboard() => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        key: const ValueKey('home-dashboard'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title('함께라서 더 좋은 하루 🐾', '평범한 오늘이, 소중한 추억이 되는 곳'),
          if (selectedPet == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  const Icon(Icons.pets_outlined, size: 44, color: muted),
                  const SizedBox(height: 12),
                  const Text('우리 가족을 먼저 소개해 주세요.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => editOwned('pets'),
                    child: const Text('반려동물 등록'),
                  ),
                ],
              ),
            )
          else
            PetProfileCarousel(
              pets: owned('pets'),
              selectedId: selectedPet!['id'],
              onSelected: (id) => setState(() => selectedPetId = id),
              onRecord: recordPetMemory,
              onFamily: () => setState(() => tab = 4),
              origin: selectedOrigin,
              originForPet: (id) => s.memoryOriginFor(id),
              today: DateUtils.dateOnly(korea(s.clock())),
              onSetup: selectedPet == null ? null : setupMemoryOrigin,
              photoBuilder: (source) => photo(
                source,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          const SizedBox(height: 16),
          HomeWeekCalendar(
            today: DateUtils.dateOnly(korea(s.clock())),
            origin: selectedOrigin,
            selectedDate: homeDate ?? DateUtils.dateOnly(korea(s.clock())),
            meetingDates: s
                .rows('meetings')
                .where((m) => s.joined(m) && m['canceled'] != true)
                .map((m) => dayKey(korea(DateTime.parse(m['at']))))
                .toSet(),
            onSetup: selectedPet == null ? null : setupMemoryOrigin,
            onDateSelected: (date) => setState(() => homeDate = date),
          ),
          const SizedBox(height: 14),
          homeDayMemory(),
          const SizedBox(height: 10),
          homeDayMeetings(),
        ],
      ),
    ),
  );

  DateTime get homeSelectedDate =>
      homeDate ?? DateUtils.dateOnly(korea(s.clock()));

  Future<void> recordHomeMemory() async {
    final pet = selectedPet;
    if (pet == null) {
      await editOwned('pets');
      return;
    }
    setState(() {
      memoryDate = homeSelectedDate;
      editingMemories = false;
      tab = 1;
    });
    await editMemoryPhoto(initialDate: memoryDate, petId: pet['id']);
  }

  Widget homeDayMemory() {
    final date = homeSelectedDate;
    final today = DateUtils.dateOnly(korea(s.clock()));
    final isToday = DateUtils.isSameDay(date, today);
    final future = date.isAfter(today);
    final dateKey = dayKey(date);
    final memories = selectedPetMemories
        .where((m) => m['date'] == dateKey)
        .take(3)
        .toList();
    final journal = s.memoryDay(dateKey, petId: selectedPet?['id']);
    final title = (journal['title'] as String? ?? '').trim();
    final emptyLabel = future
        ? '이날의 추억이 기다리고 있어요'
        : isToday
        ? '오늘의 추억을 기록하기'
        : '이날의 추억을 기록하기';
    Widget tile(int index) {
      final memory = memories[index];
      return InkWell(
        key: ValueKey('home-day-photo-$index'),
        onTap: () => viewMemory(memory),
        child: Semantics(
          label: '추억 사진 ${index + 1} 보기',
          child: KeyedSubtree(
            key: ValueKey("home-memory-${memory['id']}"),
            child: photo(
              memory['photo'],
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
      );
    }

    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        key: const ValueKey('home-memory-collage'),
        width: 80,
        height: 80,
        child: memories.isEmpty
            ? InkWell(
                onTap: future ? null : recordHomeMemory,
                child: const ColoredBox(
                  color: AppColors.quietSurface,
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: muted,
                    size: 28,
                  ),
                ),
              )
            : memories.length == 1
            ? tile(0)
            : Row(
                children: [
                  Expanded(flex: memories.length == 3 ? 3 : 1, child: tile(0)),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 2,
                    child: memories.length == 2
                        ? tile(1)
                        : Column(
                            children: [
                              Expanded(child: tile(1)),
                              const SizedBox(height: 2),
                              Expanded(child: tile(2)),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
    return Card(
      key: const ValueKey('home-day-memories'),
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: memories.isEmpty
            ? future
                  ? null
                  : recordHomeMemory
            : () => setState(() {
                memoryDate = date;
                editingMemories = false;
                tab = 1;
              }),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              thumbnail,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday ? '오늘의 추억' : '${date.month}월 ${date.day}일의 추억',
                      style: AppText.captionMuted,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title.isNotEmpty
                          ? title
                          : memories.isEmpty
                          ? emptyLabel
                          : '소중한 하루의 한 조각',
                      key: const ValueKey('home-memory-title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (title.isNotEmpty && memories.isEmpty) ...[
                      const SizedBox(height: 4),
                      Text(emptyLabel, style: AppText.captionMuted),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget homeDayMeetings() {
    final date = dayKey(homeSelectedDate);
    final meetings =
        s
            .rows('meetings')
            .where(
              (m) =>
                  s.joined(m) &&
                  m['canceled'] != true &&
                  dayKey(korea(DateTime.parse(m['at']))) == date,
            )
            .toList()
          ..sort(
            (a, b) =>
                DateTime.parse(a['at']).compareTo(DateTime.parse(b['at'])),
          );
    if (meetings.isEmpty) {
      return Container(
        key: const ValueKey('home-meetings-empty'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.daySurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.wb_sunny_outlined, color: AppColors.accent, size: 26),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '약속 없이, 우리만의 느긋한 하루',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '서로의 곁에서 쉬어 가도 좋아요.',
                    style: TextStyle(
                      fontSize: AppText.minimumSize,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final meeting in meetings)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              key: ValueKey("home-meeting-${meeting['id']}"),
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.cardBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => showMeeting(meeting['id']),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      meetingParticipants(meeting),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '함께하는 약속',
                              style: TextStyle(
                                fontSize: AppText.minimumSize,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              meeting['title'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              stamp(DateTime.parse(meeting['at'])),
                              style: AppText.captionMuted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
