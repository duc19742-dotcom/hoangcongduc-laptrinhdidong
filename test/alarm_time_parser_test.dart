import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoang_cong_duc/services/alarm_time_parser.dart';

void main() {
  test('Parses Vietnamese and English times and AM/PM', () {
    final cases = <String, TimeOfDay>{
      'Báo thức 7 giờ 30 sáng': const TimeOfDay(hour: 7, minute: 30),
      'bảy giờ rưỡi tối': const TimeOfDay(hour: 19, minute: 30),
      'seven thirty PM': const TimeOfDay(hour: 19, minute: 30),
      'twelve AM': const TimeOfDay(hour: 0, minute: 0),
      '23:59': const TimeOfDay(hour: 23, minute: 59),
      'seven forty five AM': const TimeOfDay(hour: 7, minute: 45),
    };
    for (final entry in cases.entries) {
      expect(parseAlarmTime(entry.key), entry.value, reason: entry.key);
    }
  });
  test('Rejects absent and invalid times', () {
    for (final text in ['không có giờ', '25:30', '7:99', '19 PM']) {
      expect(parseAlarmTime(text), isNull, reason: text);
    }
  });
}
