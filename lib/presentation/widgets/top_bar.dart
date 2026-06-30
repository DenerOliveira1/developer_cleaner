import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/app_lang.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// In-window top bar: app name on the left (clear of the native traffic
/// lights) and the PT|EN language switcher on the right (a real app feature).
class TopBar extends StatelessWidget {
  final AppLang lang;
  final ValueChanged<AppLang> onLang;
  const TopBar({super.key, required this.lang, required this.onLang});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 86, right: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/icons/logo.svg',
            width: 25,
            height: 25,
          ),
          const SizedBox(width: 9),
          Text('DevDisk',
              style: AppText.space(14, wght: 600, color: AppColors.heroInk2)),
          const SizedBox(width: 8),
          Text('Cleaner',
              style: AppText.mono(11.5, color: AppColors.faintest)),
          const Spacer(),
          _LangButton(
            label: 'PT',
            active: lang == AppLang.pt,
            onTap: () => onLang(AppLang.pt),
          ),
          const SizedBox(width: 4),
          _LangButton(
            label: 'EN',
            active: lang == AppLang.en,
            onTap: () => onLang(AppLang.en),
          ),
        ],
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _LangButton(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF33303D) : const Color(0x00000000),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: AppText.mono(11,
              wght: 600,
              letterSpacing: 0.55,
              color: active ? AppColors.heroInk2 : AppColors.faintest),
        ),
      ),
    );
  }
}
