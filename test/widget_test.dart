import 'package:controle_containers/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('abre a tela de login', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ControleContainersApp());
    await tester.pumpAndSettle();

    expect(find.text('Bem Vindo'), findsOneWidget);
    expect(find.text('Usuario'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Redefinir senha'), findsOneWidget);
  });
}
