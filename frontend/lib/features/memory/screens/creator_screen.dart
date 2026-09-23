import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants.dart';
import '../models/concert_kit.dart';
import '../models/memory_concert.dart';
import '../state/creation_job_scope.dart';
import '../state/memory_concert_api_scope.dart';
import '../state/ticket_store_scope.dart';
import '../widgets/creator/concert_card.dart';
import '../widgets/creator/concert_list_skeleton.dart';
import '../widgets/creator/processing_orbit.dart';
import '../widgets/creator/processing_stage.dart';
import '../widgets/creator/photo_frame.dart';
import '../widgets/creator/photo_source_sheet.dart';
import '../widgets/creator/person_placement_editor.dart';
import '../widgets/creator/selection_tile.dart';
import '../widgets/creator/step_progress.dart';
import '../widgets/viewer/effect_layer.dart';
import '../widgets/viewer/volumetric_lab.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/timo_mascot.dart';
import '../motion/motion_tokens.dart';
import '../motion/reveal.dart';
import '../motion/staggered_text.dart';
import '../widgets/ui/overlay_service.dart';
import '../models/memory_ticket.dart';
import '../models/ticket_effect.dart';
import '../models/photo_framing.dart';
import '../theme/timo_colors.dart';
import '../widgets/ui/glow_button.dart';
import '../widgets/ui/catalog_poster.dart';
import '../widgets/ui/local_image.dart';
import '../widgets/ui/paper_card.dart';
import '../state/creation_job.dart';
import '../data/creation_service.dart';
import 'memory_page_route.dart';
import 'memory_ticket_screen.dart';

/// 여섯 단계(공연 → 배경 → 인물 → 인물 추가 → 인물 조정 → 이펙트) 뒤에 '제작중' 단계.
///
/// 생성 자체는 [CreationJob] 에서 돌기 때문에 이 화면을 떠나도 취소되지 않는다.
class CreatorScreen extends StatefulWidget {
  const CreatorScreen({super.key, this.initialConcert, this.service});

  /// 카탈로그 격자에서 공연을 고르고 들어온 경우. 배경 단계부터 시작한다.
  final MemoryConcert? initialConcert;

  /// 테스트가 넣는다. 앱에서는 진짜 파이프라인을 만든다.
  final CreationService? service;

  @override
  State<CreatorScreen> createState() => _CreatorScreenState();
}

class _CreatorScreenState extends State<CreatorScreen> {
  late final service = widget.service ?? CreationService();

  /// 공연 카탈로그. '다시 시도' 는 새 Future 를 만들어 넘긴다.
  late Future<List<MemoryConcert>> _concerts;

  void _reloadConcerts() => setState(
    () => _concerts = MemoryConcertApiScope.of(context).getConcerts(),
  );
  final picker = ImagePicker();
  late int step = widget.initialConcert == null ? 0 : 1;
  late MemoryConcert? concert = widget.initialConcert;

  /// 고른 공연의 소재. 공연을 고른 순간 받기 시작해 사진 단계에 닿을 때쯤
  /// 와 있다. 받지 못하면 데모 소재로 채운다 — 소재 없는 공연이 정상이다.
  Future<ConcertKit>? _kit;

  /// 공연을 고르지 않고 사진 단계에 올 수는 없지만, 혹시 그러면 데모다. 한 번
  /// 만들어 둔다 — 빌드마다 새 Future 를 주면 FutureBuilder 가 매번 처음부터다.
  final _demoKit = Future.value(ConcertKit.demo);
  String? background;
  String? backgroundAsset;
  PhotoFraming framing = const PhotoFraming();
  final people = <Map<String, dynamic>>[];
  TicketEffect effect = TicketEffect.none;
  String status = CreatorText.processing[0];

  /// 사진 복사·보정처럼 화면을 잠가야 하는 작업이 도는 중.
  bool busy = false;

  /// Set once the job has been handed off; the route then shows the stage.
  bool submitted = false;
  MemoryTicket? result;

  bool get lastStep => step == CreatorText.totalSteps - 1;

  int get personIndex => step == 2 ? 0 : 1;

