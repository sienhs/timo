import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/timo_logo.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';

/// 앱을 켤 때 처음 보이는 로딩 화면.
///
/// 시안 '로딩 1~4' 는 한 애니메이션의 네 장면이다. 'ticket moa' 에서 T·I·M·O
/// 네 글자만 대문자로 남고(로딩 2) 나머지가 빠져 'TIMO' 가 되고(로딩 3),
/// 마지막에 로고 이미지로 바뀐다(로딩 4). 장면은 크로스페이드로 넘어가고,
/// 마지막 장면까지 보인 뒤 홈으로 **교체** 이동한다 — push 로 쌓으면 홈에서
/// 뒤로 가기를 눌렀을 때 이 화면으로 돌아온다.
///
/// 서버는 부르지 않는다. 로그인 정보 되살리기는 main 이 앱을 띄우기 전에
/// 끝내고, 홈 데이터는 홈이 스켈레톤을 보이며 직접 가져온다. 그래서 이 화면은
/// 정해진 시간만 머무는 브랜드 화면이다. 장면별 시간은 [SplashMetrics].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// 지금 보이는 장면. 0 부터 시작해 마지막 장면(로고)까지 하나씩 오른다.
  int _step = 0;

  /// 다음 장면으로 넘길 타이머. 화면이 사라질 때 꼭 취소한다 — 안 그러면 이미
  /// 없는 화면이 setState 를 부르거나 홈으로 한 번 더 이동한다.
  Timer? _timer;

  bool _logoPrecached = false;

  @override
  void initState() {
    super.initState();
    // 첫 프레임이 그려진 뒤부터 시간을 센다. initState 시점엔 화면에 아직
    // 아무것도 없다 — 느린 기기나 디버그 빌드는 첫 프레임까지 1초 넘게
    // 걸리는데, 그때부터 세면 첫 장면이 보이기도 전에 지나간다(에뮬레이터에서
    // 확인). 그 사이 화면이 사라졌을 수도 있어 mounted 를 본다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleNext();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 마지막 장면의 로고를 지금 미리 디코딩해 둔다. 원본이 2820×1472 라 장면이
    // 바뀌는 순간 읽으면 디코딩하는 동안 빈 화면이 한 번 보인다(에뮬레이터에서
    // 확인). 화면 배율(MediaQuery)이 필요해 initState 가 아니라 여기서 한다.
    if (!_logoPrecached) {
      _logoPrecached = true;
      TimoLogo.precache(context, height: SplashMetrics.logoHeight);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 현재 장면이 머무는 시간이 지나면 다음 장면으로 넘기고, 마지막 장면이었으면
  /// 홈으로 간다.
  void _scheduleNext() {
    _timer = Timer(SplashMetrics.stepDurations[_step], () {
      if (_step < SplashMetrics.stepDurations.length - 1) {
        setState(() => _step++);
        _scheduleNext();
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AnimatedSwitcher(
          duration: SplashMetrics.fadeDuration,
          // 장면마다 다른 키를 줘야 AnimatedSwitcher 가 "다른 위젯" 으로 보고
          // 페이드를 건다. 키가 같으면 글자만 바뀌고 애니메이션은 없다.
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: _step < SplashStrings.wordmarks.length
                ? _WordmarkFrame(wordmark: SplashStrings.wordmarks[_step])
                : const TimoLogo(height: SplashMetrics.logoHeight),
          ),
        ),
      ),
    );
  }
}

/// 로딩 1~3. 위에 작은 회색 문구, 아래에 초록 워드마크.
class _WordmarkFrame extends StatelessWidget {
  const _WordmarkFrame({required this.wordmark});

  final String wordmark;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          SplashStrings.tagline,
          style: textTheme.bodySmall?.copyWith(
            fontSize: SplashMetrics.taglineFontSize,
          ),
        ),
        const SizedBox(height: SplashMetrics.taglineGap),
        Text(
          wordmark,
          style: textTheme.headlineSmall?.copyWith(
            fontSize: SplashMetrics.wordmarkFontSize,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
