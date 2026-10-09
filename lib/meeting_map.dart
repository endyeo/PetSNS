import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'meeting_location.dart';

const _coral = Color(0xFFE77D63);

class PetMeetingMap extends StatefulWidget {
  const PetMeetingMap({
    super.key,
    this.locations = const [],
    this.markerLabels = const [],
    this.onMarkerTap,
    this.onPick,
    this.selected,
    this.initial,
  });
  final List<MeetingLocation> locations;
  final List<String> markerLabels;
  final ValueChanged<int>? onMarkerTap;
  final ValueChanged<MeetingLocation>? onPick;
  final MeetingLocation? selected, initial;
  @override
  State<PetMeetingMap> createState() => _PetMeetingMapState();
}

class _PetMeetingMapState extends State<PetMeetingMap> {
  final controller = MapController();
  bool tileError = false;
  int retry = 0;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        widget.initial ??
        (widget.locations.isEmpty
            ? meetingPlaceExamples.first
            : widget.locations.first);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          FlutterMap(
            key: ValueKey('meeting-map-$retry'),
            mapController: controller,
            options: MapOptions(
              initialCenter: LatLng(initial.latitude, initial.longitude),
              initialZoom: widget.onPick == null ? 12 : 14,
              minZoom: 3,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              initialCameraFit:
                  widget.initial == null && widget.locations.length > 1
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(
                        widget.locations
                            .map((l) => LatLng(l.latitude, l.longitude))
                            .toList(),
                      ),
                      padding: const EdgeInsets.all(48),
                      maxZoom: 15,
                    )
                  : null,
              onTap: widget.onPick == null
                  ? null
                  : (_, point) => widget.onPick!(
                      MeetingLocation(
                        '선택한 장소',
                        point.latitude,
                        point.longitude,
                      ),
                    ),
            ),
            children: [
              TileLayer(
                urlTemplate: const String.fromEnvironment(
                  'PET_SNS_MAP_TILES',
                  defaultValue:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                userAgentPackageName: 'com.portfolio.pet_sns',
                maxNativeZoom: 19,
                panBuffer: 0,
                errorTileCallback: (_, _, _) {
                  if (mounted && !tileError) setState(() => tileError = true);
                },
              ),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < widget.locations.length; i++)
                    Marker(
                      point: LatLng(
                        widget.locations[i].latitude,
                        widget.locations[i].longitude,
                      ),
                      width: 48,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: IconButton(
                        key: ValueKey('meeting-map-marker-$i'),
                        tooltip: widget.markerLabels.length > i
                            ? widget.markerLabels[i]
                            : '${widget.locations[i].name} 선택',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _coral,
                        ),
                        icon: const Icon(Icons.pets, size: 25),
                        onPressed: () {
                          if (widget.onMarkerTap != null) {
                            widget.onMarkerTap!(i);
                          }
                          widget.onPick?.call(widget.locations[i]);
                        },
                      ),
                    ),
                  if (widget.selected != null)
                    Marker(
                      point: LatLng(
                        widget.selected!.latitude,
                        widget.selected!.longitude,
                      ),
                      alignment: Alignment.topCenter,
                      width: 40,
                      height: 48,
                      child: const IgnorePointer(
                        child: Icon(Icons.location_on, size: 40, color: _coral),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              color: Colors.white.withValues(alpha: .9),
              child: InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 10, color: Color(0xFF343D34)),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 34,
            child: Column(
              children: [
                IconButton.filledTonal(
                  tooltip: '지도 확대',
                  onPressed: () => controller.move(
                    controller.camera.center,
                    (controller.camera.zoom + 1).clamp(3, 19),
                  ),
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(height: 4),
                IconButton.filledTonal(
                  tooltip: '지도 축소',
                  onPressed: () => controller.move(
                    controller.camera.center,
                    (controller.camera.zoom - 1).clamp(3, 19),
                  ),
                  icon: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
          if (tileError)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '지도 배경을 불러오지 못했어요.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          tileError = false;
                          retry++;
                        }),
                        child: const Text('재시도'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MeetingPlacePicker extends StatefulWidget {
  const MeetingPlacePicker({super.key, this.initial});
  final MeetingLocation? initial;
  @override
  State<MeetingPlacePicker> createState() => _MeetingPlacePickerState();
}

class _MeetingPlacePickerState extends State<MeetingPlacePicker> {
  late MeetingLocation? selected = widget.initial;
  late final name = TextEditingController(text: widget.initial?.name ?? '');
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('지도에서 장소 선택')),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              '지점을 누르거나 장소 핀을 선택해 주세요.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PetMeetingMap(
                key: const ValueKey('meeting-place-map'),
                locations: meetingPlaceExamples,
                initial: widget.initial,
                selected: selected,
                onPick: (place) => setState(() {
                  selected = place;
                  name.text = place.name == '선택한 장소' ? '' : place.name;
                }),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: TextField(
              key: const ValueKey('meeting-place-name'),
              controller: name,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: '장소 이름 (선택)',
                hintText: '예: 공원 정문 앞',
              ),
            ),
          ),
          if (selected != null)
            Text(
              '${selected!.latitude.toStringAsFixed(5)}, ${selected!.longitude.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF899083)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('meeting-place-confirm'),
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(
                        context,
                        MeetingLocation(
                          name.text.trim().isEmpty
                              ? '선택한 장소 (${selected!.latitude.toStringAsFixed(4)}, ${selected!.longitude.toStringAsFixed(4)})'
                              : name.text.trim(),
                          selected!.latitude,
                          selected!.longitude,
                        ),
                      ),
                child: const Text('이 장소로 선택'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
