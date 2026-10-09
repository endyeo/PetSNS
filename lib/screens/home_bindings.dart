import 'package:flutter/material.dart';
import '../store.dart';
import '../design_system.dart';
import 'home_model.dart';
import '../widgets/meeting_participants.dart';
import '../widgets/meeting_participants.dart' as participants;

abstract class HomeBindings {
  HomeBindings(this.context, this.model);
  final BuildContext context;
  final HomeModel model;
  PetStore get s => model.s;
  bool get mounted => context.mounted;
  void setState(VoidCallback action) {
    if (mounted) model.update(action);
  }

  int get tab => model.tab;
  set tab(int value) => model.tab = value;
  String get filter => model.filter;
  set filter(String value) => model.filter = value;
  bool get editingMemories => model.editingMemories;
  set editingMemories(bool value) => model.editingMemories = value;
  bool get showMeetingMap => model.showMeetingMap;
  set showMeetingMap(bool value) => model.showMeetingMap = value;
  String get meetingCategory => model.meetingCategory;
  set meetingCategory(String value) => model.meetingCategory = value;
  int get chatSection => model.chatSection;
  set chatSection(int value) => model.chatSection = value;
  String? get selectedPetId => model.selectedPetId;
  set selectedPetId(String? value) => model.selectedPetId = value;
  DateTime get memoryDate => model.memoryDate;
  set memoryDate(DateTime value) => model.memoryDate = value;
  DateTime? get homeDate => model.homeDate;
  set homeDate(DateTime? value) => model.homeDate = value;
  DateTime get memoryMonth => model.memoryMonth;
  set memoryMonth(DateTime value) => model.memoryMonth = value;
  List<RecordData> owned(String key) => model.owned(key);
  RecordData? get selectedPet => model.selectedPet;
  List<RecordData> get selectedPetMemories => model.selectedPetMemories;
  DateTime? get selectedOrigin => model.selectedOrigin;
  DateTime? get selectedFirstPhoto => model.selectedFirstPhoto;
  void selectPet(String id) => model.selectPet(id);
  String memoryDayKey(DateTime date) => dayKey(date);
  Future<void> editOwned(
    String collection, {
    RecordData? existing,
    DateTime? initialDate,
  });
  Future<void> editMemoryPhoto({
    RecordData? existing,
    DateTime? initialDate,
    String? petId,
  });
  Future<void> setupMemoryOrigin();
  Future<void> editMemoryDay();
  Future<void> createMeeting();
  Future<void> createPost();
  Future<void> showMeeting(String mid);
  Widget title(String title, String sub, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 24,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(sub, style: AppText.captionMuted),
          ],
        ),
        ?action,
      ],
    ),
  );
  Widget section(String name, int target) => Padding(
    padding: const EdgeInsets.only(top: 30, bottom: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => tab = target),
          child: const Text(
            '모두 보기  →',
            style: TextStyle(fontSize: AppText.minimumSize, color: muted),
          ),
        ),
      ],
    ),
  );
  Widget grid(List<Widget> children, {double itemWidth = 270}) => LayoutBuilder(
    builder: (context, c) {
      final count = (c.maxWidth / itemWidth).floor().clamp(1, 3);
      final width = (c.maxWidth - (count - 1) * 18) / count;
      return Wrap(
        spacing: 18,
        runSpacing: 18,
        children: children
            .map((w) => SizedBox(width: width, child: w))
            .toList(),
      );
    },
  );
  Widget meetingPetChoice(
    List<String> selected,
    ValueChanged<List<String>> onChanged,
  ) => MeetingPetChoice(
    pets: owned('pets'),
    selected: selected,
    onChanged: onChanged,
  );
  Widget meetingParticipants(RecordData meeting) =>
      MeetingParticipants(store: s, meeting: meeting);
  Widget participantAvatar(RecordData pet, {double size = 48}) =>
      participants.participantAvatar(pet, size: size);
}
