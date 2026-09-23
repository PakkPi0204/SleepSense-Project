/// Client-side mirror of PatternAnalysisResult on the backend — the response
/// behind the Sleep Patterns screen.
///
/// Test Plan reference: STC-04. The payload deliberately carries the evidence
/// (which cluster each night fell into, which pattern was detected, how many
/// nights support it) alongside the advice, so the screen can show the user
/// why a recommendation was made rather than just asserting it.
class PatternAnalysis {
  /// False when fewer than three nights of history exist.
  final bool sufficientData;

  /// Only set when [sufficientData] is false.
  final String? note;

  final int nightsAnalysed;
  final List<ClusteredNight> nights;
  final List<NightCluster> clusters;
  final List<DetectedPattern> patterns;
  final List<SmartSuggestion> suggestions;

  const PatternAnalysis({
    required this.sufficientData,
    this.note,
    required this.nightsAnalysed,
    required this.nights,
    required this.clusters,
    required this.patterns,
    required this.suggestions,
  });

  static const empty = PatternAnalysis(
    sufficientData: false,
    nightsAnalysed: 0,
    nights: [],
    clusters: [],
    patterns: [],
    suggestions: [],
  );

  factory PatternAnalysis.fromJson(Map<String, dynamic> json) {
    return PatternAnalysis(
      sufficientData: json['sufficientData'] == true,
      note: json['note'] as String?,
      nightsAnalysed: (json['nightsAnalysed'] as num?)?.toInt() ?? 0,
      nights: _list(json['nights'], ClusteredNight.fromJson),
      clusters: _list(json['clusters'], NightCluster.fromJson),
      patterns: _list(json['patterns'], DetectedPattern.fromJson),
      suggestions: _list(json['suggestions'], SmartSuggestion.fromJson),
    );
  }
}

/// One night of history, with the cluster it was assigned to.
class ClusteredNight {
  final String? reportId;
  final String? date;
  final int cluster;
  final double avgCo2;
  final double maxCo2;
  final double avgTemperature;
  final double avgHumidity;
  final double avgPm25;
  final double avgLight;
  final double avgNoise;
  final int motionEventCount;

  const ClusteredNight({
    this.reportId,
    this.date,
    required this.cluster,
    required this.avgCo2,
    required this.maxCo2,
    required this.avgTemperature,
    required this.avgHumidity,
    required this.avgPm25,
    required this.avgLight,
    required this.avgNoise,
    required this.motionEventCount,
  });

  factory ClusteredNight.fromJson(Map<String, dynamic> json) {
    return ClusteredNight(
      reportId: json['reportId'] as String?,
      date: json['date'] as String?,
      cluster: (json['cluster'] as num?)?.toInt() ?? 0,
      avgCo2: _double(json['avgCo2']),
      maxCo2: _double(json['maxCo2']),
      avgTemperature: _double(json['avgTemperature']),
      avgHumidity: _double(json['avgHumidity']),
      avgPm25: _double(json['avgPm25']),
      avgLight: _double(json['avgLight']),
      avgNoise: _double(json['avgNoise']),
      motionEventCount: (json['motionEventCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A group of nights that share an environmental profile.
class NightCluster {
  final int index;
  final int nightCount;
  final String label;
  final double avgCo2;
  final double avgTemperature;
  final double avgHumidity;
  final double avgPm25;
  final double avgLight;
  final double avgNoise;
  final double avgMotionEvents;

  const NightCluster({
    required this.index,
    required this.nightCount,
    required this.label,
    required this.avgCo2,
    required this.avgTemperature,
    required this.avgHumidity,
    required this.avgPm25,
    required this.avgLight,
    required this.avgNoise,
    required this.avgMotionEvents,
  });

  factory NightCluster.fromJson(Map<String, dynamic> json) {
    return NightCluster(
      index: (json['index'] as num?)?.toInt() ?? 0,
      nightCount: (json['nightCount'] as num?)?.toInt() ?? 0,
      label: (json['label'] ?? 'Cluster').toString(),
      avgCo2: _double(json['avgCo2']),
      avgTemperature: _double(json['avgTemperature']),
      avgHumidity: _double(json['avgHumidity']),
      avgPm25: _double(json['avgPm25']),
      avgLight: _double(json['avgLight']),
      avgNoise: _double(json['avgNoise']),
      avgMotionEvents: _double(json['avgMotionEvents']),
    );
  }
}

/// A recurring condition found across the nights in one cluster.
class DetectedPattern {
  final String id;
  final String factor;
  final String description;
  final int occurrences;
  final int nightsInCluster;
  final int cluster;
  final double confidence;

  const DetectedPattern({
    required this.id,
    required this.factor,
    required this.description,
    required this.occurrences,
    required this.nightsInCluster,
    required this.cluster,
    required this.confidence,
  });

  factory DetectedPattern.fromJson(Map<String, dynamic> json) {
    return DetectedPattern(
      id: (json['id'] ?? '').toString(),
      factor: (json['factor'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      occurrences: (json['occurrences'] as num?)?.toInt() ?? 0,
      nightsInCluster: (json['nightsInCluster'] as num?)?.toInt() ?? 0,
      cluster: (json['cluster'] as num?)?.toInt() ?? 0,
      confidence: _double(json['confidence']),
    );
  }
}

/// An actionable recommendation derived from exactly one detected pattern.
class SmartSuggestion {
  /// Ties the advice back to the pattern it came from.
  final String patternId;
  final String factor;
  final String title;
  final String recommendation;

  /// The evidence behind it, e.g. "On 4 of 5 similar nights, ...".
  final String evidence;

  const SmartSuggestion({
    required this.patternId,
    required this.factor,
    required this.title,
    required this.recommendation,
    required this.evidence,
  });

  factory SmartSuggestion.fromJson(Map<String, dynamic> json) {
    return SmartSuggestion(
      patternId: (json['patternId'] ?? '').toString(),
      factor: (json['factor'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      recommendation: (json['recommendation'] ?? '').toString(),
      evidence: (json['evidence'] ?? '').toString(),
    );
  }
}

// ── helpers ──
double _double(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) build) {
  if (v is! List) return const [];
  return v
      .whereType<Map<String, dynamic>>()
      .map(build)
      .toList(growable: false);
}
