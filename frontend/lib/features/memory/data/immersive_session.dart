import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Lifecycle of one immersive playback, shared between the card (which owns
/// the pointer) and the fullscreen page (which owns the pixels).
enum ImmersivePhase {
  /// Finger still down: video loops.
  held,

  /// Finger lifted: the current pass plays to its end.
  lingering,

  /// Page is animating out; playback stops.
  closing,
}

class ImmersiveSession extends ChangeNotifier {
  ImmersiveSession({
    required this.controller,
    required this.ready,
    required this.failed,
    required this.transition,
  });

  /// Null when the video never initialised.
  final VideoPlayerController? controller;
  bool ready, failed;
  final Map<String, dynamic> transition;

  ImmersivePhase _phase = ImmersivePhase.held;
  bool _graceful = false;
  ImmersivePhase get phase => _phase;

  /// True when the close should take the long, symmetric exit (video ended)
  /// rather than the quick cancel exit.
  bool get graceful => _graceful;
  bool get playable => ready && !failed && controller != null;

  /// Video finished initialising while the page is already up.
  void markReady() {
    ready = true;
    failed = false;
    notifyListeners();
  }

  void markFailed() {
    failed = true;
    notifyListeners();
  }

  void release() {
    if (_phase != ImmersivePhase.held) return;
    _phase = ImmersivePhase.lingering;
    notifyListeners();
  }

  void close({bool graceful = false}) {
    if (_phase == ImmersivePhase.closing) return;
    _phase = ImmersivePhase.closing;
    _graceful = graceful;
    notifyListeners();
  }
}
