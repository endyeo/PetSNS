part of 'home_forms.dart';

mixin MeetingForms on HomeBindings {
  @override
  Future<void> showMeeting(String mid) async {
    var participatingPets = <String>[
      if (selectedPet != null) selectedPet!['id'] as String,
    ];
    await showDialog(
      context: context,
      builder: (dialogContext) => PolicyBuilder(
        store: s,
        dates: () {
          final at = DateTime.parse(s.meeting(mid)['at']);
          return [meetingDeadline(at), at.toUtc(), chatClose(at)];
        },
        builder: (_) => StatefulBuilder(
          builder: (context, update) {
            final m = s.meeting(mid);
            return AlertDialog(
              title: Text(m['title']),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      tag(s.status(m)),
                      const SizedBox(height: 18),
                      Text(m['note']),
                      const SizedBox(height: 18),
                      Text(
                        '장소  ${m['place']}\n약속  ${stamp(DateTime.parse(m['at']))} KST\n참여 마감  ${stamp(meetingDeadline(DateTime.parse(m['at'])))} KST (시작 6시간 전)\n정원  ${s.members(m).length} / ${m['capacity']} 계정',
                        style: const TextStyle(height: 2, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      notice(
                        '채팅은 ${stamp(chatClose(DateTime.parse(m['at'])))} KST에 종료됩니다.\n탈퇴하면 참여가 취소되고 채팅 접근이 차단됩니다. 재참여 시 새 메시지부터 볼 수 있어요.',
                      ),
                      if (s.meetingPets(m).isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          '함께하는 반려동물',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: s
                              .meetingPets(m)
                              .map(
                                (pet) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    participantAvatar(pet),
                                    const SizedBox(height: 4),
                                    Text(pet['name'], style: AppText.caption),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      if (!s.joined(m)) ...[
                        const SizedBox(height: 16),
                        if (owned('pets').isNotEmpty)
                          meetingPetChoice(
                            participatingPets,
                            (ids) => update(() => participatingPets = ids),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('닫기'),
                ),
                if (s.joined(m)) ...[
                  TextButton(
                    onPressed: () async {
                      if (await attempt(context, () => s.leave(mid)) &&
                          dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
                    child: const Text('참여 취소'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      Navigator.push(
                        this.context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(store: s, mid: mid),
                        ),
                      );
                    },
                    child: const Text('채팅 열기'),
                  ),
                ] else
                  FilledButton(
                    onPressed: s.status(m) == '모집 중'
                        ? () async {
                            if (await attempt(
                                  context,
                                  () => s.join(mid, petIds: participatingPets),
                                ) &&
                                dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          }
                        : null,
                    child: const Text('참여하기'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Future<void> createMeeting() async {
    final title = TextEditingController(), note = TextEditingController();
    MeetingLocation? chosenPlace;
    int capacity = 6;
    String category = meetingCategory == '전체'
        ? petCategories.first
        : meetingCategory;
    var participatingPets = <String>[
      if (selectedPet != null) selectedPet!['id'] as String,
    ];
    DateTime at = s.clock().toUtc().add(const Duration(days: 2));
    bool saving = false;
    Future<DateTime?> pick(BuildContext context, DateTime initial) async {
      final k = korea(initial);
      final now = korea(s.clock());
      final d = await showDatePicker(
        context: context,
        initialDate: DateTime(k.year, k.month, k.day),
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: DateTime(now.year + 2),
      );
      if (d == null || !context.mounted) {
        return null;
      }
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: k.hour, minute: k.minute),
      );
      return t == null
          ? null
          : DateTime.utc(
              d.year,
              d.month,
              d.day,
              t.hour,
              t.minute,
            ).subtract(const Duration(hours: 9));
    }

    await completedDialog(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('새로운 약속 만들기'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('meeting-category-input'),
                      initialValue: category,
                      decoration: const InputDecoration(labelText: '약속 카테고리'),
                      items: [
                        for (final name in petCategories)
                          DropdownMenuItem(value: name, child: Text(name)),
                      ],
                      onChanged: saving
                          ? null
                          : (value) => update(() => category = value!),
                    ),
                  ),
                  if (owned('pets').isNotEmpty)
                    meetingPetChoice(
                      participatingPets,
                      (ids) => update(() => participatingPets = ids),
                    ),
                  TextField(
                    controller: title,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: '약속 이름'),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey('meeting-place-picker'),
                      icon: const Icon(Icons.map_outlined),
                      label: Text(
                        chosenPlace?.name ?? '지도에서 만날 장소 선택',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final chosen =
                                  await Navigator.push<MeetingLocation>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MeetingPlacePicker(
                                        initial: chosenPlace,
                                      ),
                                    ),
                                  );
                              if (chosen != null && dc.mounted) {
                                update(() => chosenPlace = chosen);
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: note,
                    maxLength: 1000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '함께할 이야기 / 준비물',
                    ),
                  ),
                  ListTile(
                    title: const Text('약속 시간 · 한국 시간'),
                    subtitle: Text(stamp(at)),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () async {
                      final d = await pick(context, at);
                      if (d != null) {
                        update(() => at = d);
                      }
                    },
                  ),
                  Counter(
                    label: '정원 (보호자 수)',
                    value: capacity,
                    min: 2,
                    max: 50,
                    onChanged: (v) => capacity = v,
                  ),
                  const SizedBox(height: 16),
                  notice(
                    '참여는 약속 시작 6시간 전에 마감돼요.\n자동 마감: ${stamp(meetingDeadline(at))} KST\n개설자도 자동으로 참여하며 정원에 포함됩니다.\n채팅 종료: ${stamp(chatClose(at))} KST',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dc),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: saving || chosenPlace == null
                  ? null
                  : () async {
                      update(() => saving = true);
                      final ok = await attempt(
                        context,
                        () => s.createMeeting(
                          title.text,
                          chosenPlace!,
                          note.text,
                          at,
                          capacity,
                          petIds: participatingPets,
                          category: category,
                        ),
                      );
                      if (dc.mounted) {
                        if (ok) {
                          setState(() => meetingCategory = category);
                          Navigator.pop(dc);
                        } else {
                          update(() => saving = false);
                        }
                      }
                    },
              child: const Text('약속 만들기'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    note.dispose();
  }
}
