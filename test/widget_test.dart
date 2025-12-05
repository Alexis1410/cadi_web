// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:cadi_admin_web/main.dart'; // 👈 nombre del paquete (revísalo en pubspec.yaml)

void main() {
  testWidgets('Panel CADI smoke test', (WidgetTester tester) async {
    // Construye la app
    await tester.pumpWidget(const CadiAdminWebApp());

    // Verifica que se muestre el título de la página de usuarios
    expect(find.text('Usuarios CADI (panel web)'), findsOneWidget);
  });
}