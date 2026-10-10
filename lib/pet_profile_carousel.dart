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
    this.origin,
    this.originForPet,
    this.today,
    this.onSetup,
  });
  final List<RecordData> pets;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final ValueChanged<RecordData> onRecord;
  final VoidCallback onFamily;
  final Widget Function(String?) photoBuilder;
  final DateTime? origin;
  final DateTime? Function(String petId)? originForPet;
  final DateTime? today;
  final VoidCallback? onSetup;
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
      final origin = widget.originForPet != null
          ? widget.originForPet!(pet['id'])
          : widget.origin;
      final today = widget.today ?? DateUtils.dateOnly(DateTime.now());
      String dayText;
      if (origin != null) {
        final count = daysBetween(origin, today) + 1;
        if (count >= 1) {
          dayText = 'D+$count';
        } else {
          dayText = '기준 설정';
        }
      } else {
        dayText = '기준 설정';
      }

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
                    top: 16,
                    right: 16,
                    child: Material(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        key: const ValueKey('home-pet-day'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: origin == null ? widget.onSetup : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: Text(
                            dayText,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: IgnorePointer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
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
                                const SizedBox(height: 4),
                                Text(
                                  pet['breed'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.captionOnPhoto,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          key: const ValueKey('home-record-memory'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.surface,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
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
                      Row(
                        key: const ValueKey('home-pet-indicators'),
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          widget.pets.length,
                          (index) => Container(
                            margin: const EdgeInsets.only(right: 5),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index == selectedIndex
                                  ? AppColors.primary
                                  : AppColors.muted.withValues(
                                      alpha: .35,
                                    ),
                            ),
                          ),
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
