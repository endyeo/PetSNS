import 'package:flutter/material.dart';
import '../widgets/common.dart';
import 'home_content.dart';
import 'home_model.dart';

class PetsTab extends StatelessWidget {
  const PetsTab({super.key, required this.model, required this.hostContext});
  final HomeModel model;
  final BuildContext hostContext;
  @override
  Widget build(BuildContext context) =>
      _PetsTabContent(hostContext, model).render();
}

class _PetsTabContent extends HomeContent {
  _PetsTabContent(super.context, super.model);
  Widget render() => pets();
  Widget pets() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      title(
        '우리 집 작은 가족',
        '가장 가까운 친구를 소개해 주세요.',
        action: FilledButton.icon(
          onPressed: () => editOwned('pets'),
          icon: const Icon(Icons.add),
          label: const Text('반려동물 등록'),
        ),
      ),
      owned('pets').isEmpty
          ? empty('가족을 소개해 주세요', '이름, 생일, 사진을 등록할 수 있어요.', Icons.pets)
          : grid(
              owned('pets')
                  .map(
                    (p) => Card(
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          photo(
                            p['photo'],
                            height: 230,
                            width: double.infinity,
                          ),
                          ListTile(
                            title: Text(
                              p['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${p['breed']}\n생일 ${p['birthday']}',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: '프로필 수정',
                              onPressed: () => editOwned('pets', existing: p),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    ],
  );
}
