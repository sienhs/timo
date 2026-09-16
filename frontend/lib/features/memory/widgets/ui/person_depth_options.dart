import 'package:flutter/material.dart';

import '../../models/person_depth_layer.dart';

class PersonDepthOptions extends StatelessWidget {
  const PersonDepthOptions({
    super.key,
    required this.value,
    required this.onChanged,
    this.available = true,
    this.layerLabels = const [],
    this.layered = false,
    this.onLayeredChanged,
  });
  final PersonDepthStrength value;
  final ValueChanged<PersonDepthStrength> onChanged;
  final bool available;

  /// Body-part layers found for this person, far to near. Empty when the
  /// split was not possible; the toggle is then hidden.
  final List<String> layerLabels;
  final bool layered;
  final ValueChanged<bool>? onLayeredChanged;

  @override
  Widget build(BuildContext context) {
    final canLayer =
        available && layerLabels.length >= 2 && onLayeredChanged != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '인물 입체감',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final strength in PersonDepthStrength.values)
              ChoiceChip(
                key: ValueKey('person-depth-${strength.name}'),
                label: Text(strength.label),
                selected: value == strength,
                onSelected: available ? (_) => onChanged(strength) : null,
              ),
          ],
        ),
        if (canLayer)
          SwitchListTile(
            key: const ValueKey('person-depth-layered'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              '부위별로 나누기',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '층 ${layerLabels.length}개: ${layerLabels.join('·')}',
              style: const TextStyle(fontSize: 11),
            ),
            value: layered && value != PersonDepthStrength.off,
            onChanged: value == PersonDepthStrength.off
                ? null
                : onLayeredChanged,
          ),
        Text(switch ((available, canLayer && layered)) {
          (false, _) => '깊이를 분석하지 못해 고정 이미지로 보여줘요.',
          (true, true) => '얼굴·손·머리카락이 서로 다른 깊이로 움직여요. 위치와 윤곽은 그대로예요.',
          (true, false) => '위치와 윤곽은 고정하고 내부에만 입체감을 줘요.',
        }, style: const TextStyle(fontSize: 11, height: 1.5)),
      ],
    );
  }
}
