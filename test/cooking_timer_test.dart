import 'package:flutter_test/flutter_test.dart';
import 'package:kochmaster/features/meal_planning/domain/cooking_timer.dart';

void main() {
  test('timer calculates remaining time from a deadline', () {
    final timer = CookingTimer(300);
    timer.toggle();
    expect(timer.remaining, inInclusiveRange(299, 300));
  });

  test('pause and resume preserve the remaining time', () {
    final timer = CookingTimer(120);
    timer.toggle();
    expect(timer.running, isTrue);
    timer.toggle();
    expect(timer.running, isFalse);
    timer.toggle();
    expect(timer.running, isTrue);
  });

  test('reset restores the configured duration', () {
    final timer = CookingTimer(90);
    timer.toggle();
    timer.addMinute();
    timer.reset();
    expect(timer.remaining, 150);
    expect(timer.started, isFalse);
  });

  test('independent timers keep separate deadlines', () {
    final pasta = CookingTimer(600);
    final sauce = CookingTimer(180);
    pasta.toggle();
    sauce.toggle();
    expect(pasta.running, isTrue);
    expect(sauce.running, isTrue);
    pasta.toggle();
    expect(pasta.running, isFalse);
    expect(sauce.running, isTrue);
  });
}
