import 'package:flutter/material.dart';

import '../../core/cleaner/clean_models.dart';
import '../../core/util/byte_format.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'risk_badge.dart';

/// One rule in the Results list: checkbox · risk badge · name/desc · size ·
/// chevron, with an expandable path preview (spec §UI Results).
class RuleRow extends StatelessWidget {
  final ScanResult result;
  final AppLocalizations str;
  final bool selected;
  final bool expanded;
  final bool actionable;
  final VoidCallback onToggle;
  final VoidCallback onExpand;

  const RuleRow({
    super.key,
    required this.result,
    required this.str,
    required this.selected,
    required this.expanded,
    required this.actionable,
    required this.onToggle,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final rule = result.rule;
    final sizeLabel =
        result.bytes == null ? '—' : formatBytes(result.bytes);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: expanded ? AppColors.raisedModal : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: expanded ? AppColors.borderActive : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            child: Row(
              children: [
                _Checkbox(
                  selectable: actionable,
                  checked: selected,
                  onTap: actionable ? onToggle : null,
                ),
                const SizedBox(width: 14),
                RiskBadge(safety: rule.safety, str: str),
                const SizedBox(width: 14),
                Expanded(
                  child: _NameBlock(
                    name: str.ruleName(rule.id),
                    desc: str.ruleDesc(rule.id),
                    muted: !actionable,
                    onTap: onExpand,
                  ),
                ),
                const SizedBox(width: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 62),
                  child: Text(
                    sizeLabel,
                    textAlign: TextAlign.right,
                    style: AppText.mono(
                      13.5,
                      color: !actionable
                          ? AppColors.faintest2
                          : (selected ? AppColors.accentMono : AppColors.monoDim),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onExpand,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Text('▸',
                        style: TextStyle(
                            color: AppColors.faintest2, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
          if (expanded) _Preview(result: result, str: str),
        ],
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  final bool selectable;
  final bool checked;
  final VoidCallback? onTap;
  const _Checkbox({
    required this.selectable,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          gradient: checked ? AppColors.accentGradient : null,
          color: selectable
              ? (checked ? null : Colors.transparent)
              : AppColors.raisedAlt,
          border: Border.all(
            width: 1.5,
            color: !selectable
                ? AppColors.border
                : (checked ? AppColors.accentLight : AppColors.borderControl),
          ),
        ),
        child: checked
            ? const Icon(Icons.check, size: 15, color: AppColors.onAccent)
            : null,
      ),
    );
  }
}

class _NameBlock extends StatelessWidget {
  final String name;
  final String desc;
  final bool muted;
  final VoidCallback onTap;
  const _NameBlock({
    required this.name,
    required this.desc,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.ui(14,
                weight: FontWeight.w500,
                color: muted ? AppColors.faint2 : AppColors.rowName),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.ui(12, color: AppColors.faint2),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final ScanResult result;
  final AppLocalizations str;
  const _Preview({required this.result, required this.str});

  @override
  Widget build(BuildContext context) {
    final empty = result.targets.isEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(15, 0, 15, 13),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.sunken,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.borderPreview),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isReversibleAction(result.rule.action)) ...[
            Row(
              children: [
                const Icon(Icons.report_gmailerrorred_outlined,
                    size: 13, color: AppColors.danger),
                const SizedBox(width: 5),
                Text(str.permanentWarning,
                    style: AppText.mono(11, color: AppColors.danger)),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (empty)
            Text(str.nothing,
                style: AppText.mono(12, color: AppColors.bodyDim))
          else
            ...result.targets.map(
              (t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: RichText(
                  text: TextSpan(children: [
                    TextSpan(
                        text: '› ',
                        style: AppText.mono(12, color: AppColors.faintest3)),
                    TextSpan(
                        text: t,
                        style: AppText.mono(12, color: AppColors.bodyDim)),
                  ]),
                ),
              ),
            ),
          if (result.keepNote != null) ...[
            const SizedBox(height: 6),
            Text('✓ ${str.keeps(result.keepNote!)}',
                style: AppText.mono(11.5, color: AppColors.safe)),
          ],
        ],
      ),
    );
  }
}
