class MeetingLocation {
  const MeetingLocation(this.name, this.latitude, this.longitude);
  final String name;
  final double latitude, longitude;
  bool get isValid =>
      name.trim().isNotEmpty &&
      name.trim().length <= 100 &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -85 &&
      latitude <= 85 &&
      longitude >= -180 &&
      longitude <= 180;
  static MeetingLocation? fromRecord(Map<String, dynamic> record) {
    final lat = record['latitude'], lng = record['longitude'];
    if (lat is! num || lng is! num) return null;
    final place = MeetingLocation(
      record['place'] as String? ?? '약속 장소',
      lat.toDouble(),
      lng.toDouble(),
    );
    return place.isValid ? place : null;
  }
}

const meetingPlaceExamples = [
  MeetingLocation('서울 · 반포한강공원', 37.5103, 126.9950),
  MeetingLocation('서울 · 서울숲', 37.5445, 127.0374),
];
