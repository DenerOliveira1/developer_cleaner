// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get breakdown => 'Detalhamento do disco';

  @override
  String get used => 'USADO';

  @override
  String diskSub(String free, String total) {
    return '$free livres · $total no total';
  }

  @override
  String get reclaimRest => 'recuperáveis de lixo de dev';

  @override
  String get scan => 'Escanear';

  @override
  String get reversible =>
      'Os itens vão para a Lixeira — você pode restaurá-los.';

  @override
  String get scanning => 'ESCANEANDO';

  @override
  String reading(String rule) {
    return 'Lendo $rule…';
  }

  @override
  String get cleanup => 'Limpeza';

  @override
  String get selected => 'selecionado';

  @override
  String get cleanSelected => 'Limpar selecionados';

  @override
  String get nothing => 'Nada para limpar aqui.';

  @override
  String get cleaning => 'LIMPANDO';

  @override
  String get stepOf => 'de';

  @override
  String get freeNow => 'LIVRE AGORA';

  @override
  String returnedReal(String freed) {
    return '+$freed devolvidos ao disco';
  }

  @override
  String get complete => 'LIMPEZA CONCLUÍDA';

  @override
  String get reclaimable => 'recuperáveis';

  @override
  String get freed => 'liberados';

  @override
  String get waiting => 'aguardando na Lixeira';

  @override
  String get trashEmptiedLbl => 'Lixeira esvaziada';

  @override
  String get emptyCta => 'Esvaziar a Lixeira para liberar de vez';

  @override
  String get trashEmpty => 'Lixeira vazia';

  @override
  String get recoverNote =>
      'Itens na Lixeira são recuperáveis até você esvaziá-la.';

  @override
  String removeTitle(String name) {
    return 'Remover $name?';
  }

  @override
  String get reviewed => 'Revisei os itens acima.';

  @override
  String get cancel => 'Cancelar';

  @override
  String moveTrash(String size) {
    return 'Mover $size para a Lixeira';
  }

  @override
  String get removePermanently => 'Remover permanentemente';

  @override
  String get permanentWarning => 'Permanente — não vai para a Lixeira.';

  @override
  String keeps(String version) {
    return 'Mantém $version';
  }

  @override
  String get eTitle => 'Esvaziar a Lixeira?';

  @override
  String get eBody1 => 'Isto apaga permanentemente ';

  @override
  String get eBody2 => ' de itens na Lixeira. Este é o único passo que ';

  @override
  String get eCant => 'não pode ser desfeito';

  @override
  String get eBody3 => ' — tudo antes dele era recuperável.';

  @override
  String get keepTrash => 'Manter na Lixeira';

  @override
  String get emptyTrash => 'Esvaziar Lixeira';

  @override
  String get genericError => 'Algo deu errado.';

  @override
  String get scanAgain => 'Escanear novamente';

  @override
  String cleanFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count regras não puderam ser limpas',
      one: '1 regra não pôde ser limpa',
    );
    return '$_temp0';
  }

  @override
  String badge(String safety) {
    String _temp0 = intl.Intl.selectLogic(safety, {
      'safe': 'SEGURO',
      'confirm': 'CONFIRMAR',
      'danger': 'PERIGO',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String category(String key) {
    String _temp0 = intl.Intl.selectLogic(key, {
      'xcode': 'Xcode / Simuladores',
      'caches': 'Caches',
      'androidSdk': 'Android SDK',
      'appSupport': 'Suporte de apps (IDEs)',
      'free': 'Livre',
      'other': 'Outros / Sistema',
    });
    return '$_temp0';
  }

  @override
  String ruleName(String ruleId) {
    String _temp0 = intl.Intl.selectLogic(ruleId, {
      'derived': 'Xcode DerivedData',
      'simun': 'Simuladores indisponíveis',
      'coresim': 'Caches do CoreSimulator',
      'gradle': 'Caches do Gradle',
      'brew': 'Limpeza do Homebrew',
      'intellij': 'IntelliJ — versões antigas',
      'studio': 'Android Studio — versões antigas',
      'ndk': 'Android NDK — versões antigas',
      'docker': 'Docker — prune (sem volumes)',
      'simruntime': 'Simulador iOS — runtimes antigos',
      'flutter': 'Flutter — build/.dart_tool',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String ruleDesc(String ruleId) {
    String _temp0 = intl.Intl.selectLogic(ruleId, {
      'derived': 'Intermediários de build que o Xcode recria no próximo build.',
      'simun': 'Runtimes de simulador sem suporte no seu Xcode.',
      'coresim': 'Dados de simulador em cache e snapshots de dispositivos.',
      'gradle': 'Dependências baixadas que o Gradle rebaixa quando preciso.',
      'brew': 'Downloads antigos e versões obsoletas de fórmulas.',
      'intellij': 'Caches e plugins de versões da IDE que você não usa mais.',
      'studio': 'Caches de versões do Android Studio que você já substituiu.',
      'ndk':
          'O NDK certo depende do ndkVersion dos seus projetos. Revise antes de remover.',
      'docker':
          'Imagens órfãs e camadas de build paradas. Volumes nomeados não são tocados.',
      'simruntime':
          'Mantém só o iOS mais recente; remove os runtimes antigos do simulador. Irreversível.',
      'flutter':
          'build/ e .dart_tool/ de todos os projetos Flutter (recriáveis no próximo build).',
      'other': '',
    });
    return '$_temp0';
  }
}
