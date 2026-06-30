import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/cleaner/clean_models.dart';
import '../../core/util/byte_format.dart';
import '../../domain/usecases/clean_rules.dart' show CleanFailure;
import '../cubit/cleaner_cubit.dart';
import '../../l10n/app_localizations.dart';
import '../cubit/cleaner_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/danger_modal.dart';
import '../widgets/disk_gauge.dart';
import '../widgets/empty_trash_modal.dart';
import '../widgets/rule_row.dart';
import '../widgets/top_bar.dart';

/// Formats reclaimable/disk numbers like the design hero (no decimals for the
/// big readouts).
String _hero(int bytes) => formatBytes(bytes, decimals: 0);

class CleanerPage extends StatefulWidget {
  const CleanerPage({super.key});

  @override
  State<CleanerPage> createState() => _CleanerPageState();
}

class _CleanerPageState extends State<CleanerPage>
    with TickerProviderStateMixin {
  late final AnimationController _gauge =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _reveal =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  bool _dryRun = false;
  bool _reduced = false;
  bool _showFailures = false;
  CleanerPhase? _lastPhase;
  bool _gaugeShown = false;

  @override
  void dispose() {
    _gauge.dispose();
    _reveal.dispose();
    _spin.dispose();
    super.dispose();
  }

  void _onState(BuildContext context, CleanerState s) {
    // Reduced motion: jump to final values, no tweens/spins.
    if (_reduced) {
      _gauge.value = 1;
      _reveal.value = 1;
      _spin.stop();
    }

    // Animate the idle gauge once disk stats arrive.
    if (s.phase == CleanerPhase.idle && s.disk != null && !_gaugeShown) {
      _gaugeShown = true;
      _reduced ? _gauge.value = 1 : _gauge.forward(from: 0);
    }

    if (s.phase == _lastPhase) return;
    _lastPhase = s.phase;

    // Allow the idle gauge to re-animate on a later return (e.g. after a
    // restart from Done).
    if (s.phase != CleanerPhase.idle) _gaugeShown = false;

    switch (s.phase) {
      case CleanerPhase.scanning:
        if (!_reduced) _spin.repeat();
      case CleanerPhase.done:
        _spin.stop();
        _showFailures = false;
        if (_reduced) {
          _gauge.value = 1;
          _reveal.value = 1;
        } else {
          _gauge.forward(from: 0);
          _reveal.forward(from: 0);
        }
      default:
        _spin.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    _reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return BlocConsumer<CleanerCubit, CleanerState>(
      listener: _onState,
      builder: (context, state) {
        final str = AppLocalizations.of(context);
        return DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.pageGradient),
          child: Column(
            children: [
              TopBar(
                lang: state.lang,
                onLang: (l) => context.read<CleanerCubit>().setLang(l),
              ),
              Expanded(child: _body(context, state, str)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, CleanerState s, AppLocalizations str) {
    return switch (s.phase) {
      CleanerPhase.error => _Error(message: s.error ?? str.genericError),
      CleanerPhase.scanning => _scanning(s, str),
      CleanerPhase.results => _results(context, s, str),
      CleanerPhase.cleaning => _cleaning(s, str),
      CleanerPhase.done => _done(context, s, str),
      _ => _idle(context, s, str),
    };
  }

  // ── Idle ────────────────────────────────────────────────────────────────
  Widget _idle(BuildContext context, CleanerState s, AppLocalizations str) {
    final disk = s.disk;
    if (disk == null) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
        ),
      );
    }
    final segments = [
      for (final c in disk.categories)
        GaugeSegment(AppColors.category(c.key), c.bytes.toDouble()),
    ];
    final reclaim = disk.categories
        .where((c) => const {'xcode', 'caches', 'androidSdk', 'appSupport'}
            .contains(c.key))
        .fold<int>(0, (a, c) => a + c.bytes);

    return Row(
      children: [
        Expanded(
          flex: 105,
          child: Center(
            child: AnimatedBuilder(
              animation: _gauge,
              builder: (_, _) => DiskGauge(
                size: 336,
                segments: segments,
                total: disk.totalBytes.toDouble(),
                progress: _gauge.value,
                center: _gaugeCenter(
                  kicker: str.used,
                  value: _hero(disk.usedBytes),
                  sub: str.diskSub(_hero(disk.freeBytes), _hero(disk.totalBytes)),
                ),
              ),
            ),
          ),
        ),
        Container(width: 1, color: AppColors.divider),
        SizedBox(
          width: 374,
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MACINTOSH HD',
                    style: AppText.mono(11,
                        letterSpacing: 2, color: AppColors.faintest)),
                const SizedBox(height: 6),
                Text(str.breakdown,
                    style: AppText.space(20,
                        wght: 600, color: AppColors.heroInk2)),
                const SizedBox(height: 18),
                ...disk.categories.map((c) => _legendRow(str, c)),
                const SizedBox(height: 16),
                _reclaimHint(str, reclaim),
                const Spacer(),
                _AccentButton(
                  label: str.scan,
                  height: 48,
                  onTap: () => context.read<CleanerCubit>().scanAll(),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(str.reversible,
                      textAlign: TextAlign.center,
                      style: AppText.mono(11.5, color: AppColors.faintest)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendRow(AppLocalizations str, DiskCategory c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
                color: AppColors.category(c.key),
                borderRadius: BorderRadius.circular(2.5)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(str.category(c.key),
                style: AppText.ui(13.5, color: AppColors.secondary)),
          ),
          Text(formatBytes(c.bytes),
              style: AppText.mono(13, color: AppColors.monoDim)),
        ],
      ),
    );
  }

  Widget _reclaimHint(AppLocalizations str, int reclaim) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.55),
                    blurRadius: 10,
                    spreadRadius: 1),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(children: [
                const TextSpan(text: '≈ '),
                TextSpan(
                    text: _hero(reclaim),
                    style: AppText.mono(12.5, color: AppColors.accentMono)),
                TextSpan(
                    text: ' ${str.reclaimRest}',
                    style: AppText.ui(12.5, color: AppColors.bodyDim)),
              ], style: AppText.ui(12.5, color: AppColors.bodyDim)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Scanning ──────────────────────────────────────────────────────────────
  Widget _scanning(CleanerState s, AppLocalizations str) {
    final pct = (s.scanProgress * 100).round();
    final currentName = s.scanningRuleId == null
        ? '…'
        : str.ruleName(s.scanningRuleId!);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _spin,
            builder: (_, _) => DiskGauge(
              size: 300,
              segments: const [],
              total: 1,
              spinnerFraction: 140 / (2 * 3.14159 * 130),
              spinnerRotation: _reduced ? 0 : _spin.value * 2 * 3.14159,
              center: _gaugeCenter(
                kicker: str.scanning,
                value: '$pct%',
                sub: '',
              ),
            ),
          ),
          const SizedBox(height: 22),
          _PulseLabel(text: str.reading(currentName), reduced: _reduced),
        ],
      ),
    );
  }

  // ── Results ───────────────────────────────────────────────────────────────
  Widget _results(BuildContext context, CleanerState s, AppLocalizations str) {
    final total = s.selectedReclaimableBytes;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str.cleanup,
                        style: AppText.space(18,
                            wght: 600, color: AppColors.heroInk2)),
                    const SizedBox(height: 4),
                    Text(str.reversible,
                        style: AppText.mono(11.5, color: AppColors.faintest)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      _DryToggle(
                        value: _dryRun,
                        onChanged: (v) => setState(() => _dryRun = v),
                      ),
                      const SizedBox(width: 16),
                      RichText(
                        text: TextSpan(children: [
                          TextSpan(
                              text: '${str.selected} ',
                              style:
                                  AppText.mono(12, color: AppColors.faintest)),
                          TextSpan(
                              text: _hero(total),
                              style: AppText.mono(12,
                                  color: AppColors.accentMono)),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 240,
                    child: _AccentButton(
                      label: '${str.cleanSelected} · ${_hero(total)}',
                      height: 40,
                      onTap: s.selectedRuleIds.isEmpty
                          ? null
                          : () => _runClean(context, s, str),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            children: [
              for (final r in s.results)
                RuleRow(
                  result: r,
                  str: str,
                  selected: s.isSelected(r.rule.id),
                  expanded: s.expandedId == r.rule.id,
                  actionable: s.isActionable(r.rule.id),
                  onToggle: () =>
                      context.read<CleanerCubit>().toggleRule(r.rule.id),
                  onExpand: () =>
                      context.read<CleanerCubit>().expand(r.rule.id),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _runClean(
      BuildContext context, CleanerState s, AppLocalizations str) async {
    final cubit = context.read<CleanerCubit>();
    if (s.hasUnconfirmedDanger) {
      final dangerResult = s.results.firstWhere(
        (r) => r.rule.safety == Safety.danger && s.isSelected(r.rule.id),
      );
      final rule = dangerResult.rule;
      final permanent = !isReversibleAction(rule.action);
      final ok = await showDangerModal(
        context,
        str: str,
        title: str.removeTitle(str.ruleName(rule.id)),
        body: str.ruleDesc(rule.id),
        targets: dangerResult.targets,
        keepNote: dangerResult.keepNote,
        permanent: permanent,
        confirmLabel: permanent
            ? str.removePermanently
            : str.moveTrash(_hero(dangerResult.bytes ?? 0)),
      );
      if (!ok) return;
      cubit.confirmDanger();
    }
    await cubit.cleanSelected(dryRun: _dryRun);
  }

  // ── Cleaning ──────────────────────────────────────────────────────────────
  Widget _cleaning(CleanerState s, AppLocalizations str) {
    final cur = s.cleaningRuleId == null
        ? ''
        : (s.resultFor(s.cleaningRuleId!)?.rule.label ?? s.cleaningRuleId!);
    final total = s.cleanTotal == 0 ? 1 : s.cleanTotal;
    final fraction = ((s.cleanIndex + 1) / total).clamp(0.0, 1.0);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(str.cleaning,
              style: AppText.mono(11,
                  letterSpacing: 2, color: AppColors.faintest)),
          const SizedBox(height: 12),
          Text(cur,
              style: AppText.space(24, wght: 600, color: AppColors.heroInk2)),
          const SizedBox(height: 22),
          SizedBox(
            width: 440,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: const Duration(milliseconds: 300),
                builder: (_, v, _) => Stack(
                  children: [
                    Container(height: 8, color: AppColors.borderPreview),
                    FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        height: 8,
                        decoration:
                            const BoxDecoration(gradient: AppColors.accentGradient),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('${s.cleanIndex + 1} ${str.stepOf} ${s.cleanTotal}',
              style: AppText.mono(12, color: AppColors.monoDim)),
        ],
      ),
    );
  }

  // ── Done ──────────────────────────────────────────────────────────────────
  Widget _done(BuildContext context, CleanerState s, AppLocalizations str) {
    final outcome = s.outcome;
    final disk = s.disk;
    final freed = outcome?.freedBytes ?? 0;
    final inTrash = outcome?.inTrashBytes ?? 0;
    final reclaimTotal = outcome?.totalBytes ?? 0;

    return Row(
      children: [
        Expanded(
          flex: 100,
          child: Center(
            child: AnimatedBuilder(
              animation: _reveal,
              builder: (_, _) {
                final p = _reveal.value;
                final total = (disk?.totalBytes ?? 1).toDouble();
                final free = (disk?.freeBytes ?? 0).toDouble();
                final usedOther = (total - free - freed - inTrash).clamp(0, total);
                final segments = [
                  GaugeSegment(AppColors.catOther, usedOther + freed * (1 - p)),
                  GaugeSegment(AppColors.safe, freed * p),
                  GaugeSegment(
                      AppColors.accent.withValues(alpha: 0.42), inTrash * p),
                  GaugeSegment(AppColors.catFree, free),
                ];
                final freeNow = free + freed * p;
                return DiskGauge(
                  size: 312,
                  segments: segments,
                  total: total,
                  progress: 1,
                  center: _gaugeCenter(
                    kicker: str.freeNow,
                    value: _hero(freeNow.round()),
                    sub: str.returnedReal(_hero(freed)),
                    subColor: AppColors.safe,
                  ),
                );
              },
            ),
          ),
        ),
        Container(width: 1, color: AppColors.divider),
        SizedBox(
          width: 412,
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(str.complete,
                    style: AppText.mono(11,
                        letterSpacing: 2, color: AppColors.safe)),
                const SizedBox(height: 14),
                AnimatedBuilder(
                  animation: _reveal,
                  builder: (_, _) {
                    final shown = (reclaimTotal * _reveal.value).round();
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatBytes(shown, decimals: 0).split(' ').first,
                            style: AppText.space(88,
                                wght: 700,
                                letterSpacing: -2.6,
                                color: AppColors.heroInk)),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                              formatBytes(shown, decimals: 0).split(' ').last,
                              style: AppText.space(34,
                                  wght: 600, color: AppColors.accentMono)),
                        ),
                      ],
                    );
                  },
                ),
                Text(str.reclaimable,
                    style: AppText.space(18, color: AppColors.faint)),
                const SizedBox(height: 20),
                _trashSplit(str, freed, inTrash, s.trashEmptied),
                const SizedBox(height: 16),
                _EmptyTrashButton(
                  label: s.trashEmptied ? str.trashEmpty : str.emptyCta,
                  enabled: !s.trashEmptied && inTrash > 0,
                  onTap: () async {
                    final ok = await showEmptyTrashModal(context,
                        str: str, sizeLabel: _hero(inTrash));
                    if (ok && context.mounted) {
                      context.read<CleanerCubit>().emptyTrash();
                    }
                  },
                ),
                const SizedBox(height: 12),
                Text(str.recoverNote,
                    style: AppText.mono(11.5, color: AppColors.faintest)),
                if (s.failures.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showFailures = !_showFailures),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 14, color: AppColors.confirm),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(str.cleanFailures(s.failures.length),
                              style:
                                  AppText.mono(11.5, color: AppColors.confirm)),
                        ),
                        Icon(
                            _showFailures
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 16,
                            color: AppColors.confirm),
                      ],
                    ),
                  ),
                  if (_showFailures) ...[
                    const SizedBox(height: 8),
                    _FailureDetails(failures: s.failures, str: str),
                  ],
                ],
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () => context.read<CleanerCubit>().restart(),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh,
                          size: 15, color: AppColors.accentMono),
                      const SizedBox(width: 6),
                      Text(str.scanAgain,
                          style: AppText.ui(13,
                              weight: FontWeight.w500,
                              color: AppColors.accentMono)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _trashSplit(AppLocalizations str, int freed, int inTrash, bool emptied) {
    Widget half(String big, Color color, String label) => Expanded(
          child: Column(
            children: [
              Text(big, style: AppText.mono(20, color: color)),
              const SizedBox(height: 4),
              Text(label,
                  style: AppText.ui(12, color: AppColors.faint),
                  textAlign: TextAlign.center),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.raisedAlt,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          half(_hero(freed), AppColors.safe, str.freed),
          Container(width: 1, height: 40, color: AppColors.border),
          half(emptied ? '0 GB' : _hero(inTrash), AppColors.accentMono,
              emptied ? str.trashEmptiedLbl : str.waiting),
        ],
      ),
    );
  }

  // ── Shared ────────────────────────────────────────────────────────────────
  Widget _gaugeCenter({
    required String kicker,
    required String value,
    required String sub,
    Color? subColor,
  }) {
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(kicker,
              style: AppText.mono(11,
                  letterSpacing: 2.4, color: AppColors.faintest)),
          if (value.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(value,
                style: AppText.space(44, wght: 600, color: AppColors.heroInk2)),
          ],
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(sub,
                style: AppText.mono(12, color: subColor ?? AppColors.faint)),
          ],
        ],
      ),
    );
  }
}

