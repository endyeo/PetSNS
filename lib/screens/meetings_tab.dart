import 'package:flutter/material.dart';
import '../store.dart';
import '../design_system.dart';
import '../widgets/common.dart';
import 'home_content.dart';
import 'home_model.dart';
import '../meeting_map.dart';
import '../meeting_location.dart';

class MeetingsTab extends StatelessWidget {
  const MeetingsTab({
    super.key,
    required this.model,
    required this.hostContext,
  });
  final HomeModel model;
  final BuildContext hostContext;
  @override
  Widget build(BuildContext context) =>
      _MeetingsTabContent(hostContext, model).render();
}

class _MeetingsTabContent extends HomeContent {
  _MeetingsTabContent(super.context, super.model);
  Widget render() => showMeetingMap
      ? meetingMapContent(MediaQuery.sizeOf(context).width > 950)
      : meetings();
  Widget meetingMapContent(bool wide) {
    final located = categoryMeetings
        .where((m) => MeetingLocation.fromRecord(m) != null)
        .toList();
    final missing = categoryMeetings.length - located.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 36 : 20, 20, wide ? 36 : 20, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          categorySelector(),
          if (missing > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '위치가 없는 약속 $missing개는 목록에서 확인해 주세요.',
                style: AppText.captionMuted,
              ),
            ),
          Expanded(
            child: PetMeetingMap(
              key: const ValueKey('meetings-map-view'),
              locations: located
                  .map((m) => MeetingLocation.fromRecord(m)!)
                  .toList(),
              markerLabels: located.map((m) => '약속: ${m['title']}').toList(),
              onMarkerTap: (index) => showMeeting(located[index]['id']),
            ),
          ),
        ],
      ),
    );
  }

  Widget meetings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      categorySelector(),
      const Padding(
        padding: EdgeInsets.only(bottom: 20),
        child: Text(
          '정원은 참여하는 보호자 수로 계산해요.',
          style: TextStyle(fontSize: AppText.minimumSize, color: muted),
        ),
      ),
      categoryMeetings.isEmpty
          ? empty(
              '$meetingCategory 약속이 아직 없어요',
              '+ 버튼으로 첫 약속을 만들어 보세요.',
              Icons.explore_outlined,
            )
          : meetingGrid(categoryMeetings),
    ],
  );
  List<RecordData> get categoryMeetings => s
      .rows('meetings')
      .where((m) => meetingCategory == '전체' || m['category'] == meetingCategory)
      .toList();

  Widget categorySelector() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        key: const ValueKey('meeting-categories'),
        segments: [
          for (final category in ['전체', ...petCategories])
            ButtonSegment(value: category, label: Text(category)),
        ],
        selected: {meetingCategory},
        showSelectedIcon: false,
        onSelectionChanged: (selected) =>
            setState(() => meetingCategory = selected.single),
      ),
    ),
  );
}
