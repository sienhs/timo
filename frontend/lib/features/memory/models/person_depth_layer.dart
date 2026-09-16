import 'dart:ui';

enum PersonDepthStrength {
  off('끄기', 0),
  weak('약하게', 0.012),
  strong('강하게', 0.026);

  const PersonDepthStrength(this.label, this.displacement);
  final String label;
  final double displacement;
  static PersonDepthStrength fromName(Object? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => weak);
}

/// One body-part layer of a person, far to near. [depth] is the layer's
/// median in the person's normalised depth range; [share] its pixel fraction.
class PersonPart {
  const PersonPart({
    required this.label,
    required this.depth,
    required this.share,
  });
  final String label;
  final double depth;
  final double share;

  /// Display name; unknown labels show as-is.
  String get name => switch (label) {
    'head' => '머리',
    'torso' => '몸통',
    'arms' => '팔',
    'hands' => '손',
    'legs' => '다리',
    _ => label,
  };

  Map<String, dynamic> toJson() => {
    'label': label,
    'depth': depth,
    'share': share,
  };
  factory PersonPart.fromJson(Map<String, dynamic> json) => PersonPart(
    label: json['label'] as String,
    depth: (json['depth'] as num).toDouble(),
    share: (json['share'] as num).toDouble(),
  );
}

/// The cutout and depth share pixel coordinates; placement is on the ticket.
/// [partMapPath] and [parts] describe the optional body-part split; they are
/// only drawn when [layered] is on and both exist.
class PersonDepthLayer {
  const PersonDepthLayer({
    required this.path,
    required this.placement,
    this.depthMapPath,
    this.partMapPath,
    this.parts = const [],
    this.layered = false,
    this.strength = PersonDepthStrength.weak,
    this.order = 0,
  });
  final String path;
  final String? depthMapPath;
  final String? partMapPath;
  final List<PersonPart> parts;
  final bool layered;
  final Rect placement;
  final PersonDepthStrength strength;
  final int order;

  /// Enough data to render the body-part shader instead of the single map.
  bool get usesPartLayers =>
      layered &&
      depthMapPath != null &&
      partMapPath != null &&
      parts.length >= 2;

  PersonDepthLayer withStrength(PersonDepthStrength value) => PersonDepthLayer(
    path: path,
    depthMapPath: depthMapPath,
    partMapPath: partMapPath,
    parts: parts,
    layered: layered,
    placement: placement,
    strength: value,
    order: order,
  );

  Map<String, dynamic> toJson() => {
    'path': path,
    'depthMapPath': depthMapPath,
    'partMapPath': partMapPath,
    'parts': parts.map((p) => p.toJson()).toList(),
    'layered': layered,
    'strength': strength.name,
    'order': order,
    'placement': {
      'left': placement.left,
      'top': placement.top,
      'width': placement.width,
      'height': placement.height,
    },
  };
  factory PersonDepthLayer.fromJson(Map<String, dynamic> json) {
    final p = json['placement'] as Map;
    return PersonDepthLayer(
      path: json['path'] as String,
      depthMapPath: json['depthMapPath'] as String?,
      partMapPath: json['partMapPath'] as String?,
      parts: [
        for (final part in json['parts'] as List? ?? const [])
          PersonPart.fromJson(Map<String, dynamic>.from(part as Map)),
      ],
      layered: json['layered'] == true,
      strength: PersonDepthStrength.fromName(json['strength']),
      order: (json['order'] as num?)?.toInt() ?? 0,
      placement: Rect.fromLTWH(
        (p['left'] as num).toDouble(),
        (p['top'] as num).toDouble(),
        (p['width'] as num).toDouble(),
        (p['height'] as num).toDouble(),
      ),
    );
  }
}