  @override
  void initState() {
    super.initState();
    // 스코프는 구독이 아니라 읽기라 initState 에서 꺼내도 된다.
    _concerts = MemoryConcertApiScope.of(context).getConcerts();
    final initial = widget.initialConcert;
    if (initial != null) _kit = _loadKit(initial);
    recoverLostPhoto();
  }

  /// 소재를 못 받아도 만들기는 이어져야 한다. 서버 소재는 있으면 좋은 것이고
  /// 데모 소재와 갤러리 사진이 늘 있다.
  Future<ConcertKit> _loadKit(MemoryConcert of) => MemoryConcertApiScope.of(
    context,
  ).getKit(of.id).then((kit) => kit.orDemo(), onError: (_) => ConcertKit.demo);

  void _selectConcert(MemoryConcert picked) => setState(() {
    concert = picked;
    _kit = _loadKit(picked);
  });

  Future<void> recoverLostPhoto() async {
    final response = await picker.retrieveLostData();
    if (!mounted || response.isEmpty) return;
    // The stage can be lost after Android process death. Never guess the recovered image role.
    if (response.files?.isNotEmpty == true) {
      OverlayService.notify(context, CreatorText.lostPhoto);
    }
  }

  void back() {
    if (busy) return;
    final first = widget.initialConcert == null ? 0 : 1;
    if (submitted || step <= first) {
      Navigator.pop(context);
    } else {
      setState(() => step--);
    }
  }

  /// 갤러리·카메라에서 사진 하나를 받아 경로를 돌려준다. 취소면 null.
  ///
  /// 실패 안내는 출처별로 다르다 — 갤러리는 사진 접근 권한, 카메라는 카메라
  /// 권한이나 카메라가 없는 기기 문제라 같은 문장으로 묶으면 무엇을 고쳐야
  /// 하는지 알 수 없다.
  Future<String?> pickPhoto(PhotoSource from) async {
    try {
      final picked = await picker.pickImage(
        source: switch (from) {
          PhotoSource.gallery => ImageSource.gallery,
          PhotoSource.camera => ImageSource.camera,
        },
        maxWidth: 2000,
        maxHeight: 2000,
      );
      return picked?.path;
    } catch (_) {
      if (mounted) {
        OverlayService.notify(context, switch (from) {
          PhotoSource.gallery => CreatorText.permissionFailed,
          PhotoSource.camera => CreatorText.cameraFailed,
        });
      }
      return null;
    }
  }