class _AccentButton extends StatelessWidget {
  final String label;
  final double height;
  final VoidCallback? onTap;
  const _AccentButton({required this.label, required this.height, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.accentGradient : null,
          color: enabled ? null : AppColors.raised,
          borderRadius: BorderRadius.circular(11),
          boxShadow: enabled
              ? [
                  BoxShadow(
                      color: AppColors.accentDark.withValues(alpha: 0.6),
                      blurRadius: 22,
                      offset: const Offset(0, 8))
                ]
              : null,
        ),
        child: Text(label,
            style: AppText.space(16,
                wght: 600,
                color: enabled ? const Color(0xFF0E1622) : AppColors.faintest2)),
      ),
    );
  }
}

/// Mono caption that pulses opacity .55↔1 (scanning readout). Static when
/// reduced motion is requested.
class _PulseLabel extends StatefulWidget {
  final String text;
  final bool reduced;
  const _PulseLabel({required this.text, required this.reduced});

  @override
  State<_PulseLabel> createState() => _PulseLabelState();
}

class _PulseLabelState extends State<_PulseLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduced) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = Text(widget.text,
        style: AppText.mono(12.5, color: AppColors.monoDim));
    if (widget.reduced) return label;
    return FadeTransition(
      opacity: Tween(begin: 0.55, end: 1.0).animate(_c),
      child: label,
    );
  }
}

