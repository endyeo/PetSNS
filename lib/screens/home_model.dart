import 'package:flutter/material.dart';
import '../store.dart';

class HomeModel extends ChangeNotifier {
  HomeModel(this.s) {
    memoryDate = DateUtils.dateOnly(korea(s.clock()));
    memoryMonth = DateTime(memoryDate.year, memoryDate.month);
  }
  final PetStore s;
  int tab = 0;
  String filter = '전체';
  bool editingMemories = false;
  bool showMeetingMap = false;
  String meetingCategory = '전체';
  int chatSection = 0;
  String? selectedPetId;
  late DateTime memoryDate;
  DateTime? homeDate;
  late DateTime memoryMonth;

  void update(VoidCallback action) {
    action();
    notifyListeners();
  }

  List<RecordData> owned(String key) =>
      s.rows(key).where((r) => r['owner'] == s.user).toList();
  RecordData? get selectedPet {
    final pets = owned('pets');
    final selected = pets.where((pet) => pet['id'] == selectedPetId);
    return selected.isNotEmpty
        ? selected.first
        : pets.isEmpty
        ? null
        : pets.first;
  }

  List<RecordData> get selectedPetMemories => owned(
    'memories',
  ).where((photo) => photo['petId'] == selectedPet?['id']).toList();
  DateTime? get selectedOrigin => s.memoryOriginFor(selectedPet?['id']);
  DateTime? get selectedFirstPhoto => s.firstPhotoDateFor(selectedPet?['id']);
  void selectPet(String id) => update(() {
    selectedPetId = id;
    editingMemories = false;
    memoryDate = DateUtils.dateOnly(korea(s.clock()));
  });
}