  /// [asset] 은 타일에서 고른 소재(앱 에셋 경로 또는 서버 주소). 없으면
  /// 갤러리·카메라를 묻는다.
  Future<void> selectPhotoAndProcess({KitAsset? asset}) async {
    String? source = asset?.source;
    if (source == null) {
      final from = await showPhotoSourceSheet(context);
      if (from == null || !mounted) return;
      source = await pickPhoto(from);
    }
    if (source == null || !mounted) return;
    var advance = false;
    setState(() {
      busy = true;
      status = step == 1
          ? CreatorText.processing[1]
          : CreatorText.processing[2];
    });
    String? path;
    try {
      path = await service.copyPhotoToPrivateStorage(
        source,
        asset: asset?.isAsset ?? false,
        remote: asset != null && !asset.isAsset,
      );
      if (step == 1) {
        background = path;
        backgroundAsset = asset?.source;
        framing = const PhotoFraming();
      } else {
        Map<String, dynamic> person;
        try {
          person = await service.segmentAndAnalyze(path);
        } catch (_) {
          if (!mounted) return;
          final choice = await OverlayService.choose(
            context,
            title: '인물을 분리하지 못했어요',
            message: '배경이 복잡하거나 사람이 잘 보이지 않을 수 있어요. 원본 데모는 누끼 결과가 아닙니다.',
            choices: const {
              'retry': '재시도',
              'other': '다른 사진 선택',
              'demo': '원본 사진으로 데모 진행',
            },
          );
          if (choice == 'retry') {
            person = await service.segmentAndAnalyze(path);
          } else if (choice == 'demo') {
            person = await service.analyzeOriginalForDemo(path);
          } else {
            return;
          }
        }
        // 누끼가 나와도 사람이라는 근거가 없으면 한 번 묻는다. 데모 진행은
        // 방금 스스로 고른 길이라 다시 묻지 않는다.
        if (person['segmented'] == true &&
            !CreationService.personDetected(person)) {
          if (!mounted) return;
          final choice = await OverlayService.choose(
            context,
            title: CreatorText.noPersonTitle,
            message: CreatorText.noPersonBody,
            choices: const {'keep': '이대로 진행', 'other': '다른 사진 선택'},
          );
          if (choice != 'keep') return;
        }
        person['sourceAsset'] = asset?.source;
        if (people.length > personIndex) {
          people[personIndex] = person;
        } else {
          people.add(person);
        }
        await harmonizePeople(changed: {personIndex});
        // 인물은 고르면 곧바로 다음으로 넘어간다. 고른 뒤 이 화면에 남아서 할
        // 일이 없어, '다음으로' 를 누르는 손이 한 번 더 들어갈 뿐이었다.
        advance = true;
      }
    } catch (_) {
      if (mounted) OverlayService.notify(context, CreatorText.photoFailed);
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          if (advance && !lastStep) step++;
        });
      }
    }
  }

  /// Match crops across everyone currently chosen, then re-seed the placement
  /// of any person whose image changed (plus the ones in [changed]).
  Future<void> harmonizePeople({Set<int> changed = const {}}) async {
    final reseed = {...changed, ...await service.harmonizeCrops(people)};
    for (final i in reseed) {
      if (i < people.length) {
        await service.composition.initializePlacement(people[i], i);
      }
    }
  }

  /// Hand the draft to the app-wide job and switch to the "제작중" stage.
  void submit() {
    final errors = CreationService.validateDraft(concert, background, people);
    if (errors.isNotEmpty) {
      OverlayService.notify(context, errors.join('\n'));
      return;
    }
    final draft = CreationDraft(
      concert: concert!,
      background: background!,
      people: [for (final p in people) Map<String, dynamic>.from(p)],
      effect: effect,
      framing: framing,
    );
    CreationJobScope.read(context).start(draft, service: service);
    setState(() => submitted = true);
  }

  void retry(CreationDraft draft) =>
      CreationJobScope.read(context).start(draft, service: service);

  void openResult() {
    final ticket = result;
    final made = concert;
    if (ticket == null || made == null) return;
    CreationJobScope.read(context).acknowledge();
    Navigator.pushReplacement(
      context,
      stageRoute<void>(
        MemoryTicketScreen(
          ticket: ticket,
          created: true,
          // 방금 만든 것은 아직 임시다. 마음에 안 들면 같은 공연으로 곧장
          // 다시 만들 수 있어야 한다. 이 화면은 그때 이미 교체된 뒤라 여기
          // context 를 가둬 쓸 수 없다 — 소장품 화면이 제 것을 넘겨준다.
          onEdit: (viewer) => Navigator.pushReplacement(
            viewer,
            memoryRoute<void>(CreatorScreen(initialConcert: made)),
          ),
        ),
      ),
    );
  }

  bool get canContinue => switch (step) {
    0 => concert != null,
    1 => background != null,
    2 => people.isNotEmpty,
    _ => true,
  };

  /// 데모 소재는 예전 이름 그대로, 서버 소재는 공연 것이라고 부른다.
  String tileLabel(int i, KitAsset asset) {
    if (!asset.isAsset) {
      return '${step == 1 ? CreatorText.kitStageLabel : CreatorText.kitPersonLabel} ${i + 1}';
    }
    return step == 1
        ? '${CreatorText.stageLabel} ${i + 1}'
        : i == 2
        ? CreatorText.analysisSampleLabel
        : '${CreatorText.illustrationLabel} ${i + 1}';
  }

  bool tileSelected(KitAsset asset) => step == 1
      ? backgroundAsset == asset.source
      : people.length > personIndex &&
            people[personIndex]['sourceAsset'] == asset.source;

  /// 공연 소재가 아직 오지 않았으면 기다리는 한 줄, 왔으면 그 소재로 타일을.
  Widget photoGrid() => FutureBuilder<ConcertKit>(
    future: _kit ?? _demoKit,
    builder: (context, snapshot) {
      final kit = snapshot.data;
      if (kit == null) return const _KitLoading();
      return photoGridFor(step == 1 ? kit.backgrounds : kit.people);
    },
  );

  Widget photoGridFor(List<KitAsset> assets) {
    final chosen = step == 1
        ? background
        : people.length > personIndex
        ? people[personIndex]['path'] as String
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: CreatorLayout.gridSpacing,
          mainAxisSpacing: CreatorLayout.gridSpacing,
          childAspectRatio: CreatorLayout.photoTileAspect,
          children: [
            for (var i = 0; i < assets.length; i++)
              Reveal(
                index: i,
                scaleFrom: 0.94,
                child: SelectionTile(
                  label: tileLabel(i, assets[i]),
                  selected: tileSelected(assets[i]),
                  onTap: () => selectPhotoAndProcess(asset: assets[i]),
                  child: _KitImage(assets[i]),
                ),
              ),
            Reveal(
              index: assets.length,
              scaleFrom: 0.94,
              child: SelectionTile(
                label: CreatorText.addPhotoLabel,
                selected: false,
                muted: true,
                onTap: () => selectPhotoAndProcess(),
                child: const Center(
                  child: Icon(
                    Icons.add_rounded,
                    size: 34,
                    color: TimoColors.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (chosen != null) ...[
          const SizedBox(height: 22),
          Reveal(
            key: ValueKey('chosen-$step-$chosen'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionLabel(step == 1 ? '선택한 사진' : '고른 인물'),
                const SizedBox(height: 10),
                // 인물 단계에서는 고른 사진만 보여준다. 옮기고 키우는 일은
                // 인물을 다 고른 뒤 제 단계에서 한 자리에 모아 한다.
                if (step == 1) backgroundEditor(chosen) else personPreview(),
                if (step > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: PaperCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      radius: 12,
                      elevated: false,
                      color: TimoColors.paperMuted,
                      child: Text(
                        personStatus(personIndex),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: TimoColors.inkSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 인물 단계에서 방금 고른 누끼를 확인만 하는 자리. 조작은 없다.
  Widget personPreview() => PaperCard(
    padding: const EdgeInsets.all(12),
    radius: 14,
    elevated: false,
    color: TimoColors.paperMuted,
    child: SizedBox(
      height: CreatorLayout.personPreviewHeight,
      child: LocalImage(
        people[personIndex]['path'] as String,
        fit: BoxFit.contain,
      ),
    ),
  );

  String personStatus(int index) {
    final p = people[index];
    final a = p['analysis'] as Map;
    final cropped = p['upperBodyCropped'] == true
        ? '상대 인물 골격에 맞춰 자르기 완료\n'
        : '';
    final segmentation = p['segmented'] != true
        ? '원본 사진 데모'
        : p['segmentationEngine'] == 'modnet'
        ? '정밀 누끼 완료'
        : '기본 누끼로 처리했어요';
    return '$cropped$segmentation\n${a['poseAvailable'] == true ? 'MediaPipe · ${CreationService.cropLabel(a['cropType'] as String)}' : '자세 분석 불가 · 크기 기반 배치'}\n${a['faceAvailable'] == true ? '얼굴 감지 완료' : '얼굴 감지 불가 · 크기 기반 배치'}';
  }

  Widget backgroundEditor(String path) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('프레임 채우기'),
            selected: !framing.contain,
            onSelected: (_) => setState(() => framing = const PhotoFraming()),
          ),
          ChoiceChip(
            label: const Text('전체 사진 넣기'),
            selected: framing.contain,
            onSelected: (_) =>
                setState(() => framing = const PhotoFraming(contain: true)),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(TimoRadii.tile),
            child: PhotoFrame(
              path: path,
              framing: framing,
              onChanged: (value) => setState(() => framing = value),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        framing.contain
            ? '사진 전체를 보여주고 남는 공간은 단색으로 채워요.'
            : '사진을 드래그해 이동하고, 두 손가락이나 슬라이더로 확대하세요.',
        style: const TextStyle(fontSize: 12, color: TimoColors.inkSecondary),
      ),
      if (!framing.contain)
        Row(
          children: [
            Text('${framing.scale.toStringAsFixed(1)}배'),
            Expanded(
              child: Slider(
                value: framing.scale,
                min: 1,
                max: 3,
                label: '사진 확대 ${framing.scale.toStringAsFixed(1)}배',
                onChanged: (value) =>
                    setState(() => framing = framing.copyWith(scale: value)),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => framing = const PhotoFraming()),
              child: const Text('초기화'),
            ),
          ],
        ),
    ],
  );

  Widget compositionEditor() => PersonPlacementEditor(
    background: background!,
    framing: framing,
    people: people,
    onChanged: (index, changes) =>
        setState(() => people[index].addAll(changes)),
  );

  Widget concertList() => AsyncBoundary<List<MemoryConcert>>(
    future: _concerts,
    onRetry: _reloadConcerts,
    loading: const ConcertListSkeleton(),
    builder: (context, concerts) {
      // 이미 만든 티켓은 내리지 않는다. 티켓 한 장에 소장품은 하나뿐이라
      // 골라 봤자 예전 것을 덮어쓸 뿐이다. 고치는 길은 컬렉션 쪽에 있다.
      //
      // 기준은 둘이다 — 서버가 아는 것(`goodsId`, 다른 기기에서 만든 것 포함)과
      // 이 기기에만 있는 확정 전 임시본. 서버만 보면 임시본을 덮어쓰고, 기기만
      // 보면 다른 기기에서 만든 티켓을 골라 서버가 409 로 막는다.
      final made = {
        for (final t in TicketStoreScope.of(context).readAll()) t.ticketId,
      };
      final pickable = [
        for (final c in concerts)
          if (c.goodsId == null && !made.contains(c.ticketId)) c,
      ];
      if (pickable.isEmpty) return const _NoConcerts();
      return Column(
        children: [
          for (var i = 0; i < pickable.length; i++)
            Reveal(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: ConcertCard(
                  title: pickable[i].title,
                  date: [pickable[i].date, ?pickable[i].time].join(' '),
                  venue: pickable[i].venue,
                  poster: pickable[i].poster,
                  selected: concert?.id == pickable[i].id,
                  onTap: () => _selectConcert(pickable[i]),
                ),
              ),
            ),
        ],
      );
    },
  );

  /// Live previews: every tile runs the real stage effect renderer.
  Widget effectGrid() => Column(
    children: [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: CreatorLayout.gridSpacing,
        mainAxisSpacing: CreatorLayout.gridSpacing,
        childAspectRatio: CreatorLayout.effectTileAspect,
        children: [
          for (var i = 0; i < TicketEffect.values.length; i++)
            Reveal(
              index: i,
              scaleFrom: 0.94,
              child: SelectionTile(
                label: TicketEffect.values[i].label,
                selected: effect == TicketEffect.values[i],
                onTap: () => setState(() => effect = TicketEffect.values[i]),
                child: _EffectPreview(effect: TicketEffect.values[i]),
              ),
            ),
        ],
      ),
      if (effect == TicketEffect.godRays)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              stageRoute<void>(const VolumetricLab()),
            ),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('빛줄기 미리보기·조절'),
          ),
        ),
      const SizedBox(height: 16),
      const Text(
        '선택한 공연의 공식 이머시브 영상이 자동으로 적용돼요.\n완성된 티켓을 길게 눌러 영상을 볼 수 있어요.',
        style: TextStyle(fontSize: 12, color: TimoColors.inkSecondary),
      ),
    ],
  );

  Widget stepContent() {
    if (step == 0) return concertList();
    if (step < 4) return photoGrid();
    if (step == 4) return compositionEditor();
    return effectGrid();
  }

  /// Short inline wait while a picked photo is analysed.
  Widget photoProcessingView() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const ProcessingOrbit(),
        const SizedBox(height: 32),
        Reveal(
          key: ValueKey(status),
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w600,
              color: TimoColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          CreatorText.onDeviceNote,
          style: const TextStyle(fontSize: 12, color: TimoColors.inkTertiary),
        ),
        const SizedBox(height: 28),
        if (busy)
          const Center(
            child: CircularProgressIndicator(semanticsLabel: '처리 중'),
          ),
      ],
    ),
  );

  Widget header() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text(
        CreatorText.brand,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 20,
          letterSpacing: 1.5,
          color: TimoColors.brandMid,
        ),
      ),
      if (!submitted) StepProgress(step: step, total: CreatorText.totalSteps),
    ],
  );

  Widget stepView(BuildContext context) => SingleChildScrollView(
    key: ValueKey(step),
    padding: const EdgeInsets.fromLTRB(
      CreatorLayout.pagePadding,
      16,
      CreatorLayout.pagePadding,
      28,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header(),
        const SizedBox(height: 18),
        StaggeredText(
          CreatorText.titles[step],
          key: ValueKey('title$step'),
          style: Theme.of(context).textTheme.headlineMedium!,
        ),
        const SizedBox(height: 8),
        Reveal(
          key: ValueKey('subtitle$step'),
          index: 1,
          child: Text(
            CreatorText.subtitles[step],
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 22),
        stepContent(),
      ],
    ),
  );

  Widget stageView(CreationJobState job) {
    final phase = result != null
        ? ProcessingPhase.done
        : job is CreationFailed
        ? ProcessingPhase.failed
        : ProcessingPhase.running;
    return Padding(
      key: const ValueKey('stage'),
      padding: const EdgeInsets.fromLTRB(
        CreatorLayout.pagePadding,
        16,
        CreatorLayout.pagePadding,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header(),
          const SizedBox(height: 18),
          Expanded(
            child: ProcessingStage(
              phase: phase,
              status: switch (job) {
                CreationRunning(:final status) => status,
                CreationFailed(:final message) => message,
                _ => CreatorText.processingTitle,
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget? bottomBar(CreationJobState job) {
    if (busy) return null;
    Widget? primary;
    Widget? secondary;
    if (submitted) {
      if (result != null) {
        primary = GlowButton(
          label: CreatorText.finishLabel,
          icon: Icons.card_giftcard_rounded,
          onPressed: openResult,
        );
      } else if (job is CreationFailed) {
        primary = GlowButton(
          label: CreatorText.retryLabel,
          icon: Icons.refresh_rounded,
          onPressed: () => retry(job.draft),
        );
      } else {
        primary = const GlowButton(
          label: CreatorText.finishLabel,
          onPressed: null,
        );
      }
    } else if (step == 2) {
      // 인물은 고르는 순간 넘어간다. 아래에서 한 번 더 누를 것이 없다.
      return null;
    } else {
      // 인물을 더 넣는 단계에서도 고르면 저절로 넘어간다. 남는 선택은 "안
      // 넣는다" 뿐이라 건너뛰기만 세운다.
      if (step != 3) {
        primary = GlowButton(
          // 공연을 고르는 첫 단계에서는 이 버튼이 곧 시작 버튼이다.
          label: step == 0 ? CreatorText.concertAction : CreatorText.nextLabel,
          onPressed: canContinue
              ? () => lastStep ? submit() : setState(() => step++)
              : null,
        );
      }
      // 건너뛰기가 뜨는 곳은 두 군데다 — 인물을 더 안 넣을 때와, 효과 없이
      // 만들 때. 인물 조정 단계는 건너뛸 것이 없다(안 만지면 그대로 간다).
      if (step == 3 || lastStep) {
        // 글자만 있으면 버튼으로 안 읽혀 그냥 지나친다. 주 버튼(채운 초록)과
        // 나란히 서도 한쪽만 주인공이도록 테두리만 두른다.
        secondary = OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(CreatorLayout.skipButtonHeight),
            foregroundColor: TimoColors.brandMid,
            side: const BorderSide(color: TimoColors.brandMid, width: 1.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: () {
            if (step == 3) {
              if (people.length > 1) {
                people.removeLast();
                harmonizePeople().then((_) {
                  if (mounted) setState(() {});
                });
              }
              setState(() => step++);
            } else {
              effect = TicketEffect.none;
              submit();
            }
          },
          child: const Text(CreatorText.skipLabel),
        );
      }
    }
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        CreatorLayout.pagePadding,
        8,
        CreatorLayout.pagePadding,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: primary == null ? 0 : 8,
        children: [?primary, ?secondary],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // job 이 알릴 때 이 화면도 같이 리빌드된다.
    final job = CreationJobScope.of(context).state;
    // 완성된 소장품은 job 이 다른 곳(완료 배너)에서 확인돼 idle 로 돌아가도
    // 이 화면에 남아 있어야 한다 — '보러 가기' 가 눌릴 때까지는 결과 화면이다.
    if (job is CreationDone && submitted) result = job.ticket;
    final first = widget.initialConcert == null ? 0 : 1;
    return PopScope(
      canPop: !busy && (submitted || step == first),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(CreatorText.appBarTitle),
          leading: IconButton(
            tooltip: CreatorText.backTooltip,
            onPressed: busy ? null : back,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: Motion.base,
            switchInCurve: Motion.emphasized,
            switchOutCurve: Motion.standard,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: busy
                ? KeyedSubtree(
                    key: const ValueKey('processing'),
                    child: photoProcessingView(),
                  )
                : submitted
                ? stageView(job)
                : stepView(context),
          ),
        ),
        bottomNavigationBar: bottomBar(job),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 3,
        height: 14,
        decoration: BoxDecoration(
          color: TimoColors.brandMid,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          color: TimoColors.ink,
        ),
      ),
    ],
  );
}

/// Miniature stage running the real effect renderer.
class _EffectPreview extends StatelessWidget {
  const _EffectPreview({required this.effect});
  final TicketEffect effect;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E1426), Color(0xFF070A12)],
          ),
        ),
      ),
      // Stage floor.
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: 26,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
          ),
        ),
      ),
      EffectLayer(effect: effect),
      Positioned(
        left: 10,
        bottom: 8,
        child: Text(
          effect.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
      if (effect == TicketEffect.none)
        const Center(
          child: Icon(
            Icons.block_rounded,
            size: 34,
            color: TimoColors.textTertiary,
          ),
        ),
    ],
  );
}

