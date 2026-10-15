import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';

import '../services/auth_service.dart';

class InformationScreen extends StatelessWidget {
  const InformationScreen({super.key, this.auth});
  final AuthService? auth;

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
        throw Exception('Không có ứng dụng gọi điện');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không mở được gọi điện: $e')));
      }
    }
  }

  Future<void> _openYoutube(BuildContext context) async {
    try {
      await const AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'https://www.youtube.com',
        package: 'com.google.android.youtube',
      ).launch();
    } catch (_) {
      try {
        final opened = await launchUrl(
          Uri.parse('https://www.youtube.com'),
          mode: LaunchMode.externalApplication,
        );
        if (!opened) throw Exception('Không mở được YouTube');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không mở được app YouTube; đã mở đường dẫn YouTube.',
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Không mở được YouTube: $e')));
        }
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      await launchUrl(emailUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        title: const Text('Thông Tin Cá Nhân'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withAlpha(128),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (auth?.user != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 12,
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.verified_user,
                        color: Colors.teal,
                      ),
                      title: Text('Đã đăng nhập: ${auth!.user!['name']}'),
                      subtitle: Text(
                        '${auth!.user!['username']} • ${auth!.user!['phone']}',
                      ),
                    ),
                  ),
                // Hình đại diện
                const CircleAvatar(
                  radius: 70.0,
                  backgroundImage: AssetImage('images/school.png'),
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 15.0),

                // Họ tên
                const Text(
                  'Hoàng Công Đức',
                  style: TextStyle(
                    fontSize: 28.0,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5.0),

                // Khoa
                Text(
                  'Khoa: Công Nghệ Thông Tin',
                  style: TextStyle(
                    color: Colors.teal.shade700,
                    fontSize: 18.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(
                  height: 20.0,
                  width: 250.0,
                  child: Divider(color: Colors.teal.shade200, thickness: 1),
                ),

                // Card thông tin liên lạc (Gọi điện)
                InfoCard(
                  text: '0965673905 (Bấm để gọi)',
                  icon: Icons.phone,
                  onPressed: () => _makePhoneCall(context, '0965673905'),
                ),

                // Card thông tin liên lạc (Email)
                InfoCard(
                  text: 'duc197421@gmail.com',
                  icon: Icons.email,
                  onPressed: () => _sendEmail('duc197421@gmail.com'),
                ),

                const SizedBox(height: 15.0),

                // Nút Mở Youtube
                ElevatedButton.icon(
                  onPressed: () => _openYoutube(context),
                  icon: const Icon(Icons.play_circle_fill, color: Colors.white),
                  label: const Text(
                    'Mở Ứng Dụng YouTube',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                ),

                const SizedBox(height: 15.0),

                // Nút Đăng xuất
                ElevatedButton.icon(
                  onPressed: auth == null
                      ? null
                      : () async {
                          try {
                            await auth!.logout();
                          } catch (_) {
                            // The local session is cleared even if the server is offline.
                          }
                        },
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'Đăng Xuất',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget tái sử dụng cho các thẻ thông tin (Điện thoại, Email)
class InfoCard extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;

  const InfoCard({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 25.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        onTap: onPressed,
        leading: Icon(icon, color: Colors.teal),
        title: Text(
          text,
          style: TextStyle(color: Colors.teal.shade900, fontSize: 16.0),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.teal,
        ),
      ),
    );
  }
}
