part of 'home_forms.dart';

mixin MemoryForms on HomeBindings {
  @override
  Future<void> setupMemoryOrigin() async {
    if (selectedPet == null) {
      await editOwned('pets');
      return;
    }
    final petId = selectedPet!['id'] as String;
    var type = selectedPet?['memoryOriginType'] as String? ?? 'firstMeeting';
    var date =
        selectedOrigin ??
        selectedFirstPhoto ??
        DateUtils.dateOnly(korea(s.clock()));
    var saving = false;
    await completedDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Day 0 시작 기준'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '시작한 날이 Day 0이고, 다음 날은 Day 1이에요.',
                  style: TextStyle(fontSize: 13, height: 1.7),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const ValueKey('memory-origin-type'),
                  initialValue: type,
                  decoration: const InputDecoration(labelText: '시작 기준'),
                  items: const [
                    DropdownMenuItem(
                      value: 'firstMeeting',
                      child: Text('반려동물과 첫 만남'),
                    ),
                    DropdownMenuItem(value: 'firstPhoto', child: Text('첫 사진')),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => update(() {
                          type = value!;
                          if (type == 'firstPhoto') {
                            date = selectedFirstPhoto ?? date;
                          }
                        }),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Day 0 · ${memoryDayKey(date)}'),
                  subtitle: Text(
                    type == 'firstPhoto' && selectedFirstPhoto != null
                        ? '저장된 가장 오래된 사진 날짜를 사용해요.'
                        : '날짜를 눌러 시작일을 선택해 주세요.',
                  ),
                  trailing: const Icon(Icons.event_outlined),
                  onTap:
                      saving ||
                          (type == 'firstPhoto' && selectedFirstPhoto != null)
                      ? null
                      : () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(1990),
                            lastDate: DateUtils.dateOnly(korea(s.clock())),
                          );
                          if (selected != null) update(() => date = selected);
                        },
                ),
                if (type == 'firstPhoto')
                  const Text(
                    '더 오래된 사진을 추가하면 Day 0도 그 날짜로 바뀝니다.',
                    style: TextStyle(
                      fontSize: AppText.minimumSize,
                      color: muted,
                      height: 1.6,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('닫기'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      update(() => saving = true);
                      final ok = await attempt(
                        context,
                        () => s.setMemoryOrigin(type, date, petId: petId),
                      );
                      if (dialogContext.mounted) {
                        if (ok) {
                          setState(() {
                            if (memoryDate.isBefore(selectedOrigin!)) {
                              memoryDate = selectedOrigin!;
                            }
                          });
                          Navigator.pop(dialogContext);
                        } else {
                          update(() => saving = false);
                        }
                      }
                    },
              child: const Text('설정 완료'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Future<void> editMemoryDay() async {
    if (selectedPet == null) {
      await editOwned('pets');
      return;
    }
    final petId = selectedPet!['id'] as String;
    final date = memoryDayKey(memoryDate);
    final day = s.memoryDay(date, petId: petId);
    final name = TextEditingController(text: day['title']);
    final note = TextEditingController(text: day['note']);
    var anniversary = day['anniversary'] == true;
    var saving = false;
    await completedDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('하루 기록'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(date),
                  const SizedBox(height: 16),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Day 제목'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Day 메모'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('기념일로 기억하기'),
                    value: anniversary,
                    onChanged: (value) => update(() => anniversary = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('닫기'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      update(() => saving = true);
                      final ok = await attempt(
                        context,
                        () => s.saveMemoryDay(
                          date,
                          name.text,
                          note.text,
                          anniversary,
                          petId: petId,
                        ),
                      );
                      if (dialogContext.mounted) {
                        if (ok) {
                          setState(() {});
                          Navigator.pop(dialogContext);
                        } else {
                          update(() => saving = false);
                        }
                      }
                    },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    note.dispose();
  }

  @override
  Future<void> editMemoryPhoto({
    RecordData? existing,
    DateTime? initialDate,
    String? petId,
  }) async {
    petId ??= existing?['petId'] ?? selectedPet?['id'];
    if (petId == null) {
      await editOwned('pets');
      return;
    }
    final profile = s.memoryProfile(petId: petId);
    var date =
        DateTime.tryParse(existing?['date'] ?? '') ??
        initialDate ??
        DateUtils.dateOnly(korea(s.clock()));
    var photos = <String>[if (existing != null) existing['photo'] as String];
    var saving = false;
    await completedDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(existing == null ? '추억 기록' : '사진 수정'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${profile['name']}의 추억",
                    key: const ValueKey('memory-editor-pet'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: (MediaQuery.sizeOf(context).height * .38).clamp(
                      160.0,
                      340.0,
                    ),
                    width: double.infinity,
                    color: AppColors.photoSurface,
                    child: photos.isEmpty
                        ? const Center(
                            child: Icon(
                              Icons.add_photo_alternate_outlined,
                              color: muted,
                              size: 44,
                            ),
                          )
                        : PageView(
                            children: photos
                                .map(
                                  (source) => photo(
                                    source,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.contain,
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '사진 ${photos.length}장${photos.length > 1 ? ' · 좌우로 밀어 전체 사진 보기' : ''}',
                    style: AppText.captionMuted,
                  ),
                  TextButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            await attempt(context, () async {
                              final picker = ImagePicker();
                              final files = existing == null
                                  ? await picker.pickMultiImage(
                                      maxWidth: 1200,
                                      imageQuality: 80,
                                    )
                                  : <XFile>[
                                      if (await picker.pickImage(
                                            source: ImageSource.gallery,
                                            maxWidth: 1200,
                                            imageQuality: 80,
                                          )
                                          case final XFile file)
                                        file,
                                    ];
                              final sources = <String>[];
                              for (final file in files) {
                                final bytes = await file.readAsBytes();
                                if (bytes.length > 3 * 1024 * 1024) {
                                  throw Exception('사진 한 장은 3MB 이하로 선택해 주세요.');
                                }
                                sources.add(
                                  'data:${file.mimeType ?? 'image/jpeg'};base64,${base64Encode(bytes)}',
                                );
                              }
                              if (sources.isNotEmpty && context.mounted) {
                                update(() => photos = sources);
                              }
                            });
                          },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(existing == null ? '사진 선택' : '사진 변경'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('날짜  ${memoryDayKey(date)}'),
                    leading: const Icon(Icons.event_outlined),
                    onTap: saving
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(1990),
                              lastDate: DateUtils.dateOnly(korea(s.clock())),
                            );
                            if (picked != null) update(() => date = picked);
                          },
                  ),
                  const Text(
                    '제목과 메모는 M 화면에서 하루에 하나씩 기록해요.',
                    style: TextStyle(
                      fontSize: AppText.minimumSize,
                      color: muted,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: saving
                    ? null
                    : () async {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('이 사진을 삭제할까요?'),
                            content: const Text(
                              '삭제한 사진은 복구할 수 없어요. Day 제목과 메모는 보관됩니다.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('취소'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('삭제'),
                              ),
                            ],
                          ),
                        );
                        if (yes != true || !context.mounted) return;
                        update(() => saving = true);
                        final ok = await attempt(
                          context,
                          () => s.deleteOwned('memories', existing['id']),
                        );
                        if (dialogContext.mounted) {
                          if (ok) {
                            setState(() {});
                            Navigator.pop(dialogContext);
                          } else {
                            update(() => saving = false);
                          }
                        }
                      },
                child: const Text('삭제'),
              ),
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('닫기'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      update(() => saving = true);
                      final ok = await attempt(
                        context,
                        () => s.saveMemoryPhotos(
                          memoryDayKey(date),
                          photos,
                          existingId: existing?['id'],
                          petId: petId,
                        ),
                      );
                      if (dialogContext.mounted) {
                        if (ok) {
                          setState(() => memoryDate = date);
                          Navigator.pop(dialogContext);
                        } else {
                          update(() => saving = false);
                        }
                      }
                    },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}
