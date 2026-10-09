import 'package:flutter/material.dart';
import '../store.dart';
import '../design_system.dart';
import 'pet_photo.dart';

Widget participantAvatar(RecordData pet, {double size = 48}) => Semantics(
  key: ValueKey("meeting-pet-profile-${pet['id']}"),
  label: "참여 반려동물 ${pet['name']}",
  image: true,
  child: ClipOval(
    child: photo(pet['photo'], width: size, height: size),
  ),
);

class MeetingParticipants extends StatelessWidget {
  const MeetingParticipants({
    super.key,
    required this.store,
    required this.meeting,
  });
  final PetStore store;
  final RecordData meeting;
  @override
  Widget build(BuildContext context) => render(meeting);
  Widget render(RecordData meeting) {
    final profiles = store.meetingPets(meeting);
    if (profiles.isEmpty) {
      return const SizedBox(
        width: 58,
        child: Column(
          children: [
            CircleAvatar(radius: 24, child: Icon(Icons.pets_outlined)),
            SizedBox(height: 6),
            Text(
              '프로필 없음',
              style: TextStyle(fontSize: AppText.minimumSize, color: muted),
            ),
          ],
        ),
      );
    }
    final shown = profiles.take(3).toList();
    return SizedBox(
      key: ValueKey("meeting-pets-${meeting['id']}"),
      width: 58,
      child: Column(
        children: [
          SizedBox(
            height: 48 + (shown.length - 1) * 28.0,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  Positioned(
                    top: i * 28.0,
                    left: 3,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Tooltip(
                        message: shown[i]['name'],
                        child: participantAvatar(shown[i], size: 44),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (profiles.length > 3)
            Text('+${profiles.length - 3}', style: AppText.captionMuted),
        ],
      ),
    );
  }
}

class MeetingPetChoice extends StatelessWidget {
  const MeetingPetChoice({
    super.key,
    required this.pets,
    required this.selected,
    required this.onChanged,
  });
  final List<RecordData> pets;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  @override
  Widget build(BuildContext context) => render(selected, onChanged);
  Widget render(List<String> selected, ValueChanged<List<String>> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '함께 참여할 반려동물',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: pets
                  .map(
                    (pet) => FilterChip(
                      key: ValueKey("meeting-pet-choice-${pet['id']}"),
                      label: Text(pet['name']),
                      avatar: participantAvatar(pet, size: 24),
                      selected: selected.contains(pet['id']),
                      onSelected: (include) => onChanged([
                        ...selected.where((id) => id != pet['id']),
                        if (include) pet['id'] as String,
                      ]),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      );
}
