import 'design_system.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'store.dart';

class PetProfileCarousel extends StatefulWidget {
  const PetProfileCarousel({
    super.key,
    required this.pets,
    required this.selectedId,
    required this.onSelected,
    required this.onRecord,
    required this.onFamily,
    required this.photoBuilder,
  });
  final List<RecordData> pets;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final ValueChanged<RecordData> onRecord;
  final VoidCallback onFamily;
  final Widget Function(String?) photoBuilder;
  @override
  State<PetProfileCarousel> createState() => _PetProfileCarouselState();
}

class _PetProfileCarouselState extends State<PetProfileCarousel> {
  late final PageController controller;
  int get selectedIndex => widget.pets
      .indexWhere((pet) => pet['id'] == widget.selectedId)
      .clamp(0, widget.pets.length - 1);
  @override
  void initState() {
    super.initState();
    controller = PageController(initialPage: selectedIndex);
  }

  @override
  void didUpdateWidget(PetProfileCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId ||
        oldWidget.pets.length != widget.pets.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            controller.hasClients &&
            controller.page?.round() != selectedIndex) {
          controller.jumpToPage(selectedIndex);
        }
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final pet = widget.pets[selectedIndex];
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              key: const ValueKey('home-pet-banner'),
              height: (constraints.maxWidth * .95).clamp(330.0, 390.0),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.stylus,
                        PointerDeviceKind.invertedStylus,
                        PointerDeviceKind.trackpad,
                      },
                    ),
                    child: PageView.builder(
                      key: const ValueKey('home-pet-pages'),
                      controller: controller,
                      itemCount: widget.pets.length,
                      onPageChanged: (index) =>
                          widget.onSelected(widget.pets[index]['id']),
                      itemBuilder: (context, index) => Semantics(
                        label: '${widget.pets[index]['name']} 사진',
                        image: true,
                        child: KeyedSubtree(
                          key: ValueKey("home-pet-${widget.pets[index]['id']}"),
                          child: widget.photoBuilder(
                            widget.pets[index]['photo'],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.scrimLight,
                            AppColors.transparent,
                            AppColors.scrimDark,
                          ],
                          stops: [0, .3, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IgnorePointer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pet['name'],
                                key: const ValueKey('home-pet-name'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.surface,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "${pet['breed']} · 생일 ${pet['birthday']}",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.captionOnPhoto,
                              ),
                              if (widget.pets.length > 1) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    ...List.generate(
                                      widget.pets.length,
                                      (index) => Container(
                                        margin: const EdgeInsets.only(right: 5),
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: index == selectedIndex
                                              ? AppColors.surface
                                              : AppColors.surface.withValues(
                                                  alpha: .35,
                                                ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      '좌우로 넘겨 보세요',
                                      style: TextStyle(
                                        fontSize: AppText.minimumSize,
                                        color: AppColors.onPhotoMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          key: const ValueKey('home-record-memory'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.surface,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 13,
                            ),
                          ),
                          onPressed: () =>
                              widget.onRecord(widget.pets[selectedIndex]),
                          child: const Text('추억 기록'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Material(
              color: AppColors.surface,
              child: InkWell(
                key: const ValueKey('home-family'),
                onTap: widget.onFamily,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.pets_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '가족 ${selectedIndex + 1} / ${widget.pets.length} 마리',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
