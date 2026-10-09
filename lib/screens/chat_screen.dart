import 'package:flutter/material.dart';
import '../store.dart';
import '../design_system.dart';
import '../widgets/common.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../widgets/policy_timer.dart';

class ChatScreen extends StatefulWidget {
  final PetStore store;
  final String mid;
  final bool group;
  const ChatScreen({
    super.key,
    required this.store,
    required this.mid,
    this.group = false,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver, PolicyTimer<ChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  String? attachment;
  bool picking = false;
  PetStore get s => widget.store;
  @override
  void initState() {
    super.initState();
    startPolicyTimer();
  }

  @override
  void dispose() {
    stopPolicyTimer();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  PetStore get timeStore => widget.store;
  @override
  Iterable<DateTime> get policyDates => widget.group
      ? const []
      : [chatClose(DateTime.parse(widget.store.meeting(widget.mid)['at']))];
  void refresh() => refreshPolicy();

  Future<void> send() async {
    if (s.busy || picking) return;
    if (await attempt(
      context,
      () => s.send(
        widget.mid,
        input.text,
        photo: attachment,
        group: widget.group,
      ),
    )) {
      if (!mounted) return;
      input.clear();
      setState(() => attachment = null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) {
          scroll.animateTo(
            scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> pickPhoto() async {
    setState(() => picking = true);
    await attempt(context, () async {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 3 * 1024 * 1024) {
        throw Exception('사진 한 장은 3MB 이하로 선택해 주세요.');
      }
      if (!mounted || !s.canChat(s.room(widget.mid, group: widget.group))) {
        return;
      }
      final extension = file.name.split('.').last.toLowerCase();
      final mime =
          file.mimeType ??
          switch (extension) {
            'png' => 'image/png',
            'gif' => 'image/gif',
            'webp' => 'image/webp',
            _ => 'image/jpeg',
          };
      setState(() => attachment = 'data:$mime;base64,${base64Encode(bytes)}');
    });
    if (mounted) setState(() => picking = false);
  }

  Future<void> menu(String value) async {
    if (value != 'leave') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomDetails(
            store: s,
            mid: widget.mid,
            group: widget.group,
            mode: value,
          ),
        ),
      );
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(widget.group ? '모임에서 나갈까요?' : '채팅방에서 나갈까요?'),
        content: Text(
          widget.group
              ? '모임 가입이 취소되고 대화와 사진에 접근할 수 없습니다. 다시 가입하면 새 대화부터 볼 수 있어요.'
              : '약속 참여도 취소되고 채팅방 접근이 즉시 차단됩니다. 다시 참여하면 새 대화와 사진부터 볼 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('돌아가기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await attempt(context, () => s.leave(widget.mid, group: widget.group));
    }
  }

  Widget message(RecordData msg, double maxWidth) {
    final mine = msg['owner'] == s.user;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth > 420 ? 420 : maxWidth,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
                child: Text(
                  msg['name'],
                  key: ValueKey("chat-sender-${msg['id']}"),
                  style: AppText.captionMuted,
                ),
              ),
              Container(
                key: ValueKey("chat-bubble-${msg['id']}"),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: mine ? AppColors.ownMessage : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg['photo'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatRoomDetails(
                                store: s,
                                mid: widget.mid,
                                group: widget.group,
                                mode: 'photo',
                                messageId: msg['id'],
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: photo(msg['photo'], width: 220, height: 165),
                          ),
                        ),
                      ),
                    if ((msg['body'] as String).isNotEmpty) Text(msg['body']),
                    const SizedBox(height: 3),
                    Text(
                      stamp(DateTime.parse(msg['at'])),
                      style: AppText.captionMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = s.room(widget.mid, group: widget.group);
    final allowed = s.canChat(m);
    final messages = s.messages(widget.mid, group: widget.group);
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: Text(m['title'], style: const TextStyle(fontSize: 18)),
        actions: [
          if (s.joined(m))
            PopupMenuButton<String>(
              tooltip: '채팅방 메뉴',
              onSelected: menu,
              icon: const Icon(Icons.menu_rounded),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'members',
                  enabled: allowed,
                  child: const ListTile(
                    leading: Icon(Icons.people_outline),
                    title: Text('멤버'),
                  ),
                ),
                PopupMenuItem(
                  value: 'photos',
                  enabled: allowed,
                  child: const ListTile(
                    leading: Icon(Icons.photo_library_outlined),
                    title: Text('사진'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'leave',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('나가기'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: notice(
                  widget.group
                      ? "${m['category']} · ${m['place']} · 멤버 ${s.members(m).length}명\n가입 이후의 대화와 사진을 나눠보세요."
                      : '채팅 종료 예정: ${stamp(chatClose(DateTime.parse(m['at'])))} KST\n약속 다음 날까지 이용할 수 있어요. 이번 참여 이후의 대화와 사진만 표시됩니다.',
                ),
              ),
              if (!allowed)
                Expanded(
                  child: Center(
                    child: empty(
                      m['canceled'] == true
                          ? '취소된 약속입니다'
                          : !s.joined(m)
                          ? (widget.group ? '모임에서 나갔습니다' : '참여가 취소되었습니다')
                          : '채팅이 종료되었습니다',
                      '현재 이 채팅방의 메시지를 볼 수 없습니다.',
                      Icons.lock_outline,
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: empty(
                            '첫 인사를 나눠보세요',
                            '이번 참여 이후의 대화가 여기에 쌓여요.',
                            Icons.waving_hand_outlined,
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) => ListView.builder(
                            controller: scroll,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: messages.length,
                            itemBuilder: (_, i) => message(
                              messages[i],
                              (constraints.maxWidth - 32) * .8,
                            ),
                          ),
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (attachment != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 44, bottom: 8),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: photo(
                                    attachment,
                                    width: 64,
                                    height: 64,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    '전송할 사진',
                                    style: TextStyle(color: muted),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '첨부 사진 제거',
                                  onPressed: s.busy
                                      ? null
                                      : () => setState(() => attachment = null),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            IconButton(
                              tooltip: '사진 추가',
                              onPressed: s.busy || picking ? null : pickPhoto,
                              icon: picking
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.add),
                            ),
                            Expanded(
                              child: TextField(
                                key: const ValueKey('chat-input'),
                                controller: input,
                                enabled: !s.busy,
                                maxLength: 1000,
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => send(),
                                decoration: InputDecoration(
                                  hintText: '메시지를 입력하세요',
                                  counterText: '',
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              tooltip: '메시지 보내기',
                              onPressed: s.busy || picking ? null : send,
                              icon: const Icon(Icons.arrow_upward),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Every view rechecks access, including a photo left open across the cutoff.
class ChatRoomDetails extends StatefulWidget {
  const ChatRoomDetails({
    super.key,
    required this.store,
    required this.mid,
    required this.mode,
    this.messageId,
    this.group = false,
  });
  final PetStore store;
  final String mid, mode;
  final bool group;
  final String? messageId;
  @override
  State<ChatRoomDetails> createState() => _ChatRoomDetailsState();
}

class _ChatRoomDetailsState extends State<ChatRoomDetails>
    with WidgetsBindingObserver, PolicyTimer<ChatRoomDetails> {
  @override
  void initState() {
    super.initState();
    startPolicyTimer();
  }

  @override
  PetStore get timeStore => widget.store;
  @override
  Iterable<DateTime> get policyDates => widget.group
      ? const []
      : [chatClose(DateTime.parse(widget.store.meeting(widget.mid)['at']))];
  void refresh() => refreshPolicy();

  @override
  void dispose() {
    stopPolicyTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final allowed = s.canChat(s.room(widget.mid, group: widget.group));
    final photos = s.chatPhotos(widget.mid, group: widget.group);
    final selected = photos.where((p) => p['id'] == widget.messageId);
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: Text(
          widget.mode == 'members'
              ? '채팅방 멤버'
              : widget.mode == 'photo'
              ? '채팅 사진'
              : '채팅방 사진',
        ),
      ),
      body: !allowed
          ? empty('채팅방 접근이 차단되었습니다', '멤버와 사진을 볼 수 없습니다.', Icons.lock_outline)
          : widget.mode == 'members'
          ? ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '참여 중인 보호자 ${s.chatMembers(widget.mid, group: widget.group).length}명',
                  ),
                ),
                ...s.chatMembers(widget.mid, group: widget.group).map((member) {
                  final pets = (member['pets'] as List).cast<RecordData>();
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text((member['name'] as String).characters.first),
                    ),
                    title: Text(
                      '${member['name']}${member['id'] == s.user ? ' · 나' : ''}',
                    ),
                    subtitle: Text(
                      pets.isEmpty
                          ? '참여 반려동물 없음'
                          : pets.map((p) => p['name']).join(' · '),
                    ),
                  );
                }),
              ],
            )
          : widget.mode == 'photo'
          ? selected.isEmpty
                ? empty(
                    '사진을 볼 수 없습니다',
                    '현재 참여 이후의 사진만 볼 수 있어요.',
                    Icons.lock_outline,
                  )
                : Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: InteractiveViewer(
                            child: photo(
                              selected.first['photo'],
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '${selected.first['name']} · ${stamp(DateTime.parse(selected.first['at']))}',
                        ),
                      ),
                    ],
                  )
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '이번 참여 이후 채팅에 올라온 사진만 표시됩니다.',
                    style: TextStyle(color: muted),
                  ),
                ),
                Expanded(
                  child: photos.isEmpty
                      ? empty(
                          '아직 사진이 없어요',
                          '+ 버튼으로 채팅에 사진을 올려보세요.',
                          Icons.photo_library_outlined,
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 180,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: photos.length,
                          itemBuilder: (_, i) => InkWell(
                            key: ValueKey("chat-gallery-${photos[i]['id']}"),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatRoomDetails(
                                  store: s,
                                  mid: widget.mid,
                                  group: widget.group,
                                  mode: 'photo',
                                  messageId: photos[i]['id'],
                                ),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: photo(photos[i]['photo']),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
