import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../design_system.dart';
import '../supabase_photo_repository.dart';
import 'private_photo_scope.dart';

Widget photo(
  String? source, {
  double? height,
  double? width,
  BoxFit fit = BoxFit.cover,
}) => PetPhoto(source: source, height: height, width: width, fit: fit);

class PetPhoto extends StatefulWidget {
  const PetPhoto({
    super.key,
    this.source,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });
  final String? source;
  final double? height;
  final double? width;
  final BoxFit fit;
  @override
  State<PetPhoto> createState() => _PetPhotoState();
}

class _PetPhotoState extends State<PetPhoto> {
  Uint8List? bytes;
  int request = 0;
  bool loading = false;
  String? owner;
  SupabasePhotoRepository? repository;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = PrivatePhotoScope.of(context);
    if (owner != scope?.owner || repository != scope?.repository) {
      owner = scope?.owner;
      repository = scope?.repository;
      decode();
    }
  }

  @override
  void initState() {
    super.initState();
    decode();
  }

  @override
  void didUpdateWidget(PetPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) decode();
  }

  void decode() {
    request++;
    if (bytes != null) {
      PaintingBinding.instance.imageCache.evict(MemoryImage(bytes!));
    }
    bytes = null;
    loading = false;
    final source = widget.source;
    if (source?.startsWith(privatePhotoPrefix) == true) {
      loadPrivate();
      return;
    }
    if (source == null || !source.startsWith('data:')) return;
    try {
      bytes = base64Decode(source.split(',').last);
    } on FormatException {
      // Invalid stored photos use the same fallback as failed network images.
    }
  }

  @override
  void dispose() {
    request++;
    if (bytes != null &&
        widget.source?.startsWith(privatePhotoPrefix) == true) {
      PaintingBinding.instance.imageCache.evict(MemoryImage(bytes!));
    }
    super.dispose();
  }

  Future<void> loadPrivate() async {
    if (repository == null || owner == null) return;
    final current = request;
    loading = true;
    try {
      final result = await repository!.download(owner!, widget.source!);
      if (mounted && current == request) {
        setState(() {
          bytes = result;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted && current == request) setState(() => loading = false);
    }
  }

  Widget fallback() => Container(
    height: widget.height,
    width: widget.width,
    color: AppColors.photoPlaceholder,
    child: const Center(
      child: Icon(Icons.pets_rounded, size: 48, color: muted),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    if (source == null || source.isEmpty) return fallback();
    if (source.startsWith(privatePhotoPrefix)) {
      if (loading) {
        return SizedBox(
          height: widget.height,
          width: widget.width,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      if (bytes == null) {
        return SizedBox(
          height: widget.height,
          width: widget.width,
          child: Center(
            child: IconButton(
              tooltip: '사진 다시 불러오기',
              onPressed: owner == null || repository == null
                  ? null
                  : () {
                      setState(() => loading = true);
                      loadPrivate();
                    },
              icon: const Icon(Icons.refresh),
            ),
          ),
        );
      }
      return Image.memory(
        bytes!,
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        errorBuilder: (_, e, s) => fallback(),
      );
    }
    if (source.startsWith('data:')) {
      if (bytes == null || bytes!.isEmpty) return fallback();
      return Image.memory(
        bytes!,
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        errorBuilder: (_, e, s) => fallback(),
      );
    }
    return Image.network(
      source,
      height: widget.height,
      width: widget.width,
      fit: widget.fit,
      errorBuilder: (_, e, s) => fallback(),
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              height: widget.height,
              width: widget.width,
              color: AppColors.photoPlaceholder,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
    );
  }
}
