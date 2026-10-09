import 'package:flutter/material.dart';
import '../store.dart';
import '../design_system.dart';
import '../widgets/common.dart';

class MemoryView extends StatelessWidget {
  const MemoryView({super.key, required this.memory});
  final RecordData memory;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.photoViewer,
    appBar: AppBar(
      title: const Text('추억 보기'),
      backgroundColor: AppColors.photoViewer,
      foregroundColor: AppColors.surface,
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
              style: const TextStyle(
                color: AppColors.onPhotoMuted,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
