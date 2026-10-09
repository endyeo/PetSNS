import 'package:flutter/material.dart';
import '../store.dart';
import 'home_bindings.dart';
import '../forms/home_forms.dart';
import 'memory_view.dart';
import '../widgets/meeting_list.dart';

abstract class HomeContent extends HomeBindings {
  HomeContent(super.context, super.model);
  HomeForms get forms => HomeForms(context, model);
  @override
  Future<void> editOwned(
    String collection, {
    RecordData? existing,
    DateTime? initialDate,
  }) =>
      forms.editOwned(collection, existing: existing, initialDate: initialDate);
  @override
  Future<void> editMemoryPhoto({
    RecordData? existing,
    DateTime? initialDate,
    String? petId,
  }) => forms.editMemoryPhoto(
    existing: existing,
    initialDate: initialDate,
    petId: petId,
  );
  @override
  Future<void> setupMemoryOrigin() => forms.setupMemoryOrigin();
  @override
  Future<void> editMemoryDay() => forms.editMemoryDay();
  @override
  Future<void> createMeeting() => forms.createMeeting();
  @override
  Future<void> createPost() => forms.createPost();
  @override
  Future<void> showMeeting(String mid) => forms.showMeeting(mid);
  Widget meetingGrid(List<RecordData> list, {bool chat = false}) =>
      MeetingList(store: s, meetings: list, chat: chat, onOpen: showMeeting);
  void viewMemory(RecordData memory) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MemoryView(memory: memory)),
    );
  }
}
