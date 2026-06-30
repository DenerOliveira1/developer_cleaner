import 'package:flutter/widgets.dart';

import '../../core/cleaner/clean_models.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Fixed-width risk pill (spec §"Risk semantics"). The most important info
/// after size.
class RiskBadge extends StatelessWidget {
  final Safety safety;
  final AppLocalizations str;
  const RiskBadge({super.key, required this.safety, required this.str});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (safety) {
      Safety.safe => (
          AppColors.safe.withValues(alpha: 0.12),
          AppColors.safe,
          AppColors.safe.withValues(alpha: 0.30),
        ),
      Safety.confirm => (
          AppColors.confirm.withValues(alpha: 0.12),
          AppColors.confirm,
          AppColors.confirm.withValues(alpha: 0.32),
        ),
      Safety.danger => (
          AppColors.danger.withValues(alpha: 0.13),
          AppColors.danger,
          AppColors.danger.withValues(alpha: 0.34),
        ),
    };

    return Container(
      width: 84,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        str.badge(safety.name),
        style: AppText.mono(10, wght: 600, color: fg, letterSpacing: 1),
      ),
    );
  }
}
