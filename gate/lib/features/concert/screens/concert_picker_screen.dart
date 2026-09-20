import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/timo_logo.dart';
import '../../../core/widgets/timo_mascot.dart';
import '../constants.dart';
import '../data/concert_api.dart';
import '../models/concert_summary.dart';
import '../state/concert_api_scope.dart';
import '../widgets/concert_list_skeleton.dart';
import '../widgets/concert_tile.dart';

/// 검표할 공연을 고르는 화면. 로그인 다음, 스캔 전에 한 번 거친다.
///
/// 서버 공연 목록을 받아 오늘 공연이 위로 오게 늘어놓고, 한 줄을 누르면
/// [onSelected] 로 알린다. 화면은 고른 공연을 어디에 저장하고 다음에 무엇을
/// 보일지 모른다 — 앱(App)이 저장하고 스캔 화면으로 바꿔 그린다. 스캔 화면의
/// '공연 변경' 으로 다시 왔을 때는 이 화면이 라우트로 떠 있어, 고르면 앱이
/// 닫아 준다.
///
/// 검색은 서버에 맡긴다(공연명 부분 일치). 글자를 칠 때마다 요청하지 않고
/// 잠깐 기다렸다가 마지막 글자 기준으로 한 번 보낸다.
///
/// 로딩·실패 분기는 [AsyncBoundary] 가 맡고 이 화면은 성공 모양만 그린다.
///
/// [now] 는 테스트에서 '오늘' 판정을 고정하기 위해 받는다. 앱에서는 넘기지 않는다.
class ConcertPickerScreen extends StatefulWidget {
  const ConcertPickerScreen({
    super.key,
    required this.onSelected,
    this.api,
    this.now,
    this.trailing,
  });

  final ValueChanged<ConcertSummary> onSelected;

  /// 직접 넘기면 그걸 쓰고(테스트), 안 넘기면 [ConcertApiScope] 에서 받는다(앱).
  final ConcertApi? api;

  final DateTime Function()? now;

  /// 앱바 오른쪽에 둘 것(로그아웃 버튼). 첫 화면으로 뜰 때만 앱이 넘긴다 —
  /// 스캔 화면에서 바꾸러 들어왔을 때는 뒤로 가기가 있어 필요 없다.
  final Widget? trailing;

  @override
  State<ConcertPickerScreen> createState() => _ConcertPickerScreenState();
}

class _ConcertPickerScreenState extends State<ConcertPickerScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  /// 지금 화면에 반영된 검색어. 컨트롤러의 글자와 다를 수 있다(입력 중).
  String _keyword = '';

  late Future<List<ConcertSummary>> _future;

  /// 첫 요청을 이미 만들었는지. [didChangeDependencies] 는 여러 번 불린다.
  bool _started = false;

  ConcertApi get _api => widget.api ?? ConcertApiScope.of(context);

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Scope 를 읽어야 해서 initState 가 아니라 여기서 첫 요청을 만든다. 이후
    // 의존성이 바뀌어 다시 불려도 진행 중인 요청을 버리지 않는다.
    if (!_started) {
      _started = true;
      _future = _load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ConcertSummary>> _load() =>
      _api.findAll(keyword: _keyword.isEmpty ? null : _keyword);

  void _reload() => setState(() => _future = _load());

  void _onSearchChanged() {
    // 지우기 버튼이 보일지가 글자에 달려 있어 매번 다시 그린다.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(ConcertMetrics.searchDebounce, () {
      final next = _searchController.text.trim();
      if (!mounted || next == _keyword) return;
      _keyword = next;
      _reload();
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    if (_keyword.isEmpty) return;
    _keyword = '';
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const TimoLogo(height: 22),
        actions: [if (widget.trailing != null) widget.trailing!],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppMetrics.pagePadding,
              12,
              AppMetrics.pagePadding,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ConcertStrings.title, style: textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(ConcertStrings.subtitle, style: textTheme.bodySmall),
                const SizedBox(height: 16),
                _SearchField(
                  controller: _searchController,
                  onClear: _clearSearch,
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncBoundary<List<ConcertSummary>>(
              future: _future,
              onRetry: _reload,
              loading: const ConcertListSkeleton(),
              builder: (context, concerts) {
                if (concerts.isEmpty) {
                  return _EmptyView(searching: _keyword.isNotEmpty);
                }
                final now = _now;
                final sorted = ConcertSummary.sortedForGate(concerts, now: now);
                return ListView.separated(
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const Divider(
                    indent: AppMetrics.pagePadding,
                    endIndent: AppMetrics.pagePadding,
                  ),
                  itemBuilder: (context, index) {
                    final concert = sorted[index];
                    return ConcertTile(
                      concert: concert,
                      isToday: concert.isOn(now),
                      onPressed: () => widget.onSelected(concert),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 공연명 검색칸. 글자가 있으면 오른쪽에 지우기 버튼이 뜬다.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onClear});

  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: ConcertStrings.searchHint,
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: ConcertStrings.clearSearch,
                icon: const Icon(Icons.cancel, color: AppColors.textDisabled),
                onPressed: onClear,
              ),
        // 아이콘이 들어가는 칸은 위아래 여백을 줄여야 로그인 입력칸과 높이가
        // 비슷해진다.
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }
}

/// 받아 온 목록이 비었을 때. 검색 중인지에 따라 문구가 다르다 — 검색 결과가
/// 없는 것과 서버에 공연이 하나도 없는 것은 운영자가 할 일이 다르다.
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppMetrics.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TimoMascot.sad(),
            const SizedBox(height: AppMetrics.inlineGap),
            Text(
              searching ? ConcertStrings.emptyForKeyword : ConcertStrings.empty,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
