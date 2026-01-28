import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// NOTA: Aquí YA NO importamos geolocator ni http. Dejamos que rastreo_screen se encargue.

import 'vision_screen.dart';
import 'rastreo_screen.dart';

void main() {
  runApp(const CortexApp());
}

class CortexApp extends StatelessWidget {
  const CortexApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Bloquear rotación
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    return MaterialApp(
      title: 'CÓRTEX OPERATIVO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0B1120),
          primaryColor: const Color(0xFF00F0FF),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Color(0xFF1E293B),
            selectedItemColor: Color(0xFF00F0FF),
            unselectedItemColor: Colors.grey,
          )),
      home: const MainMenu(),
    );
  }
}

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    VisionScreen(),
    const RastreoScreen(), // Aquí vive el GPS ahora
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack mantiene el estado de las pantallas para no reiniciar la cámara o el mapa
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.remove_red_eye),
            label: 'VISIÓN (LPR)',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radar),
            label: 'RASTREO (GPS)',
          ),
        ],
      ),
    );
  }
}
