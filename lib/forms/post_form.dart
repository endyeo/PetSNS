part of 'home_forms.dart';

mixin PostForm on HomeBindings {
  @override
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
}
