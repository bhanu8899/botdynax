import 'package:botdynax/domain/entities/robot_status.dart';
import 'package:botdynax/presentation/home/widgets/robot_illustration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders with all five component faults active simultaneously', (WidgetTester tester) async {
    final RobotStatus status = RobotStatus.initial('r1', 'Test Robot').copyWith(
      faultCodes: const [18, 21, 24, 25, 46],
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: RobotIllustration(status: status)))),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('transitions cleanly as faults clear one by one', (WidgetTester tester) async {
    RobotStatus status = RobotStatus.initial('r1', 'Test Robot').copyWith(
      faultCodes: const [18, 21, 24, 25, 46],
    );

    Widget build() => MaterialApp(home: Scaffold(body: Center(child: RobotIllustration(status: status))));

    await tester.pumpWidget(build());
    await tester.pump(const Duration(milliseconds: 200));

    for (final int code in [18, 21, 24, 25, 46]) {
      status = status.copyWith(faultCodes: status.faultCodes.where((c) => c != code).toList());
      await tester.pumpWidget(build());
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    }
  });
}
