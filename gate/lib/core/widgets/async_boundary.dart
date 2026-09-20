import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

/// 비동기 데이터의 로딩·실패 분기를 화면 대신 맡는다. 팬 앱
/// `core/widgets/async_boundary.dart` 를 그대로 가져왔다.
///
/// 화면은 성공했을 때의 모양([builder])만 적고, 기다리는 동안 무엇을 보일지
/// ([loading])와 실패하면 어떻게 되돌릴지([onRetry])만 넘긴다. 로딩·실패
/// 분기가 화면마다 따로 있으면 문구와 버튼이 화면마다 조금씩 달라진다.
///
/// [future] 가 바뀌면(새로 고침·다시 시도) 새 결과를 기다리되, 이미 보여 주던
/// 데이터가 있으면 그대로 둔다. 다시 불러올 때마다 목록이 회색 자리로
/// 깜빡이면 화면이 비었다가 채워지는 것처럼 보인다.
///
/// 실패 문구는 [ApiException.message] 를 그대로 쓴다. 서버 문구·네트워크 상황
/// 문구가 이미 화면용으로 번역돼 있다. 그 외 예외는 일반 문구로 덮는다.
class AsyncBoundary<T> extends StatefulWidget {
  const AsyncBoundary({
    super.key,
    required this.future,
    required this.builder,
    required this.onRetry,
    this.loading = const Center(child: CircularProgressIndicator()),
  });

  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;

  /// '다시 시도' 를 눌렀을 때. 보통 새 [future] 를 만들어 다시 넘긴다.
  final VoidCallback onRetry;

  final Widget loading;

  static const retryLabel = '다시 시도';
  static const fallbackMessage = '불러오지 못했어요. 잠시 후 다시 시도해주세요.';

  @override
  State<AsyncBoundary<T>> createState() => _AsyncBoundaryState<T>();
}

class _AsyncBoundaryState<T> extends State<AsyncBoundary<T>> {
  T? _data;
  bool _hasData = false;
  Object? _error;

  /// 지금 기다리는 Future. 결과가 왔을 때 이미 다른 것으로 바뀌었으면
  /// (빠르게 두 번 다시 시도) 늦게 온 결과는 버린다.
  Future<T>? _tracked;

  @override
  void initState() {
    super.initState();
    _track(widget.future);
  }

  @override
  void didUpdateWidget(covariant AsyncBoundary<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.future != oldWidget.future) _track(widget.future);
  }

  void _track(Future<T> future) {
    _tracked = future;
    _error = null;
    future.then<void>(
      (data) {
        if (!mounted || _tracked != future) return;
        setState(() {
          _data = data;
          _hasData = true;
          _error = null;
        });
      },
      onError: (Object error) {
        if (!mounted || _tracked != future) return;
        setState(() => _error = error);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return _ErrorView(message: _messageOf(error), onRetry: widget.onRetry);
    }
    if (_hasData) return widget.builder(context, _data as T);
    return widget.loading;
  }

  static String _messageOf(Object error) =>
      error is ApiException ? error.message : AsyncBoundary.fallbackMessage;
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppMetrics.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: AppMetrics.inlineGap),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppMetrics.inlineGap),
            TextButton(
              onPressed: onRetry,
              child: const Text(AsyncBoundary.retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
