import 'package:get_it/get_it.dart';

import '../../data/datasources/system_cleaner_datasource.dart';
import '../../data/repositories/cleaner_repository_impl.dart';
import '../../domain/repositories/cleaner_repository.dart';
import '../../domain/usecases/clean_rules.dart';
import '../../domain/usecases/scan_rules.dart';
import '../../presentation/cubit/cleaner_cubit.dart';
import '../cleaner/disk_cleaner_engine.dart';
import '../process/process_runner.dart';

final GetIt getIt = GetIt.instance;

/// Manual dependency wiring (no injectable codegen). Order: process boundary →
/// engine → datasource → repository → use cases. The Cubit is created per-page
/// via [CleanerCubit] (registered as a factory in [_registerPresentation]).
void configureDependencies() {
  getIt
    ..registerLazySingleton<ProcessRunner>(() => const SystemProcessRunner())
    ..registerLazySingleton<CleanerEngine>(
        () => CleanerEngine(runner: getIt<ProcessRunner>()))
    ..registerLazySingleton<SystemCleanerDataSource>(
        () => SystemCleanerDataSource(getIt<CleanerEngine>()))
    ..registerLazySingleton<CleanerRepository>(
        () => CleanerRepositoryImpl(getIt<SystemCleanerDataSource>()))
    ..registerLazySingleton<ScanRules>(
        () => ScanRules(getIt<CleanerRepository>()))
    ..registerLazySingleton<CleanRules>(
        () => CleanRules(getIt<CleanerRepository>()));

  _registerPresentation();
}

/// Presentation-layer registrations. The Cubit is a factory so each app launch
/// gets a fresh instance over the singleton use cases/repository.
void _registerPresentation() {
  getIt.registerFactory<CleanerCubit>(() => CleanerCubit(
        scanRules: getIt<ScanRules>(),
        cleanRules: getIt<CleanRules>(),
        repository: getIt<CleanerRepository>(),
      ));
}
