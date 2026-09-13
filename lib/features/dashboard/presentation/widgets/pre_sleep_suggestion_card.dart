import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/storage/suggestion_ack_store.dart';
import '../../models/dashboard_models.dart';

/// การ์ด "Smart Suggestion" — ไม่ใช่แค่ข้อความเฉยๆ แต่มีปุ่ม action ให้กด
/// จัดการปัญหาได้เลย (เช่น "เปิดพัดลม/แอร์") ปุ่มจะเปลี่ยนเป็น "เปิดแล้ว ✓"
/// เมื่อกด และสถานะนี้ถูกบันทึกลง local storage ของเครื่อง (ไม่ใช่แค่ memory)
/// ผูกกับ [suggestion.factorKey] — ดังนั้นแม้ผู้ใช้จะปิดแอปแล้วเปิดใหม่ ปุ่มก็ยัง
/// แสดงสถานะ "เปิดแล้ว" อยู่เหมือนเดิม ตราบใดที่ยังเป็นปัญหาเดียวกัน (factor
/// เดิม) — จนกว่าสภาพแวดล้อมจะกลับมาปกติแล้วเกิดปัญหานี้ซ้ำใหม่อีกครั้ง
class PreSleepSuggestionCard extends StatefulWidget {
  final PreSleepSuggestion suggestion;

  const PreSleepSuggestionCard({required this.suggestion, super.key});

  @override
  State<PreSleepSuggestionCard> createState() =>
      _PreSleepSuggestionCardState();
}

class _PreSleepSuggestionCardState extends State<PreSleepSuggestionCard> {
  bool _acknowledged = false;
  bool _loadedAckOnce = false;

  @override
  void initState() {
    super.initState();
    _loadAckState();
  }

  @override
  void didUpdateWidget(covariant PreSleepSuggestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ปัญหาเปลี่ยน factor (เช่น หายจาก TEMP_HIGH กลายเป็น OK หรือปัญหาอื่น) —
    // โหลดสถานะ ack ของ factor ใหม่แทนของเก่า ไม่ปนกัน
    if (oldWidget.suggestion.factorKey != widget.suggestion.factorKey) {
      _loadAckState();
    }
  }

  Future<void> _loadAckState() async {
    final key = widget.suggestion.factorKey;
    final acked = key == 'OK'
        ? false
        : await SuggestionAckStore.instance.isAcknowledged(key);
    if (!mounted) return;
    setState(() {
      _acknowledged = acked;
      _loadedAckOnce = true;
    });
  }

  Future<void> _onActionTap() async {
    final key = widget.suggestion.factorKey;
    setState(() => _acknowledged = true);
    await SuggestionAckStore.instance.acknowledge(key);
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = widget.suggestion;
    final hasAction = suggestion.actionLabel != null;
    final color = suggestion.isWarning ? AppColors.accent : AppColors.secondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withValues(alpha: 0.28),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(suggestion.icon, color: color, size: 30),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          suggestion.title,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (suggestion.isWarning && !_acknowledged) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      suggestion.message,
                      style: const TextStyle(
                        color: AppColors.neutral,
                        fontSize: 16,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasAction && _loadedAckOnce) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: _acknowledged
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle,
                          color: AppColors.secondary, size: 18),
                      label: Text(
                        '${suggestion.actionLabel} แล้ว',
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        disabledForegroundColor: AppColors.secondary,
                        side: BorderSide(
                          color: AppColors.secondary.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _onActionTap,
                      icon: const Icon(Icons.bolt, size: 18),
                      label: Text(
                        suggestion.actionLabel!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
