import 'package:flutter/material.dart';
import '../store.dart';
import '../design_system.dart';
import '../widgets/common.dart';
import 'home_content.dart';
import 'home_model.dart';
import 'chat_screen.dart';

class CommunityTab extends StatelessWidget {
  const CommunityTab({
    super.key,
    required this.model,
    required this.hostContext,
  });
  final HomeModel model;
  final BuildContext hostContext;
  @override
  Widget build(BuildContext context) =>
      _CommunityTabContent(hostContext, model).render();
}

class _CommunityTabContent extends HomeContent {
  _CommunityTabContent(super.context, super.model);
  Widget render() => chats();
  Widget chats() {
    final list = s.rows('meetings').where(s.joined).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: DefaultTabController(
            length: 3,
            initialIndex: chatSection,
            child: TabBar(
              key: const ValueKey('chat-room-tabs'),
              labelColor: coral,
              unselectedLabelColor: muted,
              indicatorColor: coral,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(text: '게시글'),
                Tab(text: '모임방'),
                Tab(text: '약속방'),
              ],
              onTap: (index) => setState(() => chatSection = index),
            ),
          ),
        ),
        if (chatSection == 0)
          posts()
        else if (chatSection == 1)
          groupRooms()
        else if (list.isEmpty)
          empty(
            '아직 참여한 채팅이 없어요',
            '약속에 참여하면 채팅방이 열립니다.',
            Icons.chat_bubble_outline,
          ),
        if (chatSection == 2 && list.isNotEmpty) meetingGrid(list, chat: true),
      ],
    );
  }

  Widget posts() => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '반려 생활 이야기를 나눠보세요.',
                  style: TextStyle(fontSize: AppText.minimumSize, color: muted),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('post-create'),
                onPressed: createPost,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('글쓰기'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (s.rows('posts').isEmpty)
            empty('아직 게시글이 없어요', '첫 이야기를 남겨보세요.', Icons.article_outlined),
          for (final post in s.rows('posts'))
            Card(
              key: ValueKey("post-card-${post['id']}"),
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.cardBorder),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(post['title']),
                    content: SizedBox(
                      width: 460,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            tag(post['category']),
                            const SizedBox(height: 12),
                            Text(
                              "${post['name']} · ${stamp(DateTime.parse(post['at']))}",
                              style: AppText.captionMuted,
                            ),
                            const SizedBox(height: 16),
                            SelectableText(post['body']),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('닫기'),
                      ),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tag(post['category']),
                      const SizedBox(height: 10),
                      Text(
                        post['title'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        post['body'],
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "${post['name']} · ${stamp(DateTime.parse(post['at']))}",
                        style: AppText.captionMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget groupRooms() {
    final groups = s
        .rows('groups')
        .where((g) => g['canceled'] != true)
        .toList();
    final joined = groups.where(s.joined).toList();
    final discover = groups.where((g) => !s.joined(g)).toList();
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (joined.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  '가입한 모임',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              ...joined.map(groupCard),
              const SizedBox(height: 16),
            ],
            if (discover.isNotEmpty) ...[
              Text(
                joined.isEmpty ? '함께할 모임을 찾아보세요' : '둘러볼 모임',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                '관심 있는 모임의 소개를 보고 가입해 보세요.',
                style: TextStyle(fontSize: AppText.minimumSize, color: muted),
              ),
              const SizedBox(height: 12),
              ...discover.map(groupCard),
            ],
            if (groups.isEmpty)
              empty(
                '아직 모임이 없어요',
                '새로운 모임이 생기면 여기에 표시됩니다.',
                Icons.groups_outlined,
              ),
          ],
        ),
      ),
    );
  }

  Widget groupCard(RecordData group) => Card(
    key: ValueKey("group-card-${group['id']}"),
    margin: const EdgeInsets.only(bottom: 10),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.cardBorder),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => openGroup(group),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.selected,
                  child: Icon(Icons.groups_outlined, color: coral),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    group['title'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                tag(group['category']),
              ],
            ),
            const SizedBox(height: 10),
            Text(group['note'], style: AppText.captionMuted),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${group['place']} · 멤버 ${s.members(group).length}명",
                    style: AppText.captionMuted,
                  ),
                ),
                TextButton(
                  onPressed: () => openGroup(group),
                  child: Text(s.joined(group) ? '모임방 열기' : '가입하기'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> openGroup(RecordData group) async {
    if (!s.joined(group)) {
      final join = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(group['title']),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${group['category']} · ${group['place']} · 멤버 ${s.members(group).length}명",
              ),
              const SizedBox(height: 16),
              Text(group['note']),
              const SizedBox(height: 16),
              const Text(
                '가입하면 모임방에서 대화와 사진을 나눌 수 있어요. 가입 이후의 대화부터 볼 수 있습니다.',
                style: TextStyle(fontSize: AppText.minimumSize, color: muted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('닫기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('가입하고 모임방 열기'),
            ),
          ],
        ),
      );
      if (join != true || !context.mounted) return;
      if (!await attempt(context, () => s.joinGroup(group['id']))) return;
      if (!context.mounted) return;
      setState(() {});
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(store: s, mid: group['id'], group: true),
      ),
    );
    if (mounted) setState(() {});
  }
}
