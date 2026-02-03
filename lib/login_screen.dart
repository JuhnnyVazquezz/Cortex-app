import 'dart:convert';
import 'dart:ui'; // Necesario para el efecto Glass
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'vision_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _cargando = false;

  // ⚠️ CORRECCIÓN TÁCTICA:
  // Al usar 'adb reverse', el celular DEBE apuntar a localhost (127.0.0.1)
  final String baseUrl = "http://10.20.36.28:8000";

  // Colores Tácticos
  final Color kDarkBg = Color(0xFF0B1120);
  final Color kNeonBlue = Color(0xFF00F0FF); // Cian Cibernético

  Future<void> _iniciarSesion() async {
    setState(() => _cargando = true);
    try {
      // Nota: http.post envía por defecto como x-www-form-urlencoded cuando el body es un Mapa
      var response = await http.post(Uri.parse("$baseUrl/token"), body: {
        // Agregamos /token
        'username': _userController.text.trim(),
        'password': _passController.text.trim(),
      });

      if (response.statusCode == 200) {
        // Éxito: Navegar a la pantalla de Visión
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => VisionScreen()));
      } else {
        _mostrarError("ACCESO DENEGADO: Credenciales incorrectas");
      }
    } catch (e) {
      print("Error de conexión: $e"); // Para ver en consola si falla
      _mostrarError("SIN CONEXIÓN: Verifica que el servidor (PC) esté activo");
    } finally {
      setState(() => _cargando = false);
    }
  }

  void _mostrarError(String msj) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msj, style: TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.redAccent.withOpacity(0.8),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: Stack(
        children: [
          // 1. Fondo Táctico (Gradiente Radial)
          Container(
            decoration: BoxDecoration(
                gradient: RadialGradient(
              colors: [Color(0xFF1E293B), kDarkBg],
              center: Alignment.center,
              radius: 1.2,
            )),
          ),

          // 2. Patrón de Red (Opcional - Grid sutil)
          Opacity(
            opacity: 0.05,
            child: GridPaper(color: kNeonBlue, interval: 50),
          ),

          // 3. Contenido
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- EMBLEMA CÓRTEX ---
                  CortexEmblem(size: 120, color: kNeonBlue),
                  SizedBox(height: 30),

                  Text("CÓRTEX",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontFamily: 'Roboto', // O la que prefieras
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8)),

                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        border: Border.all(color: kNeonBlue.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text("SISTEMA DE INTELIGENCIA V9",
                        style: TextStyle(
                            color: kNeonBlue,
                            fontSize: 10,
                            letterSpacing: 3,
                            fontWeight: FontWeight.bold)),
                  ),

                  SizedBox(height: 60),

                  // INPUTS DE CRISTAL
                  _glassInput("IDENTIFICADOR", Icons.badge_outlined,
                      _userController, false),
                  SizedBox(height: 20),
                  _glassInput("CLAVE DE ACCESO", Icons.fingerprint,
                      _passController, true),

                  SizedBox(height: 50),

                  if (_cargando)
                    CircularProgressIndicator(color: kNeonBlue)
                  else
                    GestureDetector(
                      onTap: _iniciarSesion,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                            color: kNeonBlue.withOpacity(0.1),
                            border: Border.all(color: kNeonBlue),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                  color: kNeonBlue.withOpacity(0.2),
                                  blurRadius: 20)
                            ]),
                        child: Text(
                          "ESTABLECER ENLACE",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: kNeonBlue,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2),
                        ),
                      ),
                    ),

                  SizedBox(height: 30),
                  Text("SECRETARÍA DE SEGURIDAD PÚBLICA",
                      style: TextStyle(
                          color: Colors.white24,
                          fontSize: 10,
                          letterSpacing: 2))
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassInput(
      String label, IconData icon, TextEditingController ctrl, bool pass) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: TextField(
            controller: ctrl,
            obscureText: pass,
            style: TextStyle(color: Colors.white, letterSpacing: 1),
            decoration: InputDecoration(
                prefixIcon: Icon(icon, color: Colors.white54),
                labelText: label,
                labelStyle: TextStyle(
                    color: Colors.white38, fontSize: 12, letterSpacing: 1),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 20)),
          ),
        ),
      ),
    );
  }
}

// --- WIDGET DEL EMBLEMA ORIGINAL ---
// Crea un escudo con nodos conectados (Red Neuronal)
class CortexEmblem extends StatelessWidget {
  final double size;
  final Color color;
  const CortexEmblem({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Aura
          Container(
            width: size * 0.6,
            height: size * 0.6,
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 10)
            ]),
          ),
          // Icono Base (Escudo)
          Icon(Icons.shield_outlined, size: size, color: color),
          // Red Neuronal Interna
          Icon(Icons.hub, size: size * 0.5, color: Colors.white),
          // Detalles Tech
          Positioned(
              top: 0,
              child: Icon(Icons.arrow_drop_down, color: color, size: 20)),
        ],
      ),
    );
  }
}