/// 만들 수 있는 공연이 하나도 없을 때. 목록 대신 같은 자리에 선다.
class _NoConcerts extends StatelessWidget {
  const _NoConcerts();

  @override
  Widget build(BuildContext context) => SizedBox(
    // 단계 화면의 Column 은 왼쪽 정렬이라(제목·설명이 그렇다) 이 안내를 그대로
    // 두면 글자 폭만큼만 차지해 왼쪽으로 붙는다. 화면 폭을 다 차지해야
    // 마스코트와 글이 가운데에 선다.
    width: double.infinity,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Reveal(child: TimoMascot.sad(size: 140)),
          const SizedBox(height: 24),
          const Reveal(
            index: 1,
            child: Text(
              CreatorText.noConcertsTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: TimoColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Reveal(
            index: 2,
            child: Text(
              CreatorText.noConcertsBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: TimoColors.inkSecondary),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 소재 타일 한 장. 앱 에셋이든 서버 주소든 같은 모양으로 채운다.
class _KitImage extends StatelessWidget {
  const _KitImage(this.asset);
  final KitAsset asset;

  @override
  Widget build(BuildContext context) {
    final image = catalogPosterImage(asset.source);
    if (image == null) return const ColoredBox(color: TimoColors.placeholder);
    return Image(
      image: image,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const ColoredBox(color: TimoColors.placeholder),
    );
  }
}

/// 공연 소재를 받는 동안. 타일 자리를 비워 두고 한 줄만 말한다 — 데모 소재를
/// 먼저 그리면 곧 공연 소재로 바뀌어 눈앞에서 타일이 갈린다.
class _KitLoading extends StatelessWidget {
  const _KitLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 40),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 10),
        Text(
          CreatorText.kitLoading,
          style: TextStyle(fontSize: 13, color: TimoColors.inkSecondary),
        ),
      ],
    ),
  );
}
