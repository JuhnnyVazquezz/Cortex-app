import 'dart:convert';
import 'dart:io';
import 'dart:ui'; // Necesario para efectos visuales (Blur)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:http/http.dart' as http;

class VisionScreen extends StatefulWidget {
  @override
  _VisionScreenState createState() => _VisionScreenState();
}

class _VisionScreenState extends State<VisionScreen>
    with SingleTickerProviderStateMixin {
  // --- CONTROLADORES DE INTERFAZ ---
  late TabController _tabController;
  final TextEditingController _placaController = TextEditingController();

  // --- VARIABLES DE ESTADO Y LÓGICA ---
  File? _imagen;
  final picker = ImagePicker();
  bool _cargando = false;
  Map<String, dynamic>? _resultado;

  // ⚠️ IP DEL HOTSPOT (CORREGIDA AL ENLACE ACTIVO)
  String baseUrl = "http://192.168.248.28:8000/api/v1";

  // --- PALETA DE COLORES TÁCTICA (CÓRTEX THEME) ---
  final Color kBgDark = Color(0xFF0B1120); // Fondo Ultra Oscuro
  final Color kPanelBg = Color(0xFF1E293B); // Fondo Paneles
  final Color kCyan = Color(0xFF00F0FF); // Acento Principal (Cian)
  final Color kRed = Color(0xFFEF4444); // Alerta Crítica
  final Color kOrange = Color(0xFFF97316); // Alerta Vinculado
  final Color kAmber = Color(0xFFF59E0B); // Precaución
  final Color kGreen = Color(0xFF22C55E); // Seguro/Online

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _placaController.dispose();
    super.dispose();
  }

  // ==================================================================
  // SECCIÓN 1: LÓGICA DEL NEGOCIO (EL CEREBRO)
  // ==================================================================

  // 1. Tomar Foto con Cámara
  Future tomarFoto() async {
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        _recortarImagen(File(pickedFile.path));
      }
    } catch (e) {
      mostrarSnack("Error al acceder a la cámara: $e");
    }
  }

  // 2. Recortar Imagen (Interfaz de Cropper Personalizada)
  Future<void> _recortarImagen(File imageFile) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'ENFOCAR MATRÍCULA',
            toolbarColor: Colors.black,
            toolbarWidgetColor: kCyan,
            activeControlsWidgetColor: kCyan,
            backgroundColor: Colors.black,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: false),
        IOSUiSettings(
          title: 'Ajustar Placa',
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _imagen = File(croppedFile.path);
        _resultado = null; // Limpiamos resultados anteriores
      });
      // Auto-enviar al terminar de recortar
      consultarAPI(modoImagen: true);
    }
  }

  // 3. Validación Manual
  void buscarManual() {
    if (_placaController.text.length < 3) {
      mostrarSnack("⚠️ La placa debe tener al menos 3 caracteres.");
      return;
    }
    // Ocultar teclado
    FocusScope.of(context).unfocus();
    consultarAPI(modoImagen: false);
  }

  // 4. Conexión con el Servidor (CEREBRO V17)
  Future consultarAPI({required bool modoImagen}) async {
    setState(() {
      _cargando = true;
      _resultado = null;
    });

    try {
      http.Response response;

      if (modoImagen) {
        // --- MODO A: LPR (Reconocimiento Óptico) ---
        var uri = Uri.parse("$baseUrl/vision/placa");
        var request = http.MultipartRequest('POST', uri);
        request.files
            .add(await http.MultipartFile.fromPath('archivo', _imagen!.path));
        var streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        // --- MODO B: MANUAL (Enlace Táctico V17) ---
        String placaTexto = _placaController.text.toUpperCase().trim();
        var uri = Uri.parse("$baseUrl/movil/consulta/$placaTexto");
        response = await http.get(uri);
      }

      // Procesar Respuesta
      if (response.statusCode == 200) {
        var data = json.decode(response.body);

        // --- LÓGICA DE RESPUESTA ---
        if (modoImagen == false) {
          if (data['resultado'] == 'ALERTA') {
            // 1. REVISAMOS SI EL BACKEND MANDÓ 'HISTORIAL'
            List listaAlertas = [];

            if (data['historial'] != null &&
                (data['historial'] as List).isNotEmpty) {
              // Si hay historial, lo mapeamos todo
              listaAlertas = (data['historial'] as List).map((h) {
                return {
                  'titulo': h['titulo'],
                  'color': h['color'],
                  'vehiculo': h['vehiculo'],
                  'fecha': h['fecha'],
                  'info_extra': 'REPORTE VINCULADO',
                  'narrativa': h['narrativa']
                };
              }).toList();
            } else {
              // Fallback: Si no hay historial, usamos el dato único 'data'
              listaAlertas.add({
                'titulo': data['data']['delito'],
                'color': data['color'],
                'vehiculo': data['data']['vehiculo'],
                'fecha': data['data']['fecha'],
                'info_extra': 'FOLIO: ${data['data']['folio']}',
                'narrativa': data['data']['narrativa']
              });
            }

            _resultado = {
              'existe_registro': true,
              'placa_detectada': data['data']
                  ['placa'], // Usamos la placa del primer dato
              'alertas': listaAlertas
            };
          } else {
            // Limpio
            _resultado = {
              'existe_registro': false,
              'placa_detectada': _placaController.text.toUpperCase(),
            };
          }
        } else {
          // Si viene de LPR (Modo Imagen), usamos la respuesta directa
          _resultado = data;
        }

        setState(() {}); // Actualizar pantalla
      } else {
        mostrarSnack("Error del Servidor: Código ${response.statusCode}");
      }
    } catch (e) {
      mostrarSnack("FALLO DE ENLACE: Verifica IP en baseUrl.\nError: $e");
    } finally {
      setState(() {
        _cargando = false;
      });
    }
  }

  // 5. Utilidad de Alertas (SnackBar Táctica)
  void mostrarSnack(String msj) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msj,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1)),
      backgroundColor: kRed.withOpacity(0.9),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: EdgeInsets.all(15),
    ));
  }

  // ==================================================================
  // SECCIÓN 2: INTERFAZ GRÁFICA HUD (DISEÑO PROFESIONAL)
  // ==================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark, // Fondo Táctico
      body: SafeArea(
        child: Column(
          children: [
            // A. HEADER SUPERIOR
            _buildTacticalHeader(),

            SizedBox(height: 10),

            // B. PESTAÑAS PERSONALIZADAS
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              height: 50,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12)),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                    color: kCyan.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kCyan.withOpacity(0.3))),
                labelColor: kCyan,
                unselectedLabelColor: Colors.white38,
                labelStyle: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 12),
                tabs: [
                  Tab(text: "LPR ÓPTICO"),
                  Tab(text: "MANUAL"),
                ],
              ),
            ),

            // C. CONTENIDO DE PESTAÑAS
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTabEscaner(), // Vista de Cámara
                  _buildTabManual(), // Vista de Teclado
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Header Superior con Estado Online ---
  Widget _buildTacticalHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.hub, color: kCyan, size: 28),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CÓRTEX",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: 4)),
                  Text("SISTEMA DE INTELIGENCIA",
                      style: TextStyle(
                          color: kCyan, fontSize: 8, letterSpacing: 2))
                ],
              )
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: kGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kGreen.withOpacity(0.5))),
            child: Row(
              children: [
                Icon(Icons.wifi, size: 12, color: kGreen),
                SizedBox(width: 5),
                Text("EN LÍNEA",
                    style: TextStyle(
                        color: kGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.bold))
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- VISTA 1: ESCÁNER DE CÁMARA ---
  Widget _buildTabEscaner() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          // 1. VISOR HUD (Marco de la cámara)
          GestureDetector(
            onTap: tomarFoto,
            child: Container(
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _imagen == null ? Colors.white10 : kCyan,
                      width: 1),
                  boxShadow: _imagen != null
                      ? [
                          BoxShadow(
                              color: kCyan.withOpacity(0.1), blurRadius: 30)
                        ]
                      : []),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Imagen capturada
                  if (_imagen != null)
                    ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Image.file(_imagen!,
                            fit: BoxFit.contain, width: double.infinity))
                  else
                    // Placeholder
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.view_in_ar, size: 60, color: Colors.white12),
                        SizedBox(height: 15),
                        Text("TOCA PARA ACTIVAR CÁMARA",
                            style: TextStyle(
                                color: Colors.white24,
                                letterSpacing: 1.5,
                                fontSize: 12))
                      ],
                    ),

                  // Esquinas Tácticas (Decoración HUD)
                  Positioned(top: 15, left: 15, child: _hudCorner(0)),
                  Positioned(top: 15, right: 15, child: _hudCorner(1)),
                  Positioned(bottom: 15, left: 15, child: _hudCorner(2)),
                  Positioned(bottom: 15, right: 15, child: _hudCorner(3)),

                  // Línea de Escaneo (Solo decorativa si no hay foto)
                  if (_imagen == null)
                    Positioned(
                        child: Container(
                            height: 1,
                            width: 200,
                            decoration: BoxDecoration(boxShadow: [
                              BoxShadow(color: kCyan, blurRadius: 5)
                            ], color: kCyan)))
                ],
              ),
            ),
          ),

          SizedBox(height: 25),

          // 2. BOTONES DE ACCIÓN (Si hay imagen)
          if (_imagen != null && !_cargando)
            Row(
              children: [
                Expanded(
                    child: _btnTactico(
                        icon: Icons.refresh,
                        label: "REINTENTAR",
                        color: Colors.white30,
                        onTap: tomarFoto)),
                SizedBox(width: 15),
                Expanded(
                    child: _btnTactico(
                        icon: Icons.search,
                        label: "ANALIZAR",
                        color: kCyan,
                        onTap: () => consultarAPI(modoImagen: true),
                        glow: true)),
              ],
            ),

          // 3. ESTADO DE CARGA Y RESULTADOS
          if (_cargando) _loadingAnim(),
          if (_resultado != null) _construirTarjetaResultado(),
        ],
      ),
    );
  }

  // --- VISTA 2: ENTRADA MANUAL ---
  Widget _buildTabManual() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 25, vertical: 40),
      child: Column(
        children: [
          Icon(Icons.keyboard, size: 50, color: Colors.white24),
          SizedBox(height: 15),
          Text("BÚSQUEDA POR MATRÍCULA",
              style: TextStyle(
                  color: Colors.white54, letterSpacing: 2, fontSize: 12)),

          SizedBox(height: 30),

          // Input Estilizado
          Container(
            decoration: BoxDecoration(
                color: kPanelBg,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black45,
                      blurRadius: 20,
                      offset: Offset(0, 10))
                ]),
            child: TextField(
              controller: _placaController,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6),
              decoration: InputDecoration(
                  hintText: "AAA000",
                  hintStyle: TextStyle(color: Colors.white10),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 25)),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                LengthLimitingTextInputFormatter(10),
                UpperCaseTextFormatter() // Mayúsculas automáticas
              ],
              onSubmitted: (_) => buscarManual(),
            ),
          ),

          SizedBox(height: 40),

          _btnTactico(
              icon: Icons.travel_explore,
              label: "CONSULTAR BASE DE DATOS",
              color: kCyan,
              onTap: _cargando ? () {} : buscarManual,
              glow: true),

          if (_cargando) _loadingAnim(),
          if (_resultado != null) _construirTarjetaResultado(),
        ],
      ),
    );
  }

  // --- TARJETA DE RESULTADOS MEJORADA (MULTI-EVENTO) ---
  Widget _construirTarjetaResultado() {
    // 1. Manejo de Errores del Backend
    if (_resultado!.containsKey('error')) {
      return _alertCard(kRed, "ERROR DE SISTEMA", _resultado!['error']);
    }

    String placa = _resultado!['placa_detectada'] ?? "---";
    // Nota: A veces la IA puede no detectar nada
    if (placa == "NO DETECTADA") {
      return _alertCard(kAmber, "LECTURA FALLIDA",
          "No se detectaron caracteres legibles. Intente acercarse más.");
    }

    bool encontrado = _resultado!['existe_registro'] == true;

    // --- CASO 1: NEGATIVO (Placa Limpia) ---
    if (!encontrado) {
      return Container(
        margin: EdgeInsets.only(top: 30),
        child: Column(
          children: [
            _placaHeader(placa, kGreen), // Placa en Verde
            _alertCard(kGreen, "SIN NOVEDAD",
                "El vehículo no cuenta con reportes activos en plataforma Córtex.")
          ],
        ),
      );
    }

    // --- CASO 2: POSITIVO (Hay Alertas) ---
    // Extraemos la lista de alertas.
    List alertas = _resultado!['alertas'] ?? [];

    return Container(
      margin: EdgeInsets.only(top: 30),
      child: Column(
        children: [
          // 1. PLACA EN ROJO
          _placaHeader(placa, kRed),

          SizedBox(height: 15),

          // 2. CONTADOR DE ALERTAS
          Text("⚠️ ${alertas.length} EVENTOS ENCONTRADOS",
              style: TextStyle(
                  color: kRed, fontWeight: FontWeight.bold, letterSpacing: 2)),

          SizedBox(height: 15),

          // 3. LISTA DE TARJETAS (Generada dinámicamente)
          // Esto genera una tarjeta por cada elemento en el historial
          ...alertas.map((alerta) {
            // Definir color del tema según la severidad
            Color colorTema;
            String c = alerta['color'] ?? 'NARANJA';
            if (c == 'ROJO')
              colorTema = kRed;
            else if (c == 'NARANJA')
              colorTema = kOrange;
            else
              colorTema = kAmber;

            return Container(
              margin: EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [colorTema.withOpacity(0.15), Colors.transparent],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight),
                border: Border(left: BorderSide(color: colorTema, width: 4)),
                color: kPanelBg,
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                collapsedIconColor: Colors.white54,
                iconColor: colorTema,
                title: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: colorTema),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(alerta['titulo'] ?? "ALERTA",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ],
                ),
                subtitle: Text(alerta['fecha'] ?? "",
                    style: TextStyle(color: Colors.white38, fontSize: 10)),
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(15, 0, 15, 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: Colors.white10),
                        _rowDetalle("VEHÍCULO:", alerta['vehiculo'] ?? "S/D"),
                        if (alerta['info_extra'] != null)
                          _rowDetalle("DETALLE:", alerta['info_extra']),
                        SizedBox(height: 10),
                        Text("NARRATIVA:",
                            style: TextStyle(
                                color: kCyan,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text(alerta['narrativa'] ?? "Sin datos",
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4)),
                      ],
                    ),
                  )
                ],
              ),
            );
          }).toList()
        ],
      ),
    );
  }

  // --- WIDGET CABECERA DE PLACA ---
  Widget _placaHeader(String placa, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
      decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 20)
          ]),
      child: Text(
        placa,
        style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: 5),
      ),
    );
  }

  // ==================================================================
  // SECCIÓN 3: WIDGETS REUTILIZABLES (ESTILOS)
  // ==================================================================

  // Fila de datos (Clave - Valor)
  Widget _rowDetalle(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          Expanded(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14))),
        ],
      ),
    );
  }

  // Botón Táctico Hexagonal/Bordeado
  Widget _btnTactico(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap,
      bool glow = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 55,
        decoration: BoxDecoration(
            color: glow ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 1.5),
            boxShadow: glow
                ? [
                    BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 1)
                  ]
                : []),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 1))
          ],
        ),
      ),
    );
  }

  // Animación de carga
  Widget _loadingAnim() {
    return Padding(
      padding: EdgeInsets.only(top: 30),
      child: Column(
        children: [
          CircularProgressIndicator(color: kCyan, strokeWidth: 3),
          SizedBox(height: 15),
          Text("ANALIZANDO DATOS BIOMÉTRICOS...",
              style: TextStyle(color: kCyan, letterSpacing: 2, fontSize: 10))
        ],
      ),
    );
  }

  // Tarjeta de Error Simple
  Widget _alertCard(Color color, String title, String msg) {
    return Container(
      margin: EdgeInsets.only(top: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color)),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: color, size: 40),
          SizedBox(height: 10),
          Text(title,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 5),
          Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: color.withOpacity(0.8))),
        ],
      ),
    );
  }

  // Decoración de Esquinas HUD
  Widget _hudCorner(int pos) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
          border: Border(
        top: (pos < 2) ? BorderSide(color: kCyan, width: 3) : BorderSide.none,
        bottom:
            (pos > 1) ? BorderSide(color: kCyan, width: 3) : BorderSide.none,
        left: (pos % 2 == 0)
            ? BorderSide(color: kCyan, width: 3)
            : BorderSide.none,
        right: (pos % 2 != 0)
            ? BorderSide(color: kCyan, width: 3)
            : BorderSide.none,
      )),
    );
  }
}

// Formateador para mayúsculas automáticas
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
        text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}
