import 'package:flutter/material.dart';

import '../../models/photo_framing.dart';
import '../../theme/timo_colors.dart';
import '../ui/local_image.dart';
import '../ui/person_depth_options.dart';
import '../../models/person_depth_layer.dart';
import '../../data/person_placement.dart';
import 'photo_frame.dart';

/// Shows the framed source photo, before depth processing, with editable people.
class PersonPlacementEditor extends StatefulWidget {
  const PersonPlacementEditor({
    super.key,
    required this.background,
    required this.framing,
    required this.people,
    required this.onChanged,
    this.onRepair,
  });
  final String background;
  final PhotoFraming framing;
  final List<Map<String, dynamic>> people;
  final void Function(int index, Map<String, dynamic> changes) onChanged;
  final void Function(int index)? onRepair;

  @override
  State<PersonPlacementEditor> createState() => _PersonPlacementEditorState();
}

class _PersonPlacementEditorState extends State<PersonPlacementEditor> {
  int? selected = 0;
  static const corners = [
    Offset(-1, -1),
    Offset(1, -1),
    Offset(-1, 1),
    Offset(1, 1),
  ];
  PersonPlacement placement(int i) =>
      PersonPlacement.fromPerson(widget.people[i]);
  void update(int i, PersonPlacement value) =>
      widget.onChanged(i, {'placement': value.toJson()});

  @override
  Widget build(BuildContext context) {
    final active = selected != null && selected! < widget.people.length
        ? selected
        : null;
    final ready = widget.people.every((p) => p['placement'] != null);
    final order = widget.people.asMap().keys.toList()
      ..sort(
        (a, b) => ((widget.people[a]['order'] as num?) ?? a).compareTo(
          (widget.people[b]['order'] as num?) ?? b,
        ),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 제목과 사용법은 단계 머리말이 이미 말한다. 여기서 또 적으면 화면
        // 위쪽 절반이 글자로 찬다.
        Wrap(
          spacing: 8,
          children: [
            for (final i in widget.people.asMap().keys)
              ChoiceChip(
                key: ValueKey('select-person-$i'),
                label: Text('인물 ${i + 1}'),
                selected: active == i,
                onSelected: ready ? (_) => setState(() => selected = i) : null,
              ),
            ActionChip(
              label: const Text('선택 해제'),
              onPressed: () => setState(() => selected = null),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: PersonPlacement.canvasAspect,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final activeRect = ready && active != null
                    ? placement(active).inCanvas(size)
                    : null;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      key: const ValueKey('placement-background'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => selected = null),
                      child: IgnorePointer(
                        child: PhotoFrame(
                          path: widget.background,
                          framing: widget.framing,
                        ),
                      ),
                    ),
                    if (ready)
                      for (final i in order)
                        Positioned.fromRect(
                          rect: placement(i).inCanvas(size),
                          child: GestureDetector(
                            key: ValueKey('placement-person-$i'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => selected = i),
                            child: LocalImage(
                              widget.people[i]['path'] as String,
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                    if (activeRect != null) ...[
                      Positioned.fromRect(
                        rect: activeRect,
                        child: GestureDetector(
                          key: ValueKey('move-person-$active'),
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (d) => update(
                            active!,
                            placement(active).move(
                              Offset(
                                d.delta.dx / size.width,
                                d.delta.dy / size.height,
                              ),
                            ),
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: TimoColors.accent,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      for (var c = 0; c < corners.length; c++)
                        Positioned(
                          left:
                              (corners[c].dx < 0
                                  ? activeRect.left
                                  : activeRect.right) -
                              18,
                          top:
                              (corners[c].dy < 0
                                  ? activeRect.top
                                  : activeRect.bottom) -
                              18,
                          width: 36,
                          height: 36,
                          child: Semantics(
                            label: '인물 ${active! + 1} 크기 조절 모서리 ${c + 1}',
                            child: GestureDetector(
                              key: ValueKey('resize-person-$active-$c'),
                              behavior: HitTestBehavior.opaque,
                              onPanUpdate: (d) => update(
                                active,
                                placement(active)
                                    .resize(d.delta, corners[c], size),
                              ),
                              child: Center(
                                child: Container(
                                  width: 13,
                                  height: 13,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: TimoColors.accent,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '깊이 효과를 적용하기 전 배경이에요. 완성 티켓에도 이 구도가 적용돼요.',
          style: TextStyle(
            fontSize: 11,
            height: 1.5,
            color: TimoColors.textSecondary,
          ),
        ),
        if (ready && active != null) ...[
          if (widget.onRepair != null &&
              widget.people[active]['sourceCrop'] != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => widget.onRepair!(active),
                icon: const Icon(Icons.brush_outlined),
                label: const Text('누끼 보정 · 손 복원'),
              ),
            ),
          const SizedBox(height: 8),
          PersonDepthOptions(
            value: PersonDepthStrength.fromName(
              widget.people[active]['depthStrength'],
            ),
            available: widget.people[active]['personDepthPath'] != null,
            layerLabels: [
              for (final part
                  in widget.people[active]['parts'] as List? ?? const [])
                PersonPart.fromJson(Map<String, dynamic>.from(part as Map))
                    .name,
            ],
            layered: widget.people[active]['layeredDepth'] == true,
            onLayeredChanged: (value) =>
                widget.onChanged(active, {'layeredDepth': value}),
            onChanged: (value) =>
                widget.onChanged(active, {'depthStrength': value.name}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              TextButton.icon(
                onPressed: () => update(active, placement(active).scaleBy(0.9)),
                icon: const Icon(Icons.remove, size: 18),
                label: const Text('축소'),
              ),
              TextButton.icon(
                onPressed: () => update(active, placement(active).scaleBy(1.1)),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('확대'),
              ),
              TextButton.icon(
                onPressed: () => update(
                  active,
                  placement(active).move(
                    const Offset(0.5, 0.5) - placement(active).rect.center,
                  ),
                ),
                icon: const Icon(Icons.center_focus_strong, size: 18),
                label: const Text('중앙으로'),
              ),
              if (widget.people.length > 1)
                TextButton.icon(
                  onPressed: () => widget.onChanged(active, {
                    'order':
                        ((widget.people[order.last]['order'] as num?) ??
                            order.last) +
                        1,
                  }),
                  icon: const Icon(Icons.flip_to_front, size: 18),
                  label: const Text('맨 앞으로'),
                ),
              TextButton.icon(
                onPressed: () => widget.onChanged(active, {
                  'placement': Map<String, dynamic>.from(
                    widget.people[active]['initialPlacement'] as Map,
                  ),
                }),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('선택 인물 초기화'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
