import 'package:flutter/material.dart';
import '../store.dart';
import '../design_system.dart';
import '../widgets/common.dart';
import 'home_content.dart';
import 'home_model.dart';
import '../memory_calendar.dart';

class MemoryTab extends StatelessWidget {
  const MemoryTab({super.key, required this.model, required this.hostContext});
  final HomeModel model;
  final BuildContext hostContext;
  @override
  Widget build(BuildContext context) =>
      _MemoryTabContent(hostContext, model).render();
}

class _MemoryTabContent extends HomeContent {
  _MemoryTabContent(super.context, super.model);
  Widget render() => memories();
  Widget memories() {
    final records = selectedPetMemories;
    final dateKey = memoryDayKey(memoryDate);
    final day = s.memoryDay(dateKey, petId: selectedPet?['id']);
    final dayPhotos = records.where((m) => m['date'] == dateKey).toList();
    final counts = <String, int>{};
    for (final photo in records) {
      counts[photo['date']] = (counts[photo['date']] ?? 0) + 1;
    }
    final origin = selectedOrigin;
    final dayNumber = origin == null ? null : daysBetween(origin, memoryDate);
    final calendar = MemoryDayCalendar(
      origin: origin,
      selectedDate: memoryDate,
      today: DateUtils.dateOnly(korea(s.clock())),
      originLabel: selectedPet?['memoryOriginType'] == 'firstMeeting'
          ? '첫 만남'
          : '첫 사진',
      dayBuilder: (date) => memoryCalendarDay(date, counts),
      onSelected: (date) => setState(() => memoryDate = date),
      onSetup: setupMemoryOrigin,
    );
    final journal = Container(
      key: const ValueKey('memory-day-journal'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dayNumber == null ? '하루 기록' : 'Day $dayNumber',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (day['anniversary'] == true) tag('기념일', color: coral),
              if (editingMemories)
                TextButton(onPressed: editMemoryDay, child: const Text('글 수정')),
            ],
          ),
          const SizedBox(height: 6),
          Text(dateKey, style: AppText.captionMuted),
          const SizedBox(height: 16),
          Text(
            (day['title'] as String).isEmpty ? '이날의 제목을 남겨보세요.' : day['title'],
            key: const ValueKey('memory-day-title'),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: (day['title'] as String).isEmpty ? muted : ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            (day['note'] as String).isEmpty
                ? '함께한 하루의 이야기를 기록해 보세요.'
                : day['note'],
            key: const ValueKey('memory-day-note'),
            style: const TextStyle(fontSize: 13, height: 1.8),
          ),
          if (!editingMemories && (day['title'] as String).isEmpty)
            TextButton(onPressed: editMemoryDay, child: const Text('하루 기록')),
        ],
      ),
    );
    final firstColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [calendar, const SizedBox(height: 16), journal],
    );
    final gallery = Column(
      key: const ValueKey('memory-gallery'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.photoCleanupPending)
          Row(
            children: [
              const Expanded(
                child: Text('삭제하지 못한 사진 파일이 남아 있습니다. 정리를 다시 시도해 주세요.'),
              ),
              TextButton(
                onPressed: s.busy
                    ? null
                    : () => attempt(context, s.retryPhotoCleanup),
                child: const Text('파일 정리'),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '사진 ${dayPhotos.length}장',
                  style: AppText.captionMuted,
                ),
              ),
              if (editingMemories)
                const Text(
                  '사진을 눌러 수정',
                  style: TextStyle(fontSize: AppText.minimumSize, color: coral),
                ),
            ],
          ),
        ),
        if (dayPhotos.isEmpty)
          empty(
            '이날은 아직 담긴 사진이 없어요',
            '추억 기록으로 사진을 추가해 주세요.',
            Icons.photo_library_outlined,
          )
        else
          memoryPhotoGrid(dayPhotos),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '추억 보관함',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: () =>
                  setState(() => editingMemories = !editingMemories),
              child: Text(editingMemories ? '완료' : '수정'),
            ),
            FilledButton(
              onPressed: selectedPet == null
                  ? null
                  : () => editOwned('memories', initialDate: memoryDate),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              child: const Text('추억 기록'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (owned('pets').length > 1)
          DropdownButtonFormField<String>(
            key: ValueKey('memory-pet-selector-${selectedPet?['id']}'),
            initialValue: selectedPet?['id'],
            decoration: const InputDecoration(labelText: '함께한 가족'),
            items: owned('pets')
                .map(
                  (pet) => DropdownMenuItem<String>(
                    value: pet['id'],
                    child: Text(pet['name']),
                  ),
                )
                .toList(),
            onChanged: (id) {
              if (id != null) selectPet(id);
            },
          ),
        if (owned('pets').length == 1)
          Text(
            "${selectedPet!['name']}의 추억",
            style: const TextStyle(fontSize: 13, color: muted),
          ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [firstColumn, const SizedBox(height: 20), gallery],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 330, child: firstColumn),
                const SizedBox(width: 24),
                Expanded(child: gallery),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget memoryCalendarDay(DateTime date, Map<String, int> counts) {
    final origin = selectedOrigin!;
    final dateKey = memoryDayKey(date);
    final selected = DateUtils.isSameDay(date, memoryDate);
    final enabled = !date.isAfter(DateUtils.dateOnly(korea(s.clock())));
    final hasPhoto = (counts[dateKey] ?? 0) > 0;
    final day = daysBetween(origin, date);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        selected: selected,
        child: Tooltip(
          message: 'Day $day · $dateKey · 사진 ${counts[dateKey] ?? 0}장',
          child: InkWell(
            key: ValueKey('memory-day-$dateKey'),
            onTap: enabled ? () => setState(() => memoryDate = date) : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: selected
                    ? coral.withValues(alpha: .08)
                    : AppColors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: selected ? Border.all(color: coral) : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 16,
                        color: hasPhoto ? ink : muted.withValues(alpha: .35),
                        fontWeight: hasPhoto
                            ? FontWeight.w800
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.month}.${date.day}',
                    style: TextStyle(
                      fontSize: AppText.minimumSize,
                      color: hasPhoto ? muted : muted.withValues(alpha: .35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget memoryPhotoGrid(List<RecordData> memories) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (editingMemories)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            '수정할 사진을 선택해 주세요.',
            style: TextStyle(fontSize: AppText.minimumSize, color: coral),
          ),
        ),
      GridView.builder(
        key: const ValueKey('memory-photo-grid'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
        ),
        itemCount: memories.length,
        itemBuilder: (context, index) {
          final memory = memories[index];
          return Semantics(
            label:
                '${editingMemories ? '수정' : '보기'}: ${memory['date']} 사진 ${index + 1}',
            button: true,
            child: InkWell(
              key: ValueKey('memory-photo-${memory['id']}'),
              onTap: () => editingMemories
                  ? editOwned('memories', existing: memory)
                  : viewMemory(memory),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photo(
                    memory['photo'],
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  if (editingMemories)
                    const Positioned(
                      right: 5,
                      top: 5,
                      child: CircleAvatar(
                        radius: 13,
                        backgroundColor: coral,
                        child: Icon(
                          Icons.edit,
                          color: AppColors.surface,
                          size: 15,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );

  Widget memoryGrid(List<RecordData> list) => list.isEmpty
      ? empty('아직 담긴 추억이 없어요', '첫 사진과 이야기를 남겨보세요.', Icons.photo_camera_outlined)
      : grid(
          list
              .map(
                (m) => Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => viewMemory(m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            photo(
                              m['photo'],
                              height: 200,
                              width: double.infinity,
                            ),
                            if (s.memoryDay(
                                  m['date'],
                                  petId: m['petId'],
                                )['anniversary'] ==
                                true)
                              Positioned(
                                top: 12,
                                left: 12,
                                child: tag('♥ 기념일', color: coral),
                              ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['date'], style: AppText.captionMuted),
                              const SizedBox(height: 8),
                              Text(
                                s.memoryDay(
                                  m['date'],
                                  petId: m['petId'],
                                )['title'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                s.memoryDay(
                                      m['date'],
                                      petId: m['petId'],
                                    )['note'] ??
                                    '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.captionMutedComfortable,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
}
