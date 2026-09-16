import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/memory_ticket.dart';
import '../motion/motion_tokens.dart';
import '../screens/memory_page_route.dart';
import '../screens/memory_ticket_screen.dart';
import '../state/creation_job.dart';
import '../state/creation_job_scope.dart';
import 'creator/completion_banner.dart';

/// '제작중' job 이 끝나면 지금 떠 있는 화면 위에 알림 배너를 떨군다.
///
/// 누르면 컬렉션 위로 소장품이 열리고, 위로 밀거나 기다리면 사라진다.
///
/// [MaterialApp.builder] 자리에 놓이므로 이 위젯의 context 아래에 Navigator 가
/// 있다 — `Navigator.of(context)` 로는 못 찾는다. 그래서 앱이 만든
/// [navigatorKey] 를 받아 그걸로 연다.
class CreationNotificationHost extends StatefulWidget {
  const CreationNotificationHost({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  static const autoHide = Duration(seconds: 8);

  @override
  State<CreationNotificationHost> createState() =>
      _CreationNotificationHostState();
}

class _CreationNotificationHostState extends State<CreationNotificationHost> {
  CreationJob? _job;
  MemoryTicket? _shown;
  Timer? _hide;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final job = CreationJobScope.read(context);
    if (identical(job, _job)) return;
    _job?.removeListener(_onJobChanged);
    _job = job..addListener(_onJobChanged);
  }

  void _onJobChanged() {
    final state = _job?.state;
    if (state is CreationDone) {
      _show(state.ticket);
    } else if (state is CreationIdle) {
      _dismiss();
    }
  }

  void _show(MemoryTicket ticket) {
    _hide?.cancel();
    setState(() => _shown = ticket);
    _hide = Timer(CreationNotificationHost.autoHide, _dismiss);
  }

  void _dismiss() {
    _hide?.cancel();
    if (mounted && _shown != null) setState(() => _shown = null);
  }

  void _open() {
    final ticket = _shown;
    _dismiss();
    if (ticket == null) return;
    _job?.acknowledge();
    widget.navigatorKey.currentState?.pushAndRemoveUntil(
      stageRoute<void>(MemoryTicketScreen(ticket: ticket, created: true)),
      (route) => route.isFirst,
    );
  }

  @override
  void dispose() {
    _hide?.cancel();
    _job?.removeListener(_onJobChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 8;
    final shown = _shown;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: top,
          left: 14,
          right: 14,
          child: Material(
            type: MaterialType.transparency,
            child: AnimatedSwitcher(
              duration: Motion.slow,
              switchInCurve: Motion.overshoot,
              switchOutCurve: Motion.standard,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, -0.6),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: shown == null
                  ? const SizedBox.shrink()
                  : CompletionBanner(
                      key: ValueKey(shown.ticketId),
                      title: CreatorText.notificationTitle,
                      body: CreatorText.notificationBody,
                      timeLabel: CreatorText.notificationTime,
                      onTap: _open,
                      onDismiss: _dismiss,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
