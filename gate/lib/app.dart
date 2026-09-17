import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/scan/constants.dart';
import 'features/scan/data/mock_scan_api.dart';
import 'features/scan/data/scan_api.dart';
import 'features/scan/models/gate_target.dart';
import 'features/scan/screens/scan_screen.dart';
import 'features/scan/state/scan_api_scope.dart';

/// 스캔 화면이 어느 [ScanApi] 를 쓸지 고르는 실행 인자.
///
/// ```bash
/// flutter run                                  # 기본값. 목 — 예매 ID 로 결과가 갈린다
/// flutter run --dart-define=SCAN_API=mock-error  # 매번 확인 실패
/// ```
///
/// 백엔드에 검증 API 가 생기면 `http` 값을 추가하고 기본값을 그쪽으로 바꾼다.
const _scanApiKind = String.fromEnvironment('SCAN_API');

ScanApi _scanApiFor(String kind) => switch (kind) {
  'mock-error' => MockScanApi(failing: true),
  _ => MockScanApi(),
};

class App extends StatefulWidget {
  const App({super.key, this.scanApi, this.target});

  /// 안 넘기면 [_scanApiKind] 가 고른다. 테스트는 목을 넣는다.
  final ScanApi? scanApi;

  /// 검표할 공연. 안 넘기면 목 값. 운영자 로그인·공연 선택이 붙으면 그 화면이
  /// 이 값을 만들어 넘긴다.
  final GateTarget? target;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  /// 앱에 하나만 두고 [ScanApiScope] 로 내려준다. 화면이 각자 만들면 목의
  /// "이미 입장" 기록이 화면마다 따로 놀고, 테스트에서 갈아끼울 자리도 없다.
  late final ScanApi _scanApi = widget.scanApi ?? _scanApiFor(_scanApiKind);

  @override
  Widget build(BuildContext context) {
    return ScanApiScope(
      api: _scanApi,
      child: MaterialApp(
        title: ScanStrings.appName,
        theme: AppTheme.light,
        home: ScanScreen(target: widget.target ?? MockScanApi.target),
      ),
    );
  }
}
