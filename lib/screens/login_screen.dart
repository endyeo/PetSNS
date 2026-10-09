import 'package:flutter/material.dart';
import '../store.dart';
import '../design_system.dart';
import '../widgets/common.dart';

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
                              color: AppColors.surface.withValues(alpha: .9),
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
                            style: TextStyle(
                              fontSize: AppText.minimumSize,
                              color: muted,
                            ),
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
