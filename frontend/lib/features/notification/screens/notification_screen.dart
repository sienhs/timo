import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../constants.dart';
import '../data/notification_api.dart';
import '../models/app_notification.dart';
import '../notification_destination.dart';
import '../state/notification_api_scope.dart';
import '../widgets/notification_tile.dart';

/// 알림함. 마이페이지 상단의 알림 아이콘으로 들어온다. 최신순이고 아래로 내리면
/// 이어서 받는다. 알림을 누르면 읽음으로 바꾸고, 푸시를 눌렀을 때와 같은 규칙
/// ([destinationFor])으로 고른 화면으로 간다.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key, this.now});

  /// 시각 표기의 기준. 테스트에서 시계를 고정하려고 받는다.
  final DateTime? now;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late final NotificationApi _api = NotificationApiScope.of(context);
  final _scrollController = ScrollController();
  final _items = <AppNotification>[];

  late Future<void> _firstLoad;

  /// 다음 쪽을 달랄 때 넘길 값. 더 받을 게 없으면 null 이다.
  int? _cursor;
  bool _hasNext = false;

  /// 안 읽은 알림 수. **화면에 받아 둔 것만 세지 않고 서버에 묻는다.** 아직 안
  /// 받은 쪽에 안 읽은 알림이 남아 있을 수 있어서다.
  int _unreadCount = 0;

  bool _loadingMore = false;
  bool _loadMoreFailed = false;

  @override
  void initState() {
    super.initState();
    _firstLoad = _loadFirstPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    final page = await _api.fetchNotifications();
    final unread = await _api.fetchUnreadCount();
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(page.items);
      _cursor = page.nextCursor;
      _hasNext = page.hasNext;
      _unreadCount = unread;
      _loadMoreFailed = false;
    });
    _loadMoreIfNotScrollable();
  }

  /// 받은 목록이 화면을 못 채웠으면 이어서 다음 쪽을 받는다. 목록이 짧으면 스크롤이
  /// 안 생겨 끝에 닿는 순간이 오지 않기 때문이다. 스크롤 거리는 그려진 뒤에야 알 수
  /// 있어 다음 프레임에서 본다.
  void _loadMoreIfNotScrollable() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent <= 0) _loadMore();
    });
  }

  void _retryFirstLoad() => setState(() => _firstLoad = _loadFirstPage());

  /// 목록 끝이 다가오면 다음 쪽을 미리 받는다.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final remaining =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    if (remaining <= NotificationMetrics.loadMoreThreshold) _loadMore();
  }

  Future<void> _loadMore() async {
    // 이어 받기가 실패한 뒤에는 저절로 다시 시도하지 않는다. 스크롤이 끝에 있는
    // 동안 같은 실패를 반복하기 때문이다. 아래쪽 안내를 눌러야 다시 시도한다.
    if (_loadingMore || _loadMoreFailed || !_hasNext) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _api.fetchNotifications(cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        // 빈 쪽이 오면 더 받을 게 없다고 본다. 서버가 그럴 일은 없지만, 빈 쪽을
        // 주면서 다음이 있다고 하면 위 검사가 끝없이 다음 쪽을 부른다.
        _hasNext = page.hasNext && page.items.isNotEmpty;
      });
      _loadMoreIfNotScrollable();
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadMoreFailed = true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _retryLoadMore() {
    setState(() => _loadMoreFailed = false);
    _loadMore();
  }

  /// 알림을 눌렀을 때. 읽음으로 바꾸고 그 알림이 가리키는 화면으로 간다.
  void _open(AppNotification notification) {
    if (!notification.read) _markReadLocally(notification);

    final destination = destinationFor(
      notification.linkType,
      notification.linkId,
    );
    // 갈 곳이 없는 알림(서버가 새로 만든 종류 등)은 읽음 처리만 하고 만다.
    if (destination == null) return;
    Navigator.pushNamed(
      context,
      destination.routeName,
      arguments: destination.arguments,
    );
  }

  /// 화면을 먼저 바꾸고 서버에는 뒤따라 알린다. 응답을 기다리면 그 사이 다음
  /// 화면으로 넘어가 돌아올 때까지 안 읽음으로 보인다. 서버에 못 알려도 되돌리지
  /// 않고 다음에 받을 때 맞춘다.
  void _markReadLocally(AppNotification notification) {
    setState(() {
      final index = _items.indexWhere((n) => n.id == notification.id);
      if (index != -1) _items[index] = _items[index].asRead();
      if (_unreadCount > 0) _unreadCount--;
    });
    unawaited(_tellServerRead(notification.id));
  }

  Future<void> _tellServerRead(int id) async {
    try {
      await _api.markRead(id);
    } on ApiException {
      // 위 설명대로 무시한다.
    }
  }

  /// 모두 읽음. 이쪽은 실패하면 되돌린다 — 목록 전체가 한 번에 바뀌어서, 안
  /// 되돌리면 사실은 안 읽은 알림이 통째로 읽은 것처럼 보인다.
  Future<void> _markAllRead() async {
    final previousItems = List.of(_items);
    final previousUnread = _unreadCount;

    setState(() {
      for (var i = 0; i < _items.length; i++) {
        if (!_items[i].read) _items[i] = _items[i].asRead();
      }
      _unreadCount = 0;
    });

    try {
      await _api.markAllRead();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(previousItems);
        _unreadCount = previousUnread;
      });
      showErrorSnackBar(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: () => Navigator.maybePop(context)),
            Expanded(
              child: AsyncBoundary<void>(
                future: _firstLoad,
                onRetry: _retryFirstLoad,
                loading: const _LoadingSkeleton(),
                builder: (context, _) =>
                    _items.isEmpty ? const _EmptyView() : _buildList(),
              ),
            ),
          ],
        ),
      ),
      // 안 읽은 알림이 없으면 아예 내린다. 흐리게 두면 누를 일 없는 버튼이 마지막
      // 알림을 계속 가린다.
      floatingActionButton: _unreadCount == 0
          ? null
          : _MarkAllReadButton(onPressed: _markAllRead),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.only(
        bottom: NotificationMetrics.bottomActionClearance,
      ),
      itemCount: _items.length + 1,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, thickness: 1, color: AppColors.border),
      itemBuilder: (context, index) {
        if (index == _items.length) return _buildFooter();
        final notification = _items[index];
        return NotificationTile(
          notification: notification,
          now: widget.now,
          onTap: () => _open(notification),
        );
      },
    );
  }

  /// 목록 끝. 더 받는 중이거나, 실패했으면 다시 시도할 자리다.
  Widget _buildFooter() {
    if (_loadMoreFailed) {
      return Center(
        child: TextButton(
          onPressed: _retryLoadMore,
          child: const Text(NotificationStrings.loadMoreFailed),
        ),
      );
    }
    if (!_hasNext) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// 뒤로가기와 제목. 마이페이지 상단 바와 같은 높이·아이콘 크기다.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: NotificationMetrics.topBarHeight,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: NotificationStrings.back,
            iconSize: NotificationMetrics.topBarIconSize,
            color: AppColors.textPrimary,
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Text(
              NotificationStrings.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          // 제목을 가운데에 두려고 뒤로가기와 같은 너비를 비워 둔다.
          const SizedBox(width: NotificationMetrics.topBarHeight),
        ],
      ),
    );
  }
}

/// 오른쪽 아래 '모두 읽음'. 다른 행동 버튼과 같은 초록 채움 버튼이지만 목록 위에
/// 떠 있어 가로를 다 채우지 않는다 — 최소 너비만 풀고 높이는 공통 값(짧은 버튼)을 쓴다.
class _MarkAllReadButton extends StatelessWidget {
  const _MarkAllReadButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppMetrics.compactButtonMinHeight),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: const Text(NotificationStrings.markAllRead),
    );
  }
}

/// 받은 알림이 하나도 없을 때.
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NotificationMetrics.horizontalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 48,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 16),
            Text(
              NotificationStrings.empty,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              NotificationStrings.emptyHint,
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

/// 불러오는 동안 세우는 뼈대. 빈 화면에 동그라미만 도는 것보다 목록이 곧 온다는
/// 것이 드러난다.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  static const _rows = 6;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _rows,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, thickness: 1, color: AppColors.border),
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: NotificationMetrics.horizontalPadding,
          vertical: NotificationMetrics.tileVerticalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBar(widthFactor: 0.85),
            SizedBox(height: 10),
            _SkeletonBar(widthFactor: 0.3, height: 10),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.widthFactor, this.height = 14});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
