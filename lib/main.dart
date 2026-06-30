import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/injection.dart';
import 'l10n/app_localizations.dart';
import 'presentation/cubit/cleaner_cubit.dart';
import 'presentation/cubit/cleaner_state.dart';
import 'presentation/l10n/app_lang.dart';
import 'presentation/pages/cleaner_page.dart';
import 'presentation/theme/app_colors.dart';
import 'presentation/theme/app_text.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isMacOS) configureDependencies();
  runApp(const DevDiskApp());
}

class DevDiskApp extends StatelessWidget {
  const DevDiskApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) return const _UnsupportedApp();

    // BlocProvider sits above MaterialApp so changing the locale (driven by the
    // cubit's lang) rebuilds the app without disposing the cubit — selection
    // and scan results survive a language switch.
    return BlocProvider(
      create: (_) => getIt<CleanerCubit>()..init(),
      child: BlocBuilder<CleanerCubit, CleanerState>(
        buildWhen: (a, b) => a.lang != b.lang,
        builder: (context, state) {
          return MaterialApp(
            title: 'DevDisk Cleaner',
            debugShowCheckedModeBanner: false,
            locale: state.lang == AppLang.pt
                ? const Locale('pt')
                : const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: AppColors.pageMid,
            ),
            home: const Scaffold(body: CleanerPage()),
          );
        },
      ),
    );
  }
}

class _UnsupportedApp extends StatelessWidget {
  const _UnsupportedApp();

  @override
  Widget build(BuildContext context) {
    // No locale set → Flutter resolves the system locale against the supported
    // ones, so the abort message shows in the user's language.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        backgroundColor: AppColors.pageMid,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Builder(
              builder: (context) => Text(
                AppLocalizations.of(context).macosOnly,
                textAlign: TextAlign.center,
                style: AppText.ui(18, color: AppColors.danger),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
