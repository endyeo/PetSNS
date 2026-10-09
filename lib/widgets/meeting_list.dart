import 'package:flutter/material.dart';
import '../store.dart';
import '../design_system.dart';
import '../widgets/common.dart';
import '../screens/chat_screen.dart';
import 'meeting_participants.dart';

class MeetingList extends StatelessWidget {
  const MeetingList({
    super.key,
    required this.store,
    required this.meetings,
    required this.onOpen,
    this.chat = false,
  });
  final PetStore store;
  final List<RecordData> meetings;
  final ValueChanged<String> onOpen;
  final bool chat;
  @override
  Widget build(BuildContext context) =>
      _MeetingListContent(context, store, onOpen, chat).render(meetings);
}

class _MeetingListContent {
  _MeetingListContent(this.context, this.s, this.onOpen, this.chat);
  final BuildContext context;
  final PetStore s;
  Widget meetingParticipants(RecordData meeting) =>
      MeetingParticipants(store: s, meeting: meeting);
  final ValueChanged<String> onOpen;
  final bool chat;
  String meetingDistance(RecordData meeting) {
    final distance = meeting['distanceMeters'];
    if (distance is! num || !distance.isFinite || distance < 0) return '거리 미확인';
    return distance < 1000
        ? '${distance.round()}m'
        : '${(distance / 1000).toStringAsFixed(1)}km';
  }

  Widget render(List<RecordData> list) => list.isEmpty
      ? empty('아직 약속이 없어요', '첫 산책 약속을 만들어 보세요.', Icons.explore_outlined)
      : Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: list
                  .map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        key: ValueKey(
                          "${chat ? 'chat' : 'meeting'}-card-${m['id']}",
                        ),
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.cardBorder),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => chat
                              ? Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ChatScreen(store: s, mid: m['id']),
                                  ),
                                )
                              : onOpen(m['id']),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                meetingParticipants(m),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m['title'],
                                        key: ValueKey(
                                          "meeting-title-${m['id']}",
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        key: ValueKey(
                                          "meeting-place-${m['id']}",
                                        ),
                                        children: [
                                          Expanded(
                                            child: Text(
                                              m['place'],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppText.captionMuted,
                                            ),
                                          ),
                                          if (!chat)
                                            Text(
                                              ' / ${meetingDistance(m)}',
                                              style: AppText.captionMuted,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        '${stamp(DateTime.parse(m['at']))} KST',
                                        key: ValueKey(
                                          "meeting-time-${m['id']}",
                                        ),
                                        style: AppText.captionMuted,
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        key: ValueKey(
                                          "meeting-status-${m['id']}",
                                        ),
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${chat && !s.canChat(m) ? '채팅 종료 · 접근 차단' : s.status(m)}${s.joined(m) ? ' · 참여 중' : ''}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppText.captionSuccessBold,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${s.members(m).length} / ${m['capacity']}',
                                            key: ValueKey(
                                              "meeting-count-${m['id']}",
                                            ),
                                            style: AppText.captionMuted,
                                          ),
                                        ],
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
                  )
                  .toList(),
            ),
          ),
        );
}
