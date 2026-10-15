import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class MlkitTranslateScreen extends StatefulWidget {
  const MlkitTranslateScreen({super.key});
  @override
  State<MlkitTranslateScreen> createState() => _MlkitTranslateScreenState();
}

class _MlkitTranslateScreenState extends State<MlkitTranslateScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _languages = {
    TranslateLanguage.vietnamese: 'Tiếng Việt',
    TranslateLanguage.english: 'English',
    TranslateLanguage.french: 'Français',
    TranslateLanguage.german: 'Deutsch',
    TranslateLanguage.spanish: 'Español',
  };
  late final TabController _tabs;
  final _input = TextEditingController();
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();
  final _models = OnDeviceTranslatorModelManager();
  TranslateLanguage _source = TranslateLanguage.english;
  TranslateLanguage _target = TranslateLanguage.vietnamese;
  String _result = '';
  String _status = '';
  String _cameraText = '';
  String _cameraTranslation = '';
  bool _busy = false;
  bool _listening = false;
  bool _startingCamera = false;
  bool _streaming = false;
  CameraController? _camera;
  Future<void>? _cameraWork;
  Future<void>? _stopWork;
  bool _disposed = false;
  int _cameraGeneration = 0;
  bool get _alive => mounted && !_disposed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs = TabController(length: 3, vsync: this)..addListener(_tabChanged);
  }

  void _tabChanged() {
    if (_tabs.index != 2) unawaited(_stopCamera());
    if (_tabs.index != 0) unawaited(_speech.stop());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_stopCamera());
      unawaited(_speech.stop());
    }
  }

  void _message(String text) {
    if (_alive) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<bool> _permission(Permission permission, String name) async {
    final granted = await permission.request().isGranted;
    if (!granted) {
      _message(
        'Cần cấp quyền $name. Nếu đã chặn, mở Cài đặt ứng dụng để cấp quyền.',
      );
    }
    return granted;
  }

  Future<void> _ensureModels(
    TranslateLanguage source,
    TranslateLanguage target,
  ) async {
    for (final language in {source, target}) {
      if (language == TranslateLanguage.english) continue;
      if (!await _models.isModelDownloaded(language.bcpCode)) {
        if (_alive) {
          setState(
            () => _status =
                'Đang tải model ${_languages[language]}… Cần Internet lần đầu.',
          );
        }
        final downloaded = await _models.downloadModel(
          language.bcpCode,
          isWifiRequired: false,
        );
        if (!downloaded) {
          throw Exception(
            'Không tải được model ${_languages[language]}. Kiểm tra Internet và thử lại.',
          );
        }
      }
    }
  }

  Future<String> _translate(
    String text,
    TranslateLanguage source,
    TranslateLanguage target,
  ) async {
    if (source == target) return text;
    await _ensureModels(source, target);
    final translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );
    try {
      return await translator.translateText(text);
    } finally {
      await translator.close();
    }
  }

  Future<String> _recognize(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      return (await recognizer.processImage(InputImage.fromFilePath(path)))
          .text;
    } finally {
      await recognizer.close();
    }
  }

  Future<void> _translateInput() async {
    if (_busy || _input.text.trim().isEmpty) return;
    final source = _source, target = _target;
    final text = _input.text.trim();
    setState(() {
      _busy = true;
      _status = 'Đang dịch…';
    });
    try {
      final translated = await _translate(text, source, target);
      if (_alive) {
        setState(() {
          _result = translated;
          _status = 'Đã dịch';
        });
      }
    } catch (e) {
      if (_alive) setState(() => _status = 'Không dịch được: $e');
    } finally {
      if (_alive) setState(() => _busy = false);
    }
  }

  Future<void> _listen() async {
    if (_listening) {
      await _speech.stop();
      return;
    }
    if (_busy) return;
    try {
      if (!await _permission(Permission.microphone, 'micro')) return;
      final ready = await _speech.initialize(
        onStatus: (_) {
          if (_alive) setState(() => _listening = _speech.isListening);
        },
        onError: (e) {
          if (_alive) setState(() => _listening = false);
          _message('Giọng nói: ${e.errorMsg}');
        },
      );
      if (!ready) {
        _message('Nhận giọng nói không khả dụng trên điện thoại.');
        return;
      }
      final locales = await _speech.locales();
      final locale = locales
          .where(
            (l) => l.localeId.replaceAll('_', '-').startsWith(_source.bcpCode),
          )
          .firstOrNull;
      if (locale == null) {
        _message('Điện thoại chưa hỗ trợ giọng nói ${_languages[_source]}.');
        return;
      }
      if (!_alive) return;
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(localeId: locale.localeId),
        onResult: (result) {
          if (!_alive) return;
          setState(() => _input.text = result.recognizedWords);
          if (result.finalResult) unawaited(_translateInput());
        },
      );
      if (_alive) setState(() => _listening = _speech.isListening);
    } catch (e) {
      _message('Không nhận được giọng nói: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'Đang đọc ảnh…';
    });
    final from = _source, to = _target;
    try {
      if (source == ImageSource.camera &&
          !await _permission(Permission.camera, 'camera')) {
        return;
      }
      final image = await ImagePicker().pickImage(source: source);
      if (image == null) {
        if (_alive) setState(() => _status = 'Đã hủy chọn ảnh');
        return;
      }
      final text = await _recognize(image.path);
      if (text.trim().isEmpty) {
        if (_alive) {
          setState(
            () => _status = 'Không tìm thấy chữ. Chụp rõ hơn và đủ ánh sáng.',
          );
        }
        return;
      }
      final translated = await _translate(text, from, to);
      if (_alive) {
        setState(() {
          _input.text = text;
          _result = translated;
          _status = 'Đã đọc và dịch ảnh';
        });
      }
    } catch (e) {
      if (_alive) setState(() => _status = 'Không xử lý được ảnh: $e');
    } finally {
      if (_alive) setState(() => _busy = false);
    }
  }

  Future<void> _startCamera() async {
    if (_startingCamera || _streaming || _stopWork != null) return;
    setState(() {
      _startingCamera = true;
      _status = 'Đang chuẩn bị camera…';
    });
    final generation = ++_cameraGeneration;
    CameraController? controller;
    try {
      if (!await _permission(Permission.camera, 'camera')) return;
      await _ensureModels(_source, _target);
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('Không tìm thấy camera');
      final back =
          cameras
              .where((c) => c.lensDirection == CameraLensDirection.back)
              .firstOrNull ??
          cameras.first;
      controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!_alive || _tabs.index != 2 || generation != _cameraGeneration) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _streaming = true;
        _status = 'Hướng camera vào chữ; bản dịch tự cập nhật.';
      });
      _cameraWork = _scanCamera(controller);
    } catch (e) {
      await controller?.dispose();
      if (_alive) setState(() => _status = 'Không mở được camera: $e');
    } finally {
      if (_alive) setState(() => _startingCamera = false);
    }
  }

  // Continuous snapshots use ML Kit's file input, avoiding device-specific
  // YUV/NV21 layouts. Each frame is processed before capturing the next one.
  Future<void> _scanCamera(CameraController controller) async {
    String previousText = '';
    while (_alive && _streaming && identical(_camera, controller)) {
      XFile? frame;
      try {
        frame = await controller.takePicture();
        final text = await _recognize(frame.path);
        if (!_alive || !_streaming) break;
        if (text.trim().isNotEmpty && text != previousText) {
          final translated = await _translate(text, _source, _target);
          if (!_alive || !_streaming) break;
          previousText = text;
          setState(() {
            _cameraText = text;
            _cameraTranslation = translated;
            _status = 'Đã cập nhật bản dịch camera';
          });
        } else if (text.trim().isEmpty) {
          previousText = '';
          setState(() {
            _cameraText = '';
            _cameraTranslation = '';
            _status = 'Chưa thấy chữ. Giữ camera ổn định và đủ sáng.';
          });
        }
      } catch (e) {
        if (_alive && _streaming) {
          setState(() => _status = 'Quét camera gặp lỗi: $e');
        }
      } finally {
        if (frame != null) {
          try {
            await File(frame.path).delete();
          } catch (_) {}
        }
      }
      if (_streaming) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
    }
  }

  Future<void> _stopCamera() async {
    _cameraGeneration++;
    if (_stopWork != null) return _stopWork;
    final controller = _camera;
    _streaming = false;
    if (_alive) setState(() {});
    if (controller == null) return;
    final work = _finishCamera(controller);
    _stopWork = work;
    try {
      await work;
    } finally {
      _stopWork = null;
    }
  }

  Future<void> _finishCamera(CameraController controller) async {
    await _cameraWork;
    await controller.dispose();
    _cameraWork = null;
    if (identical(_camera, controller)) _camera = null;
    if (_alive) setState(() {});
  }

  Future<void> _speak() async {
    if (_result.isEmpty) return;
    try {
      await _tts.setLanguage(_target.bcpCode);
      await _tts.speak(_result);
    } catch (e) {
      _message('Không đọc được bản dịch: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _tabs.removeListener(_tabChanged);
    _tabs.dispose();
    _input.dispose();
    unawaited(_speech.cancel());
    unawaited(_tts.stop());
    unawaited(_stopCamera());
    super.dispose();
  }

  Widget _languagePicker(
    TranslateLanguage value,
    ValueChanged<TranslateLanguage?> changed,
  ) => Expanded(
    child: DropdownButton<TranslateLanguage>(
      value: value,
      isExpanded: true,
      items: _languages.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: _busy || _listening || _streaming || _startingCamera
          ? null
          : changed,
    ),
  );

  Widget _results() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Bản dịch', style: TextStyle(fontWeight: FontWeight.bold)),
      SelectableText(_result.isEmpty ? 'Kết quả sẽ hiển thị ở đây' : _result),
      TextButton.icon(
        onPressed: _result.isEmpty ? null : _speak,
        icon: const Icon(Icons.volume_up),
        label: const Text('Đọc bản dịch'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Dịch thuật ML Kit'),
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: 'Text / Giọng nói'),
          Tab(text: 'Ảnh'),
          Tab(text: 'Camera'),
        ],
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _languagePicker(_source, (v) {
                if (v != null) {
                  setState(() {
                    _source = v;
                    _result = '';
                  });
                }
              }),
              const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_forward),
              ),
              _languagePicker(_target, (v) {
                if (v != null) {
                  setState(() {
                    _target = v;
                    _result = '';
                  });
                }
              }),
            ],
          ),
        ),
        if (_busy || _startingCamera) const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _status.isEmpty
                ? 'Cần Internet lần đầu để tải model dịch.'
                : _status,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _input,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Nhập nội dung cần dịch',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _busy || _listening ? null : _translateInput,
                        child: const Text('Dịch'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _listen,
                        icon: Icon(_listening ? Icons.stop : Icons.mic),
                        label: Text(
                          _listening ? 'Dừng nghe' : 'Nhận giọng nói',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _results(),
                ],
              ),
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Chụp rõ chữ tiếng Việt / Anh hoặc chữ Latin. Chọn ngôn ngữ nguồn đúng với ảnh.',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Chụp ảnh'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo),
                        label: const Text('Thư viện'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Chữ nhận diện',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText(_input.text),
                  const SizedBox(height: 20),
                  _results(),
                ],
              ),
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_streaming &&
                      _camera != null &&
                      _camera!.value.isInitialized)
                    SizedBox(
                      height: 280,
                      child: ClipRect(child: CameraPreview(_camera!)),
                    ),
                  FilledButton.icon(
                    onPressed: _startingCamera
                        ? null
                        : (_streaming ? _stopCamera : _startCamera),
                    icon: Icon(_streaming ? Icons.stop : Icons.videocam),
                    label: Text(_streaming ? 'Dừng camera' : 'Bật dịch camera'),
                  ),
                  const Text(
                    'Giữ máy ổn định. Quét và dịch liên tục, mỗi lượt khoảng 1–3 giây.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chữ trên camera',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText(_cameraText),
                  const SizedBox(height: 12),
                  const Text(
                    'Bản dịch trực tiếp',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText(_cameraTranslation),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
