import 'package:flutter/material.dart';

import '../services/auth_service.dart';

import 'temperature_converter_screen.dart';
import 'unit_converter_screen.dart';
import 'voice_alarm_screen.dart';
import 'mlkit_translate_screen.dart';
import 'information_screen.dart';
import 'group_info_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.auth});
  final AuthService? auth;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _widgetOptions = <Widget>[
    const TemperatureConverterScreen(), // Tab 1: Nhiệt độ
    const UnitConverterScreen(), // Tab 2: Đơn vị
    const VoiceAlarmScreen(), // Tab 3: Báo thức Giọng nói
    const MlkitTranslateScreen(), // Tab 4: ML Kit Dịch thuật
    InformationScreen(auth: widget.auth), // Tab 5: Cá nhân
    const GroupInfoScreen(), // Tab 6: Nhóm
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.thermostat),
            label: 'Nhiệt độ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz),
            label: 'Đơn vị',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.alarm), label: 'Báo thức'),
          BottomNavigationBarItem(
            icon: Icon(Icons.g_translate),
            label: 'Dịch thuật',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Cá nhân'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Nhóm'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
