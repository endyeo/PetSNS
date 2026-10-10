import 'package:flutter/widgets.dart';
import '../supabase_photo_repository.dart';

class PrivatePhotoScope extends InheritedWidget {
  const PrivatePhotoScope({
    super.key,
    required this.repository,
    required this.owner,
    required super.child,
  });
  final SupabasePhotoRepository? repository;
  final String? owner;
  static PrivatePhotoScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PrivatePhotoScope>();
  @override
  bool updateShouldNotify(PrivatePhotoScope oldWidget) =>
      owner != oldWidget.owner || repository != oldWidget.repository;
}
