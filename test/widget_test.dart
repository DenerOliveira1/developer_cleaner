import 'package:developer_cleaner/presentation/l10n/app_lang.dart';
import 'package:developer_cleaner/presentation/widgets/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TopBar language toggle reports the chosen language',
      (tester) async {
    AppLang? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TopBar(lang: AppLang.pt, onLang: (l) => picked = l),
      ),
    ));

    expect(find.text('PT'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);

    await tester.tap(find.text('EN'));
    expect(picked, AppLang.en);
  });
}
