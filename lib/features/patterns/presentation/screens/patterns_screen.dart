import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_service.dart';
import '../../models/pattern_models.dart';

/// Sleep Patterns — the Smart Suggestion screen.
///
/// This tab used to list Morning Reports, which duplicated what the dashboard
/// card already led to. Morning Reports now live on their own screen, reached
/// from the dashboard, and this tab does what the Test Plan actually asks a
/// Smart Suggestion to do (STC-04): analyse several nights of history, cluster
/// nights with similar profiles, and turn recurring conditions into advice.
///
/// Each suggestion is shown together with the pattern it came from, so the user
/// can see the evidence rather than being asked to take the advice on trust
/// (STC-04 TC-03 / TC-04). When fewer than three nights exist the screen says so
/// plainly instead of inventing a trend (TC-05).
class PatternsScreen extends StatefulWidget {
  const PatternsScreen({super.key});

  @override
  State<PatternsScreen> createState() => _PatternsScreenState();
}

class _PatternsScreenState extends State<PatternsScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  PatternAnalysis _analysis = PatternAnalysis.empty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final analysis = await _api.fetchSmartSuggestions(nights: 14);
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.secondary,
              backgroundColor: AppColors.card,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sleep Patterns',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _analysis.nightsAnalysed > 0
                          ? 'What keeps happening across your last '
                              '${_analysis.nightsAnalysed} nights'
                          : 'What keeps happening across your recent nights',
                      style: const TextStyle(
                          color: AppColors.neutral, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.secondary),
                        ),
                      ),
                    if (_error != null && !_loading) _errorBox(),
                    if (!_loading && _error == null) ..._content(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content() {
    // STC-04 TC-05: fewer than three nights of history.
    if (!_analysis.sufficientData) {
      return [_insufficientDataBox()];
    }

    if (_analysis.suggestions.isEmpty) {
      return [_noPatternsBox(), const SizedBox(height: 28), ..._clusterSection()];
    }

    return [
      _sectionTitle('Smart Suggestions'),
      const SizedBox(height: 14),
      ..._analysis.suggestions.map(_suggestionCard),
      const SizedBox(height: 28),
      ..._clusterSection(),
    ];
  }

  List<Widget> _clusterSection() {
    if (_analysis.clusters.isEmpty) return const [];
    return [
      _sectionTitle('Night groups'),
      const SizedBox(height: 6),
      const Text(
        'Nights with similar conditions are grouped together. The grouping is '
        'what the suggestions above are based on.',
        style: TextStyle(color: AppColors.neutral, fontSize: 13, height: 1.4),
      ),
      const SizedBox(height: 14),
      ..._analysis.clusters.map(_clusterCard),
    ];
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  /// One recommendation plus the pattern that produced it.
  Widget _suggestionCard(SmartSuggestion s) {
    final icon = _iconFor(s.factor);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AppColors.secondary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.secondary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  s.title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            s.recommendation,
            style: const TextStyle(
              color: AppColors.neutral,
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (s.evidence.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.iconBox.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.insights_rounded,
                      color: AppColors.neutral, size: 17),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.evidence,
                      style: const TextStyle(
                        color: AppColors.neutral,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _clusterCard(NightCluster c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.label,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                c.nightCount == 1 ? '1 night' : '${c.nightCount} nights',
                style:
                    const TextStyle(color: AppColors.secondary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${c.avgTemperature.toStringAsFixed(1)}°C · '
            '${c.avgHumidity.toStringAsFixed(0)}% · '
            '${c.avgCo2.round()} ppm CO₂ · '
            '${c.avgNoise.round()} dB',
            style: const TextStyle(color: AppColors.neutral, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// STC-04 TC-05.
  Widget _insufficientDataBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded,
                  color: AppColors.neutral, size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Not enough history yet',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _analysis.note ??
                'More data is needed for detailed pattern analysis. '
                    'At least 3 nights of history are required.',
            style: const TextStyle(
                color: AppColors.neutral, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'Keep using night monitoring — a night is added each time you stop '
            'monitoring in the morning. Pre-sleep advice on the dashboard keeps '
            'working in the meantime.',
            style: TextStyle(
                color: AppColors.neutral, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  /// Enough history, but nothing recurred often enough to call a pattern.
  /// Reporting nothing is the correct answer here (STC-04 TC-03).
  Widget _noPatternsBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.secondary.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline,
              color: AppColors.secondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No recurring problems found across your last '
              '${_analysis.nightsAnalysed} nights. Nothing was out of range '
              'often enough to be worth acting on.',
              style: const TextStyle(
                  color: AppColors.neutral, fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: AppColors.accent, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Could not load your sleep patterns — the backend is unreachable\n'
              '(pull to retry)',
              style: TextStyle(color: AppColors.neutral, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String factor) {
    switch (factor.toUpperCase()) {
      case 'CO2':
        return Icons.air;
      case 'TEMPERATURE':
        return Icons.thermostat_outlined;
      case 'HUMIDITY':
        return Icons.water_drop_outlined;
      case 'PM25':
        return Icons.speed_outlined;
      case 'LIGHT':
        return Icons.wb_sunny_outlined;
      case 'NOISE':
        return Icons.volume_up_outlined;
      case 'MOTION':
        return Icons.directions_walk;
      default:
        return Icons.lightbulb_outline;
    }
  }
}