class _DryToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _DryToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 18,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: value
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : AppColors.borderPreview,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: value ? AppColors.accentMono : AppColors.faintest,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text('Dry-run',
              style: AppText.mono(11,
                  color: value ? AppColors.accentMono : AppColors.faintest)),
        ],
      ),
    );
  }
}

class _EmptyTrashButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _EmptyTrashButton(
      {required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: enabled ? 0.10 : 0.04),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color: AppColors.danger.withValues(alpha: enabled ? 0.36 : 0.15)),
        ),
        child: Text(label,
            style: AppText.ui(13.5,
                weight: FontWeight.w600,
                color: enabled ? AppColors.dangerBright : AppColors.faintest2)),
      ),
    );
  }
}

/// Per-rule failure details on the Done screen: the rule that failed and the
/// raw engine/command error, so a silent failure becomes diagnosable.
class _FailureDetails extends StatelessWidget {
  final List<CleanFailure> failures;
  final AppLocalizations str;
  const _FailureDetails({required this.failures, required this.str});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.sunken,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.borderPreview),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < failures.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Text(str.ruleName(failures[i].ruleId),
                style: AppText.ui(12,
                    weight: FontWeight.w600, color: AppColors.rowName)),
            const SizedBox(height: 3),
            Text(failures[i].message,
                style: AppText.mono(11, color: AppColors.bodyDim, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String message;
  const _Error({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(message,
            textAlign: TextAlign.center,
            style: AppText.ui(15, color: AppColors.danger)),
      ),
    );
  }
}
