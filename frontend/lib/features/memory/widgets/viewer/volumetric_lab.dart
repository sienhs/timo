import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../effects/effect_quality.dart';
import '../../models/memory_ticket.dart';
import '../../models/ticket_effect.dart';
import '../../theme/timo_colors.dart';
import '../../constants.dart';
import '../../effects/volumetric_light.dart';
import 'memory_ticket_card.dart';

/// Tuning room for the volumetric light. Runs the real [MemoryTicketCard]
/// renderer with an on/off switch, hold-to-compare, a quality tier lock, a
/// reduced-motion toggle and a slider for every [VolumetricLightParams]
/// field. Without a ticket it stages the bundled demo photo and cut-out.
class VolumetricLab extends StatefulWidget {
  const VolumetricLab({super.key, this.ticket});
  final MemoryTicket? ticket;
  @override
  State<VolumetricLab> createState() => _VolumetricLabState();
}

class _VolumetricLabState extends State<VolumetricLab> {
  final params = VolumetricLightController.instance;
  final quality = EffectQualityController.instance;
  MemoryTicket? ticket, shown;
  bool enabled = true, comparing = false, reduceMotion = false;
  EffectQuality? lockedQuality;

  static const swatches = [
    Color(0xFFFFC98A), // warm tungsten
    Color(0xFFFFB347), // amber
    Color(0xFFFFF1D6), // soft white
    Color(0xFFFFB0C8), // rose
    Color(0xFFA9C8FF), // moonlight
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.ticket;
    if (t != null) {
      setTicket(t);
    } else {
      stageDemo();
    }
  }

  void setTicket(MemoryTicket t) {
    ticket = t;
    shown = t;
    refreshShown();
  }

  /// One ticket instance per on/off state so the card keeps its state
  /// while sliders move; only the switch rebuilds the front face.
  void refreshShown() {
    final t = ticket;
    if (t == null) return;
    final effect = enabled && !comparing
        ? TicketEffect.godRays
        : TicketEffect.none;
    if (shown?.effect != effect) {
      shown = t.copyWith(effectType: effect.label);
    }
  }

  Future<void> stageDemo() async {
    final dir = Directory(
      '${(await getTemporaryDirectory()).path}/volumetric_lab',
    );
    await dir.create(recursive: true);
    Future<String> copy(String asset, String name) async {
      // Always rewrite: the bundled asset may change between builds.
      final file = File('${dir.path}/$name');
      final data = await rootBundle.load(asset);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      return file.path;
    }

    final background = await copy('assets/demo/stage_gold.png', 'stage.png');
    final person = await copy('assets/demo/person_a_cutout.png', 'person.png');
    if (!mounted) return;
    setState(
      () => setTicket(
        MemoryTicket(
          ticketId: 'volumetric-lab',
          concertId: 'demo',
          backgroundPath: background,
          personCompositePath: person,
          effectType: TicketEffect.godRays.label,
          videoId: '',
          videoUrl: '',
          details: const {},
          depthLayers: const [],
          demoDepth: true,
        ),
      ),
    );
  }

  void setQuality(EffectQuality? tier) {
    lockedQuality = tier;
    if (tier == null) {
      quality
        ..unlock()
        ..value = EffectQuality.high;
    } else {
      quality.lock(tier);
    }
    setState(() {});
  }

  @override
  void dispose() {
    // Leave the adaptive controller the way the app expects it.
    if (lockedQuality != null) {
      quality
        ..unlock()
        ..value = EffectQuality.high;
    }
    super.dispose();
  }

  void set(VolumetricLightParams next) => params.value = next;

