import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../design_system.dart';

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
    bytes = null;
    final source = widget.source;
    if (source == null || !source.startsWith('data:')) return;
    try {
      bytes = base64Decode(source.split(',').last);
    } on FormatException {
      // Invalid stored photos use the same fallback as failed network images.
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
