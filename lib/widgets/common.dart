import 'package:flutter/material.dart';
import '../design_system.dart';
export 'pet_photo.dart';

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

Widget tag(String text, {Color color = AppColors.success}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .1),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    text,
    style: TextStyle(
      fontSize: AppText.minimumSize,
      color: color,
      fontWeight: FontWeight.w700,
    ),
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

Widget notice(String text) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: AppColors.noticeSurface,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text('ⓘ  $text', style: AppText.captionNoticeComfortable),
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

// Keep form controllers alive until the dialog exit transition has finished.
Future<void> completedDialog({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final route = DialogRoute<void>(context: context, builder: builder);
  await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
}
