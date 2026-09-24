import 'package:flutter/material.dart';

/// Brand palette for the dark "stage" look. Every color used by more than one
/// domain lives here so a brand change is a single edit.
class TimoColors {
  static const background = Color(0xFF070A12);
  static const backgroundElevated = Color(0xFF0D1220);
  static const glass = Color(0x14FFFFFF);
  static const glassStrong = Color(0x24FFFFFF);
  static const glassBorder = Color(0x2EFFFFFF);
  static const brand = Color(0xFF287743);
  static const accent = Color(0xFF4ADE80);
  static const accentSoft = Color(0xFF86EFAC);
  static const violet = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF22D3EE);
  static const gold = Color(0xFFFBBF24);
  static const magenta = Color(0xFFF472B6);
  static const textPrimary = Color(0xFFF4F6FB);
  static const textSecondary = Color(0xFFA3ACBE);
  static const textTertiary = Color(0xFF6B7485);
  static const danger = Color(0xFFF87171);

  /// 티켓 카드의 테두리 재질. 앞면 썸네일의 프레임과 오르골 뒷면이 같은 색을
  /// 써서 한 장의 카드로 읽힌다.
  static const cardFrame = Color(0xFF15181F);

  // Light "paper" chrome used by the collection and creator screens. The
  // ticket itself stays on the dark stage palette above.
  static const paper = Color(0xFFFFFFFF);
  static const paperMuted = Color(0xFFF5F6F8);
  static const placeholder = Color(0xFFDDDFE3);
  static const line = Color(0xFFE6E8EC);
  static const ink = Color(0xFF14171D);
  static const inkSecondary = Color(0xFF6B7280);
  static const inkTertiary = Color(0xFFA1A7B3);
  static const brandMid = Color(0xFF3A9A63);
  static const brandSoft = Color(0xFFE8F5EE);
  static const dangerInk = Color(0xFFD94C4C);
}

class TimoGradients {
  static const accent = LinearGradient(
    colors: [TimoColors.accent, Color(0xFF22C55E), TimoColors.brand],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const holo = LinearGradient(
    colors: [
      TimoColors.cyan,
      TimoColors.accent,
      TimoColors.gold,
      TimoColors.magenta,
      TimoColors.violet,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const wordmark = LinearGradient(
    colors: [TimoColors.accentSoft, TimoColors.accent, TimoColors.cyan],
  );
}

class TimoRadii {
  static const card = 18.0;
  static const panel = 22.0;
  static const tile = 16.0;
}
