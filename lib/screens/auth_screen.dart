import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth});
  final AuthService auth;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  bool _register = false, _busy = false, _hidePassword = true, _consent = false;
  String? _error;
  Map<String, dynamic>? _challenge;
  Timer? _timer;
  DateTime? _resendAt, _expiresAt;
  int _seconds = 0, _expiresIn = 0;

  void _startClock({bool newChallenge = false}) {
    _resendAt = DateTime.now().add(const Duration(seconds: 60));
    if (newChallenge) {
      _expiresAt = DateTime.now().add(
        Duration(seconds: _challenge!['expiresIn'] as int),
      );
    }
    _seconds = 60;
    _expiresIn = _remaining(_expiresAt);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _seconds = _remaining(_resendAt);
          _expiresIn = _remaining(_expiresAt);
        });
      }
    });
  }

  int _remaining(DateTime? until) => until == null
      ? 0
      : (until.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(
          0,
          300,
        );

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_challenge == null && _register && !_consent) {
      setState(() => _error = 'Vui lòng đồng ý nhận SMS xác minh.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_challenge != null) {
        await widget.auth.verify(
          _challenge!['challengeId'] as String,
          _code.text.trim(),
        );
      } else {
        final result = _register
            ? await widget.auth.register(
                name: _name.text.trim(),
                username: _username.text.trim(),
                phone: _phone.text.trim(),
                password: _password.text,
              )
            : await widget.auth.login(_username.text.trim(), _password.text);
        if (!mounted) return;
        setState(() {
          _challenge = result;
          _password.clear();
          _confirm.clear();
          _code.clear();
        });
        _startClock(newChallenge: true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _seconds > 0 || _expiresIn == 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.resend(_challenge!['challengeId'] as String);
      if (!mounted) return;
      setState(() {
        _code.clear();
        _startClock();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã yêu cầu gửi lại SMS OTP.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() {
    _timer?.cancel();
    setState(() {
      _challenge = null;
      _error = null;
      _code.clear();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_name, _username, _phone, _password, _confirm, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    bool secret = false,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !_busy,
      keyboardType: keyboard,
      obscureText: secret && _hidePassword,
      autocorrect: !secret,
      enableSuggestions: !secret,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        suffixIcon: secret
            ? IconButton(
                tooltip: _hidePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
                icon: Icon(
                  _hidePassword ? Icons.visibility : Icons.visibility_off,
                ),
              )
            : null,
      ),
      validator:
          validator ??
          (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập $label.' : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final otp = _challenge != null;
    return PopScope(
      canPop: !otp,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy) _back();
      },
      child: Scaffold(
        backgroundColor: const Color(0xffeef4f8),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            otp
                                ? Icons.sms_outlined
                                : Icons.lock_person_outlined,
                            size: 56,
                            color: Colors.teal,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            otp
                                ? 'Xác minh OTP'
                                : (_register
                                      ? 'Đăng ký tài khoản'
                                      : 'Đăng nhập'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            otp
                                ? 'Nhập mã SMS gửi đến ${_challenge!['maskedPhone']} để hoàn tất xác thực.'
                                : 'Đăng nhập bằng tài khoản và mật khẩu, sau đó xác minh bằng SMS OTP.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          if (!otp) ...[
                            if (_register)
                              _field(
                                _name,
                                'Họ tên',
                                Icons.person_outline,
                                validator: (v) =>
                                    v == null ||
                                        v.trim().isEmpty ||
                                        v.trim().length > 80
                                    ? 'Nhập họ tên từ 1–80 ký tự.'
                                    : null,
                              ),
                            _field(
                              _username,
                              'Tài khoản',
                              Icons.account_circle_outlined,
                              validator: (v) =>
                                  !RegExp(r'^[a-zA-Z0-9_]{3,30}$')
                                      .hasMatch(v?.trim() ?? '')
                                  ? 'Dùng 3–30 chữ không dấu, số hoặc dấu _.'
                                  : null,
                            ),
                            if (_register)
                              _field(
                                _phone,
                                'Số điện thoại',
                                Icons.phone_outlined,
                                keyboard: TextInputType.phone,
                                validator: (v) =>
                                    !RegExp(r'^(0|\+84)[35789]\d{8}$').hasMatch(
                                      (v ?? '').replaceAll(
                                        RegExp(r'[\s().-]'),
                                        '',
                                      ),
                                    )
                                    ? 'Nhập số Việt Nam dạng 09… hoặc +849….'
                                    : null,
                              ),
                            _field(
                              _password,
                              'Mật khẩu',
                              Icons.lock_outline,
                              secret: true,
                              validator: (v) =>
                                  v == null || v.length < 8 || v.length > 128
                                  ? 'Mật khẩu gồm 8–128 ký tự.'
                                  : null,
                            ),
                            if (_register) ...[
                              _field(
                                _confirm,
                                'Nhập lại mật khẩu',
                                Icons.lock_outline,
                                secret: true,
                                validator: (v) => v != _password.text
                                    ? 'Mật khẩu không trùng khớp.'
                                    : null,
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _consent,
                                onChanged: _busy
                                    ? null
                                    : (v) =>
                                          setState(() => _consent = v ?? false),
                                title: const Text(
                                  'Tôi đồng ý nhận SMS OTP để xác minh đăng ký và đăng nhập.',
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ],
                          ] else ...[
                            TextFormField(
                              controller: _code,
                              enabled: !_busy && _expiresIn > 0,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              style: const TextStyle(
                                fontSize: 28,
                                letterSpacing: 8,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Mã OTP 6 chữ số',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  !RegExp(r'^\d{6}$').hasMatch(v ?? '')
                                  ? 'Nhập đủ 6 chữ số.'
                                  : null,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _expiresIn > 0
                                  ? 'Thời gian xác minh còn $_expiresIn giây.'
                                  : 'Yêu cầu đã hết hạn. Hãy quay lại đăng nhập.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy || (otp && _expiresIn == 0)
                                ? null
                                : _submit,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: _busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      otp
                                          ? 'Xác minh và đăng nhập'
                                          : (_register
                                                ? 'Đăng ký và gửi OTP'
                                                : 'Đăng nhập và gửi OTP'),
                                    ),
                            ),
                          ),
                          if (otp) ...[
                            TextButton(
                              onPressed:
                                  _busy || _seconds > 0 || _expiresIn == 0
                                  ? null
                                  : _resend,
                              child: Text(
                                _seconds > 0
                                    ? 'Gửi lại sau $_seconds giây'
                                    : 'Gửi lại OTP',
                              ),
                            ),
                            TextButton(
                              onPressed: _busy ? null : _back,
                              child: const Text('Quay lại đăng nhập'),
                            ),
                          ] else
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      setState(() {
                                        _register = !_register;
                                        _error = null;
                                        _password.clear();
                                        _confirm.clear();
                                      });
                                      _form.currentState?.reset();
                                    },
                              child: Text(
                                _register
                                    ? 'Đã có tài khoản? Đăng nhập'
                                    : 'Chưa có tài khoản? Đăng ký',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
