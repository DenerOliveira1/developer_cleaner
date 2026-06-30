import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/cleaner/clean_models.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// The NDK danger gate (spec §4). The destructive button stays disabled until
/// the user ticks "I reviewed the versions above" — a deliberate re-read.
/// Returns `true` if the user confirmed.
Future<bool> showDangerModal(
  BuildContext context, {
  required ScanResult ndk,
  required AppLocalizations str,
  required String sizeLabel,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'danger',
    barrierColor: const Color(0xA8070609),
    pageBuilder: (_, _, _) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, _) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
      child: Opacity(
        opacity: anim.value,
        child: Center(
          child: _DangerCard(ndk: ndk, str: str, sizeLabel: sizeLabel),
        ),
      ),
    ),
    transitionDuration: const Duration(milliseconds: 160),
  );
  return result ?? false;
}

class _DangerCard extends StatefulWidget {
  final ScanResult ndk;
  final AppLocalizations str;
  final String sizeLabel;
  const _DangerCard(
      {required this.ndk, required this.str, required this.sizeLabel});

  @override
  State<_DangerCard> createState() => _DangerCardState();
}

class _DangerCardState extends State<_DangerCard> {
  bool _reviewed = false;

  @override
  Widget build(BuildContext context) {
    final str = widget.str;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 472,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.raisedModal,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.borderModal),
          boxShadow: const [
            BoxShadow(
                color: Color(0xCC000000),
                blurRadius: 90,
                offset: Offset(0, 40)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text('!',
                      style: AppText.space(20,
                          wght: 700, color: AppColors.danger)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(str.dTitle,
                      style: AppText.space(18,
                          wght: 600, color: AppColors.heroInk2)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: str.dBody1,
                    style: AppText.ui(13,
                        color: AppColors.bodyDim, height: 1.5)),
                TextSpan(
                    text: 'ndkVersion',
                    style: AppText.mono(13, color: AppColors.confirm)),
                TextSpan(
                    text: str.dBody2,
                    style: AppText.ui(13,
                        color: AppColors.bodyDim, height: 1.5)),
              ]),
            ),
            const SizedBox(height: 14),
            _PathBox(ndk: widget.ndk, str: str),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => setState(() => _reviewed = !_reviewed),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: _reviewed ? AppColors.accentGradient : null,
                      border: Border.all(
                          width: 1.5,
                          color: _reviewed
                              ? AppColors.accentLight
                              : const Color(0xFF3A3743)),
                    ),
                    child: _reviewed
                        ? const Icon(Icons.check,
                            size: 14, color: Color(0xFF0E1622))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(str.reviewed,
                      style: AppText.ui(13, color: AppColors.secondary)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _GhostButton(
                    label: str.cancel,
                    onTap: () => Navigator.of(context).pop(false)),
                const SizedBox(width: 10),
                _DangerButton(
                  label: str.moveTrash(widget.sizeLabel),
                  enabled: _reviewed,
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PathBox extends StatelessWidget {
  final ScanResult ndk;
  final AppLocalizations str;
  const _PathBox({required this.ndk, required this.str});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.sunken,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.borderPreview),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...ndk.targets.map((t) => Padding(
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
              )),
          if (ndk.keepNote != null) ...[
            const SizedBox(height: 6),
            Text('✓ ${str.keeps(ndk.keepNote!)}',
                style: AppText.mono(11.5, color: AppColors.safe)),
          ],
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Text(label, style: AppText.ui(13.5, color: AppColors.secondary)),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _DangerButton(
      {required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.danger.withValues(alpha: 0.18)
              : AppColors.borderPreview,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: AppText.ui(13.5,
              weight: FontWeight.w600,
              color: enabled ? AppColors.dangerBright : AppColors.faintest2),
        ),
      ),
    );
  }
}
