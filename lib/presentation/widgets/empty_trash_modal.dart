import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// The Empty-Trash gate (spec §"Empty Trash modal"). The one irreversible
/// step — the body spells out the permanence. Returns `true` to empty.
Future<bool> showEmptyTrashModal(
  BuildContext context, {
  required AppLocalizations str,
  required String sizeLabel,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'empty',
    barrierColor: AppColors.scrim,
    pageBuilder: (_, _, _) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, _) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
      child: Opacity(
        opacity: anim.value,
        child: Center(child: _EmptyCard(str: str, sizeLabel: sizeLabel)),
      ),
    ),
    transitionDuration: const Duration(milliseconds: 160),
  );
  return result ?? false;
}

class _EmptyCard extends StatelessWidget {
  final AppLocalizations str;
  final String sizeLabel;
  const _EmptyCard({required this.str, required this.sizeLabel});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.raisedModal,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.borderModal),
          boxShadow: const [
            BoxShadow(
                color: AppColors.modalShadow,
                blurRadius: 90,
                offset: Offset(0, 40)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(str.eTitle,
                style:
                    AppText.space(18, wght: 600, color: AppColors.heroInk2)),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: str.eBody1,
                    style:
                        AppText.ui(13, color: AppColors.bodyDim, height: 1.5)),
                TextSpan(
                    text: sizeLabel,
                    style: AppText.mono(13, color: AppColors.danger)),
                TextSpan(
                    text: str.eBody2,
                    style:
                        AppText.ui(13, color: AppColors.bodyDim, height: 1.5)),
                TextSpan(
                    text: str.eCant,
                    style: AppText.ui(13,
                        weight: FontWeight.w600, color: AppColors.danger)),
                TextSpan(
                    text: str.eBody3,
                    style:
                        AppText.ui(13, color: AppColors.bodyDim, height: 1.5)),
              ]),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    child: Text(str.keepTrash,
                        style: AppText.ui(13.5, color: AppColors.secondary)),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(true),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(str.emptyTrash,
                        style: AppText.ui(13.5,
                            weight: FontWeight.w600,
                            color: AppColors.dangerBright)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
