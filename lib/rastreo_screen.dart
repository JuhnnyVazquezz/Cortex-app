import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class RastreoScreen extends StatefulWidget {
  const RastreoScreen({super.key});

  @override
  State<RastreoScreen> createState() => _RastreoScreenState();
}

// Usamos TickerProviderStateMixin para las animaciones
class _RastreoScreenState extends State<RastreoScreen>
    with TickerProviderStateMixin {
  // ESTADOS DEL SISTEMA
  int _estado = 0; // 0: OFF, 1: BUSCANDO, 2: TRANSMITIENDO, 3: ERROR
  String _statusMsg = "SISTEMA EN ESPERA";

  StreamSubscription<Position>? _locationSubscription;
  late AnimationController _rippleController;

  // CONFIGURACIÓN
  final String _oficialId = "OFICIAL_MOVIL_01";

// IP exacta del Hotspot
  final String _serverUrl = "http://192.168.248.28:8000/api/v1/ubicacion/";
  @override
  void initState() {
    super.initState();
    _verificarPermisos();

    // Configuración de la animación del Radar
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _verificarPermisos() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  void _toggleRastreo() {
    // 1. CAMBIO INSTANTÁNEO DE ESTADO (Feedback visual inmediato)
    if (_estado == 0 || _estado == 3) {
      // ENCENDER
      setState(() {
        _estado = 1; // Pasamos a "Buscando"
        _statusMsg = "🛰️ INICIANDO ENLACE SATELITAL...";
      });
      _rippleController.repeat(); // Iniciar animación
      _iniciarTransmision();
    } else {
      // APAGAR
      _detenerTransmision();
    }
  }

  Future<void> _iniciarTransmision() async {
    try {
      // Intento rápido de caché
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null && _estado == 1) {
        _enviarUbicacion(lastPosition, '10-8');
      }
    } catch (e) {
      print(e);
    }

    // Flujo constante
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );

    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position datos) {
      // Si recibimos datos, pasamos a estado ACTIVO (Verde/Cian)
      if (mounted && _estado != 2) {
        setState(() {
          _estado = 2;
          _statusMsg = "✅ ENLACE ESTABLECIDO";
        });
      }

      // Actualizar texto técnico
      if (mounted) {
        setState(() => _statusMsg =
            "LAT: ${datos.latitude.toStringAsFixed(5)}\nLON: ${datos.longitude.toStringAsFixed(5)}");
      }

      _enviarUbicacion(datos, '10-8');
    }, onError: (e) {
      setState(() {
        _estado = 3;
        _statusMsg = "⚠️ PÉRDIDA DE SEÑAL GPS";
      });
      _rippleController.stop();
    });
  }

  void _detenerTransmision() {
    _locationSubscription?.cancel();
    _rippleController.stop(); // Detener animación
    _rippleController.reset();
    setState(() {
      _estado = 0;
      _statusMsg = "🛑 SISTEMA DESCONECTADO";
    });
  }

  Future<void> _enviarUbicacion(Position datos, String codigo) async {
    try {
      final response = await http.post(Uri.parse(_serverUrl), body: {
        'lat': datos.latitude.toString(),
        'lon': datos.longitude.toString(),
        'oficial_id': _oficialId,
        'codigo': codigo
      }).timeout(const Duration(seconds: 2));

      if (response.statusCode != 200) {
        if (mounted)
          setState(
              () => _statusMsg = "⚠️ ERROR SERVER: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted && _estado != 0) {
        // No cambiamos el estado global, solo avisamos del fallo de red
        setState(() => _statusMsg = "📡 GPS OK - ❌ RED FALLANDO ($e)");
      }
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _rippleController.dispose();
    super.dispose();
  }

  // --- UI HELPERS ---
  Color _getColor() {
    switch (_estado) {
      case 1:
        return Colors.orange; // Buscando
      case 2:
        return const Color(0xFF00F0FF); // Activo (Cian)
      case 3:
        return Colors.red; // Error
      default:
        return Colors.grey; // Off
    }
  }

  IconData _getIcon() {
    switch (_estado) {
      case 1:
        return Icons.wifi_tethering; // Icono de búsqueda
      case 2:
        return Icons.radar; // Icono de radar activo
      case 3:
        return Icons.report_problem; // Error
      default:
        return Icons.power_settings_new; // Power
    }
  }

  @override
  Widget build(BuildContext context) {
    Color mainColor = _getColor();

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. JAULA DE TAMAÑO FIJO (Para evitar que el texto salte)
            SizedBox(
              width: 300, // Ancho fijo
              height: 300, // Alto fijo (La animación ocurre aquí adentro)
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Capa 1: Onda Expansiva
                  if (_estado == 1 || _estado == 2)
                    AnimatedBuilder(
                      animation: _rippleController,
                      builder: (context, child) {
                        return Container(
                          // La onda crece hasta 300, pero no empuja nada afuera del SizedBox
                          width: 180 + (_rippleController.value * 120),
                          height: 180 + (_rippleController.value * 120),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: mainColor
                                      .withOpacity(1 - _rippleController.value),
                                  width: 2)),
                        );
                      },
                    ),

                  // Capa 2: Botón Sólido (Siempre mide lo mismo)
                  GestureDetector(
                    onTap: _toggleRastreo,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: mainColor.withOpacity(0.1),
                          border: Border.all(color: mainColor, width: 3),
                          boxShadow: [
                            BoxShadow(
                                color: mainColor.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 2)
                          ]),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_getIcon(), size: 60, color: mainColor),
                          const SizedBox(height: 10),
                          Text(
                              _estado == 0
                                  ? "START"
                                  : (_estado == 3 ? "RETRY" : "STOP"),
                              style: TextStyle(
                                  color: mainColor,
                                  fontWeight: FontWeight.bold))
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // El espacio aquí ya no variará porque el SizedBox de arriba es fijo
            const SizedBox(height: 20),

            // PANEL DE ESTADO
            Container(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
              decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: mainColor.withOpacity(0.3))),
              child: Column(
                children: [
                  Text(
                    _estado == 0
                        ? "OFFLINE"
                        : (_estado == 2 ? "ONLINE" : "ESTABLECIENDO..."),
                    style: TextStyle(
                        color: mainColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3),
                  ),
                  const Divider(color: Colors.white12),
                  Text(
                    _statusMsg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'Courier',
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
