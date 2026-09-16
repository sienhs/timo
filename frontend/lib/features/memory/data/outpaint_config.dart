/// Build-time configuration. Values arrive through `--dart-define` so no
/// secret is ever committed. Example (OpenAI-compatible gateway such as GMS):
///
/// ```
/// flutter build apk --debug \
///   --dart-define=OUTPAINT_PROVIDER=openai \
///   --dart-define=OUTPAINT_BASE_URL=https://gms.ssafy.io/gmsapi/api.openai.com \
///   --dart-define=OUTPAINT_MODEL=gpt-image-2 \
///   --dart-define=OUTPAINT_API_KEY=...
/// ```
class OutpaintConfig {
  /// `openai` (images/edits, gpt-image-*), `gemini` (generateContent,
  /// gemini-*-image) or `stability` (stable-image/edit/outpaint).
  static const provider = String.fromEnvironment(
    'OUTPAINT_PROVIDER',
    defaultValue: 'openai',
  );

  /// Origin of the API. Empty = the provider's public endpoint. Point it at
  /// a gateway (GMS) to proxy the same request shape.
  static const baseUrl = String.fromEnvironment('OUTPAINT_BASE_URL');

  /// Model id; empty = provider default.
  static const model = String.fromEnvironment('OUTPAINT_MODEL');

  /// API key for the provider/gateway. Empty disables the AI path.
  static const apiKey = String.fromEnvironment(
    'OUTPAINT_API_KEY',
    defaultValue: String.fromEnvironment('STABILITY_API_KEY'),
  );

  static bool get hasKey => apiKey.isNotEmpty;
}
