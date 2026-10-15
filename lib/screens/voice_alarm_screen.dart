import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/alarm_time_parser.dart';

class VoiceAlarmScreen extends StatefulWidget {
  const VoiceAlarmScreen({super.key});
  @override
  State<VoiceAlarmScreen> createState() => _VoiceAlarmScreenState();
}

class _VoiceAlarmScreenState extends State<VoiceAlarmScreen> {
  final _speech = stt.SpeechToText();
  List<stt.LocaleName> _locales = [];
  String? _locale;
  String _text = 'Ví dụ: “7 giờ 30 sáng” hoặc “seven thirty PM”.';
  TimeOfDay? _time;
  bool _listening = false;
  bool _busy = false;
  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _listen() async {
    if (_listening) {
      await _speech.stop();
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!await Permission.microphone.request().isGranted) {
        _message(
          'Cần cho phép micro. Nếu đã chặn, mở Cài đặt ứng dụng để cấp quyền.',
        );
        return;
      }
      final available = await _speech.initialize(
        onStatus: (_) {
          if (mounted) setState(() => _listening = _speech.isListening);
        },
        onError: (error) {
          if (mounted) setState(() => _listening = false);
          _message('Nhận giọng nói: ${error.errorMsg}');
        },
      );
      if (!available) {
        _message('Thiết bị chưa có dịch vụ nhận giọng nói.');
        return;
      }
      final locales = (await _speech.locales())
          .where(
            (l) => l.localeId.startsWith('vi') || l.localeId.startsWith('en'),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _locales = locales;
        _locale ??=
            locales
                .where((l) => l.localeId.startsWith('vi'))
                .firstOrNull
                ?.localeId ??
            locales.firstOrNull?.localeId;
      });
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(localeId: _locale),
        onResult: (result) {
          if (!mounted) return;
          setState(() {
            _text = result.recognizedWords;
            _time = parseAlarmTime(_text);
          });
        },
      );
      if (mounted) setState(() => _listening = _speech.isListening);
    } catch (e) {
      _message('Không thể nhận giọng nói: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAlarm() async {
    final time = _time;
    if (time == null) return;
    try {
      await _speech.stop();
      await AndroidIntent(
        action: 'android.intent.action.SET_ALARM',
        arguments: {
          'android.intent.extra.alarm.HOUR': time.hour,
          'android.intent.extra.alarm.MINUTES': time.minute,
          'android.intent.extra.alarm.MESSAGE': 'Báo thức học tập',
          'android.intent.extra.alarm.SKIP_UI': false,
        },
      ).launch();
      _message(
        'Đã mở Đồng hồ. Kiểm tra và xác nhận báo thức trong ứng dụng Đồng hồ.',
      );
    } catch (e) {
      _message('Không mở được Đồng hồ để đặt báo thức: $e');
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Báo thức giọng nói')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Nói giờ bằng tiếng Việt hoặc tiếng Anh. Kiểm tra giờ trước khi đặt. Lần đầu bấm micro sẽ tải danh sách ngôn ngữ nhận diện trên điện thoại.',
        ),
        if (_locales.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: _locale,
            isExpanded: true,
            items: _locales
                .map(
                  (l) => DropdownMenuItem(
                    value: l.localeId,
                    child: Text(l.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _listening
                ? null
                : (value) => setState(() => _locale = value),
          ),
        const SizedBox(height: 20),
        Text(
          _time?.format(context) ?? 'Chưa chọn giờ',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 16),
        Text(_text),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy ? null : _listen,
          icon: Icon(_listening ? Icons.stop : Icons.mic),
          label: Text(_listening ? 'Dừng nghe' : 'Nói để chọn giờ'),
        ),
        OutlinedButton(
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _time ?? TimeOfDay.now(),
            );
            if (mounted && picked != null) setState(() => _time = picked);
          },
          child: const Text('Chọn / sửa giờ thủ công'),
        ),
        FilledButton.icon(
          onPressed: _time == null ? null : _setAlarm,
          icon: const Icon(Icons.alarm_add),
          label: const Text('Đặt trong Đồng hồ điện thoại'),
        ),
      ],
    ),
  );
}
