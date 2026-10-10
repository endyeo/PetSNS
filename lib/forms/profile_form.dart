part of 'home_forms.dart';

mixin ProfileForm on HomeBindings {
  @override
  Future<void> editOwned(
    String collection, {
    RecordData? existing,
    DateTime? initialDate,
  }) async {
    if (collection == 'memories') {
      await editMemoryPhoto(existing: existing, initialDate: initialDate);
      return;
    }
    final pet = collection == 'pets';
    final name = TextEditingController(
      text: existing?[pet ? 'name' : 'title'] ?? '',
    );
    final note = TextEditingController(
      text: existing?[pet ? 'breed' : 'note'] ?? '',
    );
    String selectedPhoto = existing?['photo'] ?? '';
    DateTime date =
        DateTime.tryParse(existing?[pet ? 'birthday' : 'date'] ?? '') ??
        initialDate ??
        DateTime.now();
    bool anniversary = existing?['anniversary'] ?? false;
    bool saving = false;
    await completedDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(pet ? '우리 가족 프로필' : '오늘의 추억'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: photo(
                      selectedPhoto,
                      height: pet ? 160 : 280,
                      width: double.infinity,
                      fit: pet ? BoxFit.cover : BoxFit.contain,
                    ),
                  ),
                  if (s.usesSupabase) const Text('프로필 사진 업로드는 준비 중입니다.'),
                  if (!s.usesSupabase)
                    TextButton.icon(
                      onPressed: () async {
                        await attempt(context, () async {
                          final file = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1200,
                            imageQuality: 80,
                          );
                          if (file == null) {
                            return;
                          }
                          final bytes = await file.readAsBytes();
                          if (bytes.length > 3 * 1024 * 1024) {
                            throw Exception('사진은 3MB 이하로 선택해 주세요.');
                          }
                          if (context.mounted) {
                            update(
                              () => selectedPhoto =
                                  'data:${file.mimeType ?? 'image/jpeg'};base64,${base64Encode(bytes)}',
                            );
                          }
                        });
                      },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('사진 선택'),
                    ),
                  TextField(
                    controller: name,
                    maxLength: 60,
                    decoration: InputDecoration(labelText: pet ? '이름' : '제목'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: note,
                    maxLength: pet ? 80 : 2000,
                    maxLines: pet ? 1 : 3,
                    decoration: InputDecoration(
                      labelText: pet ? '종류 / 품종' : '오늘의 이야기',
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(
                      '${pet ? '생일' : '날짜'}  ${date.toIso8601String().substring(0, 10)}',
                    ),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(1990),
                        lastDate: pet ? DateTime.now() : korea(s.clock()),
                      );
                      if (d != null) {
                        update(() => date = d);
                      }
                    },
                  ),
                  if (!pet)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('기념일로 기억하기'),
                      value: anniversary,
                      onChanged: (v) => update(() => anniversary = v),
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
                          builder: (c) => AlertDialog(
                            title: const Text('기록을 삭제할까요?'),
                            content: const Text('삭제한 기록은 복구할 수 없습니다.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('취소'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('삭제'),
                              ),
                            ],
                          ),
                        );
                        if (yes == true &&
                            context.mounted &&
                            await attempt(
                              context,
                              () => s.deleteOwned(collection, existing['id']),
                            ) &&
                            dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      },
                child: const Text('삭제'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('닫기'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      update(() => saving = true);
                      final ok = await attempt(context, () async {
                        if (!pet && selectedPhoto.isEmpty) {
                          throw Exception('추억 사진을 선택해 주세요.');
                        }
                        await s.saveOwned(collection, {
                          'id': existing?['id'],
                          pet ? 'name' : 'title': name.text.trim(),
                          pet ? 'breed' : 'note': note.text.trim(),
                          pet ? 'birthday' : 'date': date
                              .toIso8601String()
                              .substring(0, 10),
                          'photo': selectedPhoto,
                          'anniversary': anniversary,
                        });
                      });
                      if (dialogContext.mounted) {
                        if (ok) {
                          if (!pet && mounted) {
                            setState(() {
                              memoryDate = DateUtils.dateOnly(date);
                              memoryMonth = DateTime(date.year, date.month);
                            });
                          }
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
}
