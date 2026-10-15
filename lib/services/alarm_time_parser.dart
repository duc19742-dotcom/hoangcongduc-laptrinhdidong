import 'package:flutter/material.dart';

TimeOfDay? parseAlarmTime(String input) {
  var text = input.toLowerCase().trim();
  if (text.contains('không có') ||
      text.contains('không đặt') ||
      text.contains('-')) {
    return null;
  }
  const numbers = {
    'twenty three': '23',
    'twenty two': '22',
    'twenty one': '21',
    'twenty': '20',
    'nineteen': '19',
    'eighteen': '18',
    'seventeen': '17',
    'sixteen': '16',
    'fifteen': '15',
    'fourteen': '14',
    'thirteen': '13',
    'twelve': '12',
    'eleven': '11',
    'ten': '10',
    'nine': '9',
    'eight': '8',
    'seven': '7',
    'six': '6',
    'five': '5',
    'four': '4',
    'three': '3',
    'two': '2',
    'one': '1',
    'zero': '0',
    'hai mươi ba': '23',
    'hai mươi hai': '22',
    'hai mươi mốt': '21',
    'năm mươi': '50',
    'bốn mươi': '40',
    'ba mươi': '30',
    'hai mươi': '20',
    'mười chín': '19',
    'mười tám': '18',
    'mười bảy': '17',
    'mười sáu': '16',
    'mười lăm': '15',
    'mười bốn': '14',
    'mười ba': '13',
    'mười hai': '12',
    'mười một': '11',
    'mười': '10',
    'chín': '9',
    'tám': '8',
    'bảy': '7',
    'sáu': '6',
    'năm': '5',
    'bốn': '4',
    'ba': '3',
    'hai': '2',
    'một': '1',
    'không': '0',
    'fifty': '50',
    'forty': '40',
    'thirty': '30',
  };
  final phrases = numbers.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final phrase in phrases) {
    text = text.replaceAll(
      RegExp('(?<![a-zà-ỹ])${RegExp.escape(phrase)}(?![a-zà-ỹ])'),
      numbers[phrase]!,
    );
  }
  text = text.replaceAllMapped(
    RegExp(r'\b(20|30|40|50)\s+([1-9])\b'),
    (m) => '${int.parse(m[1]!) + int.parse(m[2]!)}',
  );
  final match = RegExp(
    r'(\d{1,2})(?:\s*(?:giờ|hours?|h|:|o.clock)\s*(\d{1,2})?|\s+(\d{1,2}))',
  ).firstMatch(text);
  final single = RegExp(r'\b(\d{1,2})\b').allMatches(text).toList();
  if (match == null && single.length != 1) return null;
  var hour = int.parse(match?[1] ?? single.first[1]!);
  var minute = int.tryParse(match?[2] ?? match?[3] ?? '') ?? 0;
  if (text.contains('rưỡi') || text.contains('half past')) minute = 30;
  final pm =
      RegExp(r'\b(p\.?m\.?)\b').hasMatch(text) ||
      text.contains('chiều') ||
      text.contains('tối');
  final am = RegExp(r'\b(a\.?m\.?)\b').hasMatch(text) || text.contains('sáng');
  if ((pm || am) && (hour < 1 || hour > 12)) return null;
  if (pm && hour < 12) hour += 12;
  if (am && hour == 12) hour = 0;
  if (hour > 23 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}
