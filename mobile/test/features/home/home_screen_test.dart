import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute_ludo/features/home/screens/home_screen.dart';

// ─── Widget pump helper ───────────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: HomeScreen()),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  testWidgets('smoke — renders without crashing', (tester) async {
    await _pump(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('shows the game title', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('home_title')), findsOneWidget);
    expect(find.text('1 Minute Ludo'), findsOneWidget);
  });

  testWidgets('shows the coming-soon tagline', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('home_tagline')), findsOneWidget);
    expect(find.text('Game lobby coming soon'), findsOneWidget);
  });

  testWidgets('shows the game controller icon', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('home_icon')), findsOneWidget);
  });
}
