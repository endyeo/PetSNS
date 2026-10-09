import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'store.dart';
import 'memory_calendar.dart';
import 'pet_profile_carousel.dart';
import 'home_week_calendar.dart';
import 'meeting_location.dart';
import 'meeting_map.dart';

const coral = Color(0xFFE77D63),
    ink = Color(0xFF343D34),
    cream = Color(0xFFFAF8F3),
    muted = Color(0xFF899083);
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PetApp());
}

class PetApp extends StatefulWidget {
  const PetApp({super.key});
  @override
  State<PetApp> createState() => _PetAppState();
}

class _PetAppState extends State<PetApp> {
  PetStore? store;
  String? error;
  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    setState(() => error = null);
    try {
      final s = PetStore(await SharedPreferences.getInstance());
      await s.load();
      if (mounted) {
        setState(() => store = s);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = '데이터를 불러오지 못했습니다. $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    title: 'PetSNS · 함께 쌓는 작은 행복',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: coral,
        primary: coral,
        surface: Colors.white,
      ),
      fontFamily: 'Malgun Gothic',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink),
        headlineMedium: TextStyle(color: ink, fontWeight: FontWeight.w800),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cream,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),
    home: store == null
        ? Scaffold(
            body: Center(
              child: error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!),
                        TextButton(onPressed: init, child: const Text('다시 시도')),
                      ],
                    ),
            ),
          )
        : ListenableBuilder(
            listenable: store!,
            builder: (context, _) => store!.user == null
                ? Login(store: store!)
                : Home(store: store!),
          ),
  );
}

Widget photo(
  String? source, {
  double? height,
  double? width,
  BoxFit fit = BoxFit.cover,
}) {
  Widget fallback() => Container(
    height: height,
    width: width,
    color: const Color(0xFFE9E8DA),
    child: const Center(
      child: Icon(Icons.pets_rounded, size: 48, color: muted),
    ),
  );
  if (source == null || source.isEmpty) {
    return fallback();
  }
  if (source.startsWith('data:')) {
    try {
      return Image.memory(
        base64Decode(source.split(',').last),
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, e, s) => fallback(),
      );
    } catch (_) {
      return fallback();
    }
  }
  return Image.network(
    source,
    height: height,
    width: width,
    fit: fit,
    errorBuilder: (_, e, s) => fallback(),
    loadingBuilder: (c, w, p) => p == null
        ? w
        : Container(
            height: height,
            width: width,
            color: const Color(0xFFE9E8DA),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
  );
}

Future<bool> attempt(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
    return false;
  }
}

Widget tag(String text, {Color color = const Color(0xFF6D8161)}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .1),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    text,
    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
  ),
);
Widget empty(String title, String subtitle, IconData icon) => Padding(
  padding: const EdgeInsets.all(40),
  child: Center(
    child: Column(
      children: [
        Icon(icon, size: 44, color: muted),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted),
        ),
      ],
    ),
  ),
);

class Login extends StatefulWidget {
  final PetStore store;
  const Login({super.key, required this.store});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool signup = false, busy = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> go(Future<void> Function() fn) async {
    setState(() => busy = true);
    await attempt(context, fn);
    if (mounted) {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, c) => Row(
                children: [
                  if (c.maxWidth > 700)
                    Expanded(
                      child: Stack(
                        children: [
                          photo(dogPhoto, height: 640, width: 440),
                          Positioned(
                            left: 30,
                            right: 30,
                            bottom: 40,
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              color: Colors.white.withValues(alpha: .9),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '작은 발자국,\n오래 남을 이야기.',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      color: ink,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Text('함께한 순간을 기록하고\n새로운 산책 친구를 만나보세요.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.pets, color: coral, size: 32),
                              SizedBox(width: 10),
                              Text(
                                'PetSNS',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                          Text(
                            signup ? '반가워요, 새로운 이웃!' : '우리의 일상이 모이는 곳',
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '반려동물과 함께 쓰는 따뜻한 하루',
                            style: TextStyle(color: muted),
                          ),
                          const SizedBox(height: 28),
                          if (signup) ...[
                            TextField(
                              controller: name,
                              decoration: const InputDecoration(
                                labelText: '이름',
                              ),
                              maxLength: 30,
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(labelText: '이메일'),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: password,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: '비밀번호 · 8자 이상',
                            ),
                            onSubmitted: (_) {
                              if (!busy) {
                                go(
                                  () => widget.store.login(
                                    email.text,
                                    password.text,
                                    name: signup ? name.text : null,
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: busy
                                ? null
                                : () => go(
                                    () => widget.store.login(
                                      email.text,
                                      password.text,
                                      name: signup ? name.text : null,
                                    ),
                                  ),
                            child: Text(
                              busy
                                  ? '잠시만 기다려 주세요'
                                  : signup
                                  ? '회원가입'
                                  : '로그인',
                            ),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setState(() => signup = !signup),
                            child: Text(
                              signup ? '이미 계정이 있어요 · 로그인' : '처음 오셨나요? 회원가입',
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(),
                          ),
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => go(widget.store.testLogin),
                            icon: const Icon(Icons.auto_awesome_outlined),
                            label: const Padding(
                              padding: EdgeInsets.all(14),
                              child: Text('테스트로 이용하기'),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            '가입 없이 바로 둘러보세요.\n기록은 이 기기와 브라우저에 저장됩니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class Home extends StatefulWidget {
  final PetStore store;
  const Home({super.key, required this.store});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  String filter = '전체';
  bool editingMemories = false;
  bool showMeetingMap = false;
  String meetingCategory = '강아지';
  int chatSection = 0;
  String? selectedPetId;
  late DateTime memoryDate;
  DateTime? homeDate;
  late DateTime memoryMonth;
  Timer? timer;
  PetStore get s => widget.store;
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
    memoryDate = DateUtils.dateOnly(korea(s.clock()));
    memoryMonth = DateTime(memoryDate.year, memoryDate.month);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  List<RecordData> owned(String key) =>
      s.rows(key).where((r) => r['owner'] == s.user).toList();
  RecordData? get selectedPet {
    final pets = owned('pets');
    final selected = pets.where((pet) => pet['id'] == selectedPetId);
    return selected.isNotEmpty
        ? selected.first
        : pets.isEmpty
        ? null
        : pets.first;
  }

  List<RecordData> get selectedPetMemories => owned(
    'memories',
  ).where((photo) => photo['petId'] == selectedPet?['id']).toList();
  DateTime? get selectedOrigin => s.memoryOriginFor(selectedPet?['id']);
  DateTime? get selectedFirstPhoto => s.firstPhotoDateFor(selectedPet?['id']);
  void selectPet(String id) => setState(() {
    selectedPetId = id;
    editingMemories = false;
    memoryDate = DateUtils.dateOnly(korea(s.clock()));
  });
  Future<void> recordPetMemory(RecordData pet) async {
    setState(() {
      selectedPetId = pet['id'];
      editingMemories = false;
      memoryDate = DateUtils.dateOnly(korea(s.clock()));
      tab = 1;
    });
    await editMemoryPhoto(initialDate: memoryDate, petId: pet['id']);
  }

  @override
  Widget build(BuildContext context) {
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
                      color: Colors.white,
                      child: SegmentedButton<bool>(
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          animationDuration: Duration.zero,
                          splashFactory: NoSplash.splashFactory,
                          overlayColor: Colors.transparent,
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
                        onSelectionChanged: (selection) =>
                            setState(() => showMeetingMap = selection.single),
                      ),
                    ),
                  ),
                  if (!showMeetingMap)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          splashFactory: NoSplash.splashFactory,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                        ),
                        child: FloatingActionButton.small(
                          key: const ValueKey('meeting-create-fab'),
                          tooltip: '약속 만들기',
                          shape: const CircleBorder(),
                          backgroundColor: coral,
                          foregroundColor: Colors.white,
                          heroTag: null,
                          elevation: 6,
                          focusElevation: 6,
                          hoverElevation: 6,
                          highlightElevation: 6,
                          onPressed: createMeeting,
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
                  color: Color(0xFFF5F2E9),
                  border: Border(right: BorderSide(color: Color(0xFFE7E5DB))),
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
                        style: TextStyle(fontSize: 11, color: muted),
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
                          selectedTileColor: const Color(0xFFF7E3D9),
                          selectedColor: coral,
                          leading: Icon(icons[i], size: 21),
                          title: Text(
                            labels[i],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () => setState(() => tab = i),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAECDD),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.wb_sunny_outlined,
                            color: Color(0xFF7C8A65),
                          ),
                          SizedBox(height: 12),
                          Text(
                            '산책하기 좋은 하루',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            '오늘도 작은 행복을\n하나 더 쌓아볼까요?',
                            style: TextStyle(
                              fontSize: 11,
                              color: muted,
                              height: 1.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE7C6AD),
                        child: Icon(Icons.person_outline, color: Colors.white),
                      ),
                      title: Text(
                        '${s.account['name']} 님',
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        s.user == 'test' ? '테스트 이용 중' : '나의 계정',
                        style: const TextStyle(fontSize: 11, color: muted),
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
                        bottom: BorderSide(color: Color(0xFFE9E7DE)),
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
                            style: TextStyle(fontSize: 12, color: muted),
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
                        ? meetingMapContent(wide)
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
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: List.generate(
                5,
                (i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  label: ['하루', '추억', '약속', '채팅', '프로필'][i],
                ),
              ),
            ),
    );
  }

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
            Text(sub, style: const TextStyle(fontSize: 12, color: muted)),
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
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ),
      ],
    ),
  );
  Widget content() {
    switch (tab) {
      case 1:
        return memories();
      case 2:
        return meetings();
      case 3:
        return chats();
      case 4:
        return pets();
      default:
        return dashboard();
    }
  }

  Widget dashboard() => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        key: const ValueKey('home-dashboard'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title('함께라서 더 좋은 하루 🐾', '평범한 오늘이, 소중한 추억이 되는 곳'),
          if (selectedPet == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  const Icon(Icons.pets_outlined, size: 44, color: muted),
                  const SizedBox(height: 12),
                  const Text('우리 가족을 먼저 소개해 주세요.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => editOwned('pets'),
                    child: const Text('반려동물 등록'),
                  ),
                ],
              ),
            )
          else
            PetProfileCarousel(
              pets: owned('pets'),
              selectedId: selectedPet!['id'],
              onSelected: (id) => setState(() => selectedPetId = id),
              onRecord: recordPetMemory,
              onFamily: () => setState(() => tab = 4),
              photoBuilder: (source) => photo(
                source,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          const SizedBox(height: 16),
          HomeWeekCalendar(
            today: DateUtils.dateOnly(korea(s.clock())),
            origin: selectedOrigin,
            selectedDate: homeDate ?? DateUtils.dateOnly(korea(s.clock())),
            meetingDates: s
                .rows('meetings')
                .where((m) => s.joined(m) && m['canceled'] != true)
                .map((m) => dayKey(korea(DateTime.parse(m['at']))))
                .toSet(),
            onSetup: selectedPet == null ? null : setupMemoryOrigin,
            onDateSelected: (date) => setState(() => homeDate = date),
          ),
          const SizedBox(height: 14),
          homeDayMemory(),
          const SizedBox(height: 10),
          homeDayMeetings(),
        ],
      ),
    ),
  );

  DateTime get homeSelectedDate =>
      homeDate ?? DateUtils.dateOnly(korea(s.clock()));

  Future<void> recordHomeMemory() async {
    final pet = selectedPet;
    if (pet == null) {
      await editOwned('pets');
      return;
    }
    setState(() {
      memoryDate = homeSelectedDate;
      editingMemories = false;
      tab = 1;
    });
    await editMemoryPhoto(initialDate: memoryDate, petId: pet['id']);
  }

  Widget homeDayMemory() {
    final date = homeSelectedDate;
    final today = DateUtils.dateOnly(korea(s.clock()));
    final isToday = DateUtils.isSameDay(date, today);
    final future = date.isAfter(today);
    final dateKey = dayKey(date);
    final memories = selectedPetMemories
        .where((m) => m['date'] == dateKey)
        .take(3)
        .toList();
    final journal = s.memoryDay(dateKey, petId: selectedPet?['id']);
    final title = (journal['title'] as String? ?? '').trim();
    final emptyLabel = future
        ? '이날의 추억이 기다리고 있어요'
        : isToday
        ? '오늘의 추억을 기록하기'
        : '이날의 추억을 기록하기';
    Widget tile(int index) {
      final memory = memories[index];
      return InkWell(
        key: ValueKey('home-day-photo-$index'),
        onTap: () => viewMemory(memory),
        child: Semantics(
          label: '추억 사진 ${index + 1} 보기',
          child: KeyedSubtree(
            key: ValueKey("home-memory-${memory['id']}"),
            child: photo(
              memory['photo'],
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
      );
    }

    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        key: const ValueKey('home-memory-collage'),
        width: 80,
        height: 80,
        child: memories.isEmpty
            ? InkWell(
                onTap: future ? null : recordHomeMemory,
                child: const ColoredBox(
                  color: Color(0xFFF4F2EB),
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: muted,
                    size: 28,
                  ),
                ),
              )
            : memories.length == 1
            ? tile(0)
            : Row(
                children: [
                  Expanded(flex: memories.length == 3 ? 3 : 1, child: tile(0)),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 2,
                    child: memories.length == 2
                        ? tile(1)
                        : Column(
                            children: [
                              Expanded(child: tile(1)),
                              const SizedBox(height: 2),
                              Expanded(child: tile(2)),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
    return Card(
      key: const ValueKey('home-day-memories'),
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E3DA)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: memories.isEmpty
            ? future
                  ? null
                  : recordHomeMemory
            : () => setState(() {
                memoryDate = date;
                editingMemories = false;
                tab = 1;
              }),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              thumbnail,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday ? '오늘의 추억' : '${date.month}월 ${date.day}일의 추억',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title.isNotEmpty
                          ? title
                          : memories.isEmpty
                          ? emptyLabel
                          : '소중한 하루의 한 조각',
                      key: const ValueKey('home-memory-title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (title.isNotEmpty && memories.isEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        emptyLabel,
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget homeDayMeetings() {
    final date = dayKey(homeSelectedDate);
    final meetings =
        s
            .rows('meetings')
            .where(
              (m) =>
                  s.joined(m) &&
                  m['canceled'] != true &&
                  dayKey(korea(DateTime.parse(m['at']))) == date,
            )
            .toList()
          ..sort(
            (a, b) =>
                DateTime.parse(a['at']).compareTo(DateTime.parse(b['at'])),
          );
    if (meetings.isEmpty) {
      return Container(
        key: const ValueKey('home-meetings-empty'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3E9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.wb_sunny_outlined, color: Color(0xFF7C8A65), size: 26),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '약속 없이, 우리만의 느긋한 하루',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '서로의 곁에서 쉬어 가도 좋아요.',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final meeting in meetings)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              key: ValueKey("home-meeting-${meeting['id']}"),
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE5E3DA)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => showMeeting(meeting['id']),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      meetingParticipants(meeting),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '함께하는 약속',
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              meeting['title'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              stamp(DateTime.parse(meeting['at'])),
                              style: const TextStyle(
                                fontSize: 11,
                                color: muted,
                              ),
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
      ],
    );
  }

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
  String memoryDayKey(DateTime date) => date.toIso8601String().substring(0, 10);

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
        color: Colors.white,
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
          Text(dateKey, style: const TextStyle(color: muted, fontSize: 12)),
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
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '사진 ${dayPhotos.length}장',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ),
              if (editingMemories)
                const Text(
                  '사진을 눌러 수정',
                  style: TextStyle(fontSize: 12, color: coral),
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
              height: 56,
              decoration: BoxDecoration(
                color: selected
                    ? coral.withValues(alpha: .08)
                    : Colors.transparent,
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
                      fontSize: 9,
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
                    style: TextStyle(fontSize: 12, color: muted, height: 1.6),
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

  void viewMemory(RecordData memory) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MemoryView(memory: memory)),
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
            style: TextStyle(color: coral, fontSize: 12),
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
                        child: Icon(Icons.edit, color: Colors.white, size: 15),
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
                              Text(
                                m['date'],
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
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
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                  height: 1.7,
                                ),
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
                style: const TextStyle(fontSize: 12, color: muted),
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
          style: TextStyle(color: muted, fontSize: 12),
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
      .where((m) => m['category'] == meetingCategory)
      .toList();

  Widget categorySelector() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        key: const ValueKey('meeting-categories'),
        segments: [
          for (final category in petCategories)
            ButtonSegment(value: category, label: Text(category)),
        ],
        selected: {meetingCategory},
        showSelectedIcon: false,
        onSelectionChanged: (selected) =>
            setState(() => meetingCategory = selected.single),
      ),
    ),
  );
  String meetingDistance(RecordData meeting) {
    final distance = meeting['distanceMeters'];
    if (distance is! num || !distance.isFinite || distance < 0) return '거리 미확인';
    return distance < 1000
        ? '${distance.round()}m'
        : '${(distance / 1000).toStringAsFixed(1)}km';
  }

  Widget participantAvatar(RecordData pet, {double size = 48}) => Semantics(
    key: ValueKey("meeting-pet-profile-${pet['id']}"),
    label: "참여 반려동물 ${pet['name']}",
    image: true,
    child: ClipOval(
      child: photo(pet['photo'], width: size, height: size),
    ),
  );

  Widget meetingParticipants(RecordData meeting) {
    final profiles = s.meetingPets(meeting);
    if (profiles.isEmpty) {
      return const SizedBox(
        width: 58,
        child: Column(
          children: [
            CircleAvatar(radius: 24, child: Icon(Icons.pets_outlined)),
            SizedBox(height: 6),
            Text('프로필 없음', style: TextStyle(fontSize: 9, color: muted)),
          ],
        ),
      );
    }
    final shown = profiles.take(3).toList();
    return SizedBox(
      key: ValueKey("meeting-pets-${meeting['id']}"),
      width: 58,
      child: Column(
        children: [
          SizedBox(
            height: 48 + (shown.length - 1) * 28.0,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  Positioned(
                    top: i * 28.0,
                    left: 3,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Tooltip(
                        message: shown[i]['name'],
                        child: participantAvatar(shown[i], size: 44),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (profiles.length > 3)
            Text(
              '+${profiles.length - 3}',
              style: const TextStyle(fontSize: 11, color: muted),
            ),
        ],
      ),
    );
  }

  Widget meetingPetChoice(
    List<String> selected,
    ValueChanged<List<String>> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '함께 참여할 반려동물',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: owned('pets')
              .map(
                (pet) => FilterChip(
                  key: ValueKey("meeting-pet-choice-${pet['id']}"),
                  label: Text(pet['name']),
                  avatar: participantAvatar(pet, size: 24),
                  selected: selected.contains(pet['id']),
                  onSelected: (include) => onChanged([
                    ...selected.where((id) => id != pet['id']),
                    if (include) pet['id'] as String,
                  ]),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );

  Widget meetingGrid(List<RecordData> list, {bool chat = false}) => list.isEmpty
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
                          side: const BorderSide(color: Color(0xFFE5E3DA)),
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
                              : showMeeting(m['id']),
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
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: muted,
                                              ),
                                            ),
                                          ),
                                          if (!chat)
                                            Text(
                                              ' / ${meetingDistance(m)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: muted,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        '${stamp(DateTime.parse(m['at']))} KST',
                                        key: ValueKey(
                                          "meeting-time-${m['id']}",
                                        ),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: muted,
                                        ),
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
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF6D8161),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${s.members(m).length} / ${m['capacity']}',
                                            key: ValueKey(
                                              "meeting-count-${m['id']}",
                                            ),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: muted,
                                            ),
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
  Widget pets() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      title(
        '우리 집 작은 가족',
        '가장 가까운 친구를 소개해 주세요.',
        action: FilledButton.icon(
          onPressed: () => editOwned('pets'),
          icon: const Icon(Icons.add),
          label: const Text('반려동물 등록'),
        ),
      ),
      owned('pets').isEmpty
          ? empty('가족을 소개해 주세요', '이름, 생일, 사진을 등록할 수 있어요.', Icons.pets)
          : grid(
              owned('pets')
                  .map(
                    (p) => Card(
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          photo(
                            p['photo'],
                            height: 230,
                            width: double.infinity,
                          ),
                          ListTile(
                            title: Text(
                              p['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${p['breed']}\n생일 ${p['birthday']}',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: '프로필 수정',
                              onPressed: () => editOwned('pets', existing: p),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    ],
  );
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
                  style: TextStyle(fontSize: 12, color: muted),
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
                side: const BorderSide(color: Color(0xFFE5E3DA)),
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
                              style: const TextStyle(
                                fontSize: 11,
                                color: muted,
                              ),
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
                        style: const TextStyle(fontSize: 11, color: muted),
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

  Future<void> createPost() async {
    final title = TextEditingController(), body = TextEditingController();
    var category = '강아지';
    var saving = false;
    await completedDialog(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('게시글 쓰기'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: '카테고리'),
                    items: [
                      for (final name in petCategories)
                        DropdownMenuItem(value: name, child: Text(name)),
                    ],
                    onChanged: saving
                        ? null
                        : (value) => update(() => category = value!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('post-title-input'),
                    controller: title,
                    enabled: !saving,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: '제목'),
                  ),
                  TextField(
                    key: const ValueKey('post-body-input'),
                    controller: body,
                    enabled: !saving,
                    maxLength: 2000,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(labelText: '이야기'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dc),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      update(() => saving = true);
                      final ok = await attempt(
                        c,
                        () => s.createPost(title.text, body.text, category),
                      );
                      if (!dc.mounted) return;
                      if (ok) {
                        if (mounted) setState(() {});
                        Navigator.pop(dc);
                      } else {
                        update(() => saving = false);
                      }
                    },
              child: const Text('게시하기'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    body.dispose();
  }

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
                style: TextStyle(fontSize: 12, color: muted),
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
      side: const BorderSide(color: Color(0xFFE5E3DA)),
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
                  backgroundColor: Color(0xFFF7E3D9),
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
            Text(
              group['note'],
              style: const TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${group['place']} · 멤버 ${s.members(group).length}명",
                    style: const TextStyle(fontSize: 11, color: muted),
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
                style: TextStyle(fontSize: 12, color: muted),
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
      if (join != true || !mounted) return;
      if (!await attempt(context, () => s.joinGroup(group['id']))) return;
      if (!mounted) return;
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

  Future<void> showMeeting(String mid) async {
    var participatingPets = <String>[
      if (selectedPet != null) selectedPet!['id'] as String,
    ];
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
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
                                  Text(
                                    pet['name'],
                                    style: const TextStyle(fontSize: 11),
                                  ),
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
    );
  }

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
                    color: const Color(0xFFF1F0EB),
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
                    style: const TextStyle(fontSize: 12, color: muted),
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
                    style: TextStyle(fontSize: 12, color: muted, height: 1.6),
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

  Future<void> createMeeting() async {
    final title = TextEditingController(), note = TextEditingController();
    MeetingLocation? chosenPlace;
    int capacity = 6;
    String category = meetingCategory;
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

Widget notice(String text) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: const Color(0xFFFFF0DE),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text(
    'ⓘ  $text',
    style: const TextStyle(fontSize: 12, height: 1.7, color: Color(0xFF946B36)),
  ),
);

class Counter extends StatefulWidget {
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const Counter({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  late final TextEditingController controller;
  late int value;
  @override
  void initState() {
    super.initState();
    value = widget.value;
    controller = TextEditingController(text: '$value');
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void set(int v) {
    value = v.clamp(widget.min, widget.max);
    controller.text = '$value';
    widget.onChanged(value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(widget.label, style: const TextStyle(fontSize: 13)),
        ),
        IconButton(
          onPressed: value > widget.min ? () => set(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 58,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (t) {
              final n = int.tryParse(t);
              value = n ?? -1;
              widget.onChanged(value);
              setState(() {});
            },
            onSubmitted: (t) => set(int.tryParse(t) ?? widget.min),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.all(8),
            ),
          ),
        ),
        IconButton(
          onPressed: value < widget.max ? () => set(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    ),
  );
}

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

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  Timer? timer;
  String? attachment;
  bool picking = false;
  PetStore get s => widget.store;
  @override
  void initState() {
    super.initState();
    s.addListener(refresh);
    timer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
  }

  @override
  void dispose() {
    s.removeListener(refresh);
    timer?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void refresh() {
    if (mounted) setState(() {});
  }

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
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ),
              Container(
                key: ValueKey("chat-bubble-${msg['id']}"),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: mine ? const Color(0xFFF6DFD5) : Colors.white,
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
                      style: const TextStyle(fontSize: 10, color: muted),
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
                                  fillColor: Colors.white,
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

class _ChatRoomDetailsState extends State<ChatRoomDetails> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    widget.store.addListener(refresh);
    timer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.store.removeListener(refresh);
    timer?.cancel();
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

// Keep form controllers alive until the dialog exit transition has finished.
Future<void> completedDialog({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final route = DialogRoute<void>(context: context, builder: builder);
  await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
}

class MemoryView extends StatelessWidget {
  const MemoryView({super.key, required this.memory});
  final RecordData memory;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF161916),
    appBar: AppBar(
      title: const Text('추억 보기'),
      backgroundColor: const Color(0xFF161916),
      foregroundColor: Colors.white,
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SizedBox(
              key: const ValueKey('memory-full-photo'),
              width: double.infinity,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: photo(
                  memory['photo'],
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              memory['date'],
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );
}