  @override
  Widget build(BuildContext context) {
    final t = shown;
    return Scaffold(
      backgroundColor: const Color(0xFF070A12),
      appBar: AppBar(
        title: const Text('빛줄기 실험실'),
        actions: [
          TextButton(onPressed: params.reset, child: const Text('초기화')),
        ],
      ),
      body: t == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  flex: 11,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(40, 6, 40, 4),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: ViewerConstants.cardAspect,
                        child: MediaQuery(
                          data: MediaQuery.of(context)
                              .copyWith(disableAnimations: reduceMotion),
                          child: ValueListenableBuilder<VolumetricLightParams>(
                            valueListenable: params,
                            // Only the glow colour depends on the params here;
                            // the card's painters listen on their own.
                            builder: (_, v, child) => MemoryTicketCard(
                              ticket: t,
                              glow: v.color,
                              wrap: (photo, drag, flip) => _DragSurface(
                                onDrag: drag,
                                onFlip: flip,
                                child: photo,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                compareBar(),
                Expanded(flex: 9, child: controls()),
              ],
            ),
    );
  }

  Widget compareBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
    child: Row(
      children: [
        Switch.adaptive(
          value: enabled,
          onChanged: (v) => setState(() {
            enabled = v;
            refreshShown();
          }),
        ),
        const SizedBox(width: 4),
        const Text(
          '효과',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        ValueListenableBuilder<EffectQuality>(
          valueListenable: quality,
          builder: (_, q, _) => Text(
            '품질 ${q.name}',
            style: const TextStyle(
              fontSize: 11,
              color: TimoColors.textTertiary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Listener(
          onPointerDown: (_) => setState(() {
            comparing = true;
            refreshShown();
          }),
          onPointerUp: (_) => setState(() {
            comparing = false;
            refreshShown();
          }),
          onPointerCancel: (_) => setState(() {
            comparing = false;
            refreshShown();
          }),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: comparing
                  ? TimoColors.accent.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                '길게 눌러 원본 비교',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget controls() => ValueListenableBuilder<VolumetricLightParams>(
    valueListenable: params,
    builder: (_, v, _) => ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        section('광원'),
        slider('가로 위치', v.lightX, 0, 1, (x) => set(v.copyWith(lightX: x))),
        slider('높이', v.lightY, -0.6, 0.4, (x) => set(v.copyWith(lightY: x))),
        slider(
          '방향',
          v.direction,
          -0.8,
          0.8,
          (x) => set(v.copyWith(direction: x)),
        ),
        slider('빛줄기 폭', v.spread, 0.2, 1.2, (x) => set(v.copyWith(spread: x))),
        slider(
          '줄기 세밀도',
          v.shaftScale,
          3,
          16,
          (x) => set(v.copyWith(shaftScale: x)),
          digits: 0,
        ),
        slider('강도', v.intensity, 0, 1, (x) => set(v.copyWith(intensity: x))),
        slider('도달 거리', v.reach, 0.4, 1.8, (x) => set(v.copyWith(reach: x))),
        Row(
          children: [
            const SizedBox(
              width: 92,
              child: Text('색', style: TextStyle(fontSize: 12)),
            ),
            for (final c in swatches)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => set(v.copyWith(color: c)),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: v.color == c
                          ? Border.all(color: Colors.white, width: 2.5)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: c.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        section('안개·공기'),
        slider(
          '안개 밀도',
          v.fogDensity,
          0,
          1,
          (x) => set(v.copyWith(fogDensity: x)),
        ),
        slider('원경 안개', v.farHaze, 0, 1, (x) => set(v.copyWith(farHaze: x))),
        slider(
          '인물 앞 안개',
          v.frontHaze,
          0,
          0.6,
          (x) => set(v.copyWith(frontHaze: x)),
        ),
        section('먼지'),
        slider(
          '먼지 양',
          v.dustAmount,
          0,
          1,
          (x) => set(v.copyWith(dustAmount: x)),
        ),
        slider(
          '먼지 속도',
          v.dustSpeed,
          0,
          2,
          (x) => set(v.copyWith(dustSpeed: x)),
        ),
        section('림 라이트'),
        slider(
          '세기',
          v.rimIntensity,
          0,
          1,
          (x) => set(v.copyWith(rimIntensity: x)),
        ),
        slider(
          '두께',
          v.rimWidth,
          1,
          6,
          (x) => set(v.copyWith(rimWidth: x)),
          digits: 1,
        ),
        section('성능'),
        Row(
          children: [
            const SizedBox(
              width: 92,
              child: Text('품질', style: TextStyle(fontSize: 12)),
            ),
            Expanded(
              child: SegmentedButton<EffectQuality?>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: null, label: Text('자동')),
                  ButtonSegment(value: EffectQuality.high, label: Text('높음')),
                  ButtonSegment(value: EffectQuality.medium, label: Text('중간')),
                  ButtonSegment(value: EffectQuality.low, label: Text('낮음')),
                ],
                selected: {lockedQuality},
                onSelectionChanged: (s) => setQuality(s.first),
              ),
            ),
          ],
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('모션 감소', style: TextStyle(fontSize: 12)),
          subtitle: const Text(
            '빛과 먼지가 정지 프레임으로 표시돼요.',
            style: TextStyle(fontSize: 11),
          ),
          value: reduceMotion,
          onChanged: (x) => setState(() => reduceMotion = x),
        ),
      ],
    ),
  );

  Widget section(String title) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 2),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: TimoColors.textSecondary,
        letterSpacing: 1,
      ),
    ),
  );

  Widget slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int digits = 2,
  }) => Row(
    children: [
      SizedBox(
        width: 92,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
      Expanded(
        child: SliderTheme(
          data: const SliderThemeData(
            trackHeight: 2,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ),
      SizedBox(
        width: 40,
        child: Text(
          value.toStringAsFixed(digits),
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 11,
            fontFeatures: [FontFeature.tabularFigures()],
            color: TimoColors.textTertiary,
          ),
        ),
      ),
    ],
  );
}

/// Minimal card interaction for the lab: drag tilts, tap flips.
class _DragSurface extends StatefulWidget {
  const _DragSurface({
    required this.onDrag,
    required this.onFlip,
    required this.child,
  });
  final ValueChanged<Offset> onDrag;
  final VoidCallback onFlip;
  final Widget child;
  @override
  State<_DragSurface> createState() => _DragSurfaceState();
}

class _DragSurfaceState extends State<_DragSurface> {
  Offset origin = Offset.zero;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: widget.onFlip,
    onPanStart: (d) => origin = d.localPosition,
    onPanUpdate: (d) => widget.onDrag(d.localPosition - origin),
    onPanEnd: (_) => widget.onDrag(Offset.zero),
    onPanCancel: () => widget.onDrag(Offset.zero),
    child: widget.child,
  );
}
