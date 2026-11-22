class CookingTimer {
  CookingTimer(this.seconds) : pausedSeconds = seconds;

  int seconds;
  int pausedSeconds;
  DateTime? deadline;
  bool started = false;
  bool announced = false;

  DateTime _timeNow() => DateTime.now();

  int get remaining {
    if (deadline == null) return pausedSeconds;
    final diff = deadline!.difference(_timeNow()).inMilliseconds;
    return ((diff + 999) ~/ 1000).clamp(0, 86400).toInt();
  }

  bool get running => deadline != null && remaining > 0;

  void toggle({DateTime? now}) {
    final current = now ?? _timeNow();
    if (running) {
      pausedSeconds = remaining;
      deadline = null;
    } else {
      if (remaining == 0) pausedSeconds = seconds;
      deadline = current.add(Duration(seconds: pausedSeconds));
      started = true;
      announced = false;
    }
  }

  void addMinute({DateTime? now}) {
    final current = now ?? _timeNow();
    if (deadline != null) {
      deadline = current.add(Duration(seconds: remaining + 60));
    } else {
      pausedSeconds += 60;
    }
    seconds += 60;
    announced = false;
  }

  void reset() {
    deadline = null;
    pausedSeconds = seconds;
    started = false;
    announced = false;
  }
}
