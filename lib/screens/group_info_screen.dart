import 'package:flutter/material.dart';

class Member {
  final String name;
  final String studentId;
  final String role;
  final String faculty;
  final String email;
  final String avatarUrl;
  final String bio;

  const Member({
    required this.name,
    required this.studentId,
    required this.role,
    required this.faculty,
    required this.email,
    required this.avatarUrl,
    required this.bio,
  });
}

class GroupInfoScreen extends StatefulWidget {
  const GroupInfoScreen({super.key});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final List<Member> _members = const [
    Member(
      name: 'Hoàng Công Đức',
      studentId: 'Chưa cập nhật',
      role: 'Trưởng Nhóm (Leader)',
      faculty: 'Công Nghệ Thông Tin',
      email: 'duc197421@gmail.com',
      avatarUrl: 'images/school.png',
      bio: 'Lập trình viên Flutter & Phát triển ứng dụng di động.',
    ),
    Member(
      name: 'Nguyễn Minh Anh (mẫu)',
      studentId: '2180600002 (mẫu)',
      role: 'Thành Viên (Developer)',
      faculty: 'Công Nghệ Thông Tin',
      email: 'minhanh@example.com',
      avatarUrl: 'images/school.png',
      bio: 'Phát triển Giao diện (UI/UX) và Tích hợp ML Kit.',
    ),
    Member(
      name: 'Trần Thu Hà (mẫu)',
      studentId: '2180600003 (mẫu)',
      role: 'Thành Viên (Tester)',
      faculty: 'Công Nghệ Thông Tin',
      email: 'thuha@example.com',
      avatarUrl: 'images/school.png',
      bio: 'Kiểm thử ứng dụng & Xây dựng kịch bản báo thức.',
    ),
    Member(
      name: 'Lê Quốc Bảo (mẫu)',
      studentId: '2180600004 (mẫu)',
      role: 'Thành viên (Developer)',
      faculty: 'Công Nghệ Thông Tin',
      email: 'quocbao@example.com',
      avatarUrl: 'images/school.png',
      bio: 'Tích hợp nhận diện giọng nói và dịch camera.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[100],
      appBar: AppBar(
        title: const Text('Thông Tin Nhóm Phát Triển'),
        centerTitle: true,
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 15.0),
            child: Text(
              '👉 Vuốt ngang để xem thành viên tiếp theo',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _members.length,
              itemBuilder: (context, index) {
                final member = _members[index];
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Ảnh đại diện
                            CircleAvatar(
                              radius: 65,
                              backgroundImage:
                                  member.avatarUrl.startsWith('http')
                                  ? NetworkImage(member.avatarUrl)
                                        as ImageProvider
                                  : AssetImage(member.avatarUrl),
                              backgroundColor: Colors.grey.shade200,
                            ),
                            const SizedBox(height: 15),

                            // Tên thành viên
                            Text(
                              member.name,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 5),

                            // Vai trò trong nhóm
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade100,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                member.role,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Chi tiết thông tin
                            _buildDetailRow(
                              Icons.badge,
                              'MSSV: ${member.studentId}',
                            ),
                            _buildDetailRow(
                              Icons.school,
                              'Khoa: ${member.faculty}',
                            ),
                            _buildDetailRow(Icons.email, member.email),
                            const Divider(height: 30),

                            // Tiểu sử / Nhiệm vụ
                            Text(
                              member.bio,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
