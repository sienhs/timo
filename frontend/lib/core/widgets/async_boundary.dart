import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../theme/app_colors.dart';

/// 비동기 데이터의 로딩·실패 분기를 화면 대신 맡는다. 화면은 성공 모양([builder])
/// 과 [loading]·[onRetry] 만 넘긴다. [future] 가 바뀌어도 이미 보여 주던 데이터는
/// 그대로 두고, 실패 문구는 [ApiException.message] 를 쓰며 그 외는 일반 문구다.
class AsyncBoundary<T> extends StatefulWidget {
  const AsyncBoundary({
    super.key,
    required this.future,
    required this.builder,
    required this.onRetry,
    this.loading = const Center(child: CircularProgressIndicator()),
    this.error,
  });

  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;

  /// '다시 시도' 를 눌렀을 때. 보통 새 [future] 를 만들어 다시 넘긴다.
  final VoidCallback onRetry;

  final Widget loading;

  /// 실패했을 때 기본 문구·다시 시도 대신 보여 줄 것. 같은 데이터를 두 곳에서
  /// 그릴 때 한쪽만 실패를 알리고 다른 쪽은 비워 두는 데 쓴다.
  final Widget? error;

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
  /// (빠르게 두 번 새로 고침) 늦게 온 결과는 버린다.
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
      return widget.error ??
          _ErrorView(message: _messageOf(error), onRetry: widget.onRetry);
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text(AsyncBoundary.retryLabel),
          ),
        ],
      ),
    );
  }
}
