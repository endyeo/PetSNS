import 'package:flutter/material.dart';
import '../store.dart';
import '../design_system.dart';
import '../widgets/common.dart';
import 'home_model.dart';
import '../forms/home_forms.dart';
import '../widgets/policy_timer.dart';
import 'dashboard_tab.dart';
import 'memory_tab.dart';
import 'meetings_tab.dart';
import 'community_tab.dart';
import 'pets_tab.dart';

class Home extends StatefulWidget {
  final PetStore store;
  const Home({super.key, required this.store});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home>
    with WidgetsBindingObserver, PolicyTimer<Home> {
  late final HomeModel model;
  PetStore get s => widget.store;
  int get tab => model.tab;
  bool get showMeetingMap => model.showMeetingMap;
  final labels = ['우리의 하루', '추억 보관함', '함께하는 약속', '채팅', '반려동물'];
  final icons = [
    Icons.grid_view_rounded,
    Icons.photo_library_outlined,
    Icons.explore_outlined,
    Icons.chat_bubble_outline_rounded,
    Icons.pets_outlined,
  ];
  @override
  void initState() {
    super.initState();
    model = HomeModel(s);
    startPolicyTimer();
  }

  @override
  PetStore get timeStore => s;
  @override
  void dispose() {
    stopPolicyTimer();
    model.dispose();
    super.dispose();
  }

  void navigate(int index) => model.update(() => model.tab = index);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => shell(context),
  );

  Widget shell(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 950;
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: tab == 2
          ? SizedBox(
              width: MediaQuery.sizeOf(context).width - (wide ? 258 : 32),
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Material(
                      key: const ValueKey('meeting-view-switch'),
                      elevation: 6,
                      animationDuration: Duration.zero,
                      borderRadius: BorderRadius.circular(24),
                      color: AppColors.surface,
                      child: SegmentedButton<bool>(
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          animationDuration: Duration.zero,
                          splashFactory: NoSplash.splashFactory,
                          overlayColor: AppColors.transparent,
                        ),
                        segments: const [
                          ButtonSegment(
                            value: false,
                            icon: Icon(Icons.list_alt),
                            label: Text('목록'),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: Icon(Icons.map_outlined),
                            label: Text('지도'),
                          ),
                        ],
                        selected: {showMeetingMap},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) => model.update(
                          () => model.showMeetingMap = selection.single,
                        ),
                      ),
                    ),
                  ),
                  if (!showMeetingMap)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          splashFactory: NoSplash.splashFactory,
                          highlightColor: AppColors.transparent,
                          hoverColor: AppColors.transparent,
                        ),
                        child: FloatingActionButton.small(
                          key: const ValueKey('meeting-create-fab'),
                          tooltip: '약속 만들기',
                          shape: const CircleBorder(),
                          backgroundColor: coral,
                          foregroundColor: AppColors.surface,
                          heroTag: null,
                          elevation: 6,
                          focusElevation: 6,
                          hoverElevation: 6,
                          highlightElevation: 6,
                          onPressed: () =>
                              HomeForms(context, model).createMeeting(),
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ),
                ],
              ),
            )
          : null,
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Container(
                width: 226,
                decoration: const BoxDecoration(
                  color: AppColors.sidebar,
                  border: Border(
                    right: BorderSide(color: AppColors.sidebarBorder),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 38, 20, 8),
                      child: Row(
                        children: [
                          Icon(Icons.pets, color: coral, size: 30),
                          SizedBox(width: 10),
                          Text(
                            'PetSNS',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 29, bottom: 44),
                      child: Text(
                        '함께 쌓는 작은 행복',
                        style: TextStyle(
                          fontSize: AppText.minimumSize,
                          color: muted,
                        ),
                      ),
                    ),
                    ...List.generate(
                      5,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          selected: tab == i,
                          selectedTileColor: AppColors.selected,
                          selectedColor: coral,
                          leading: Icon(icons[i], size: 21),
                          title: Text(
                            labels[i],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () => navigate(i),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accentSurface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.wb_sunny_outlined,
                            color: AppColors.accent,
                          ),
                          SizedBox(height: 12),
                          Text('산책하기 좋은 하루', style: AppText.captionBold),
                          SizedBox(height: 5),
                          Text(
                            '오늘도 작은 행복을\n하나 더 쌓아볼까요?',
                            style: TextStyle(
                              fontSize: AppText.minimumSize,
                              color: muted,
                              height: 1.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.avatar,
                        child: Icon(
                          Icons.person_outline,
                          color: AppColors.surface,
                        ),
                      ),
                      title: Text(
                        '${s.account?['name'] ?? '보호자'} 님',
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        s.user == 'test' ? '테스트 이용 중' : '나의 계정',
                        style: AppText.captionMuted,
                      ),
                      trailing: IconButton(
                        tooltip: '로그아웃',
                        onPressed: () => attempt(context, s.logout),
                        icon: const Icon(Icons.logout, size: 18),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    key: const ValueKey('app-header'),
                    height: 78,
                    padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 20),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.divider),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            wide ? labels[tab] : 'PetSNS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: wide ? 14 : 23,
                              fontWeight: FontWeight.w800,
                              color: wide ? ink : coral,
                            ),
                          ),
                        ),
                        tag('LOCAL DEMO', color: muted),
                        const SizedBox(width: 12),
                        if (wide)
                          const Text(
                            '반가워요, 오늘도 함께해요',
                            style: TextStyle(
                              fontSize: AppText.minimumSize,
                              color: muted,
                            ),
                          ),
                        if (!wide)
                          IconButton(
                            tooltip: '로그아웃',
                            onPressed: () => attempt(context, s.logout),
                            icon: const Icon(Icons.logout, size: 20),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: tab == 2 && showMeetingMap
                        ? MeetingsTab(model: model, hostContext: context)
                        : SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              wide ? 36 : 20,
                              wide ? 36 : 20,
                              wide ? 36 : 20,
                              tab == 2 ? 100 : (wide ? 36 : 20),
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1180,
                                ),
                                child: content(),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => navigate(i),
              destinations: List.generate(
                5,
                (i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  label: ['하루', '추억', '약속', '채팅', '반려동물'][i],
                ),
              ),
            ),
    );
  }

  Widget content() => switch (tab) {
    1 => MemoryTab(model: model, hostContext: context),
    2 => MeetingsTab(model: model, hostContext: context),
    3 => CommunityTab(model: model, hostContext: context),
    4 => PetsTab(model: model, hostContext: context),
    _ => DashboardTab(model: model, hostContext: context),
  };
}
