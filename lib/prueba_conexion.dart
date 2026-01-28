import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // Para convertir el JSON

class PruebaIncidentesScreen extends StatefulWidget {
  @override
  _PruebaIncidentesScreenState createState() => _PruebaIncidentesScreenState();
}

class _PruebaIncidentesScreenState extends State<PruebaIncidentesScreen> {
  List incidentes = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    obtenerIncidentes();
  }

  // --- AQUÍ OCURRE LA MAGIA ---
  Future<void> obtenerIncidentes() async {
    // 10.0.2.2 es la IP especial para que el emulador vea tu PC
    // Ajusta '/incidentes' a la ruta real de tu API (ej: /api/v1/incidentes)
    final url = Uri.parse('http://10.0.2.2:8000/incidentes');

    try {
      final respuesta = await http.get(url);

      if (respuesta.statusCode == 200) {
        setState(() {
          incidentes = json.decode(respuesta.body);
          cargando = false;
        });
        print("¡Éxito! Datos recibidos: ${incidentes.length}");
      } else {
        print("Error del servidor: ${respuesta.statusCode}");
      }
    } catch (e) {
      print("Error de conexión: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Prueba de Conexión Cortex")),
      body: cargando
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: incidentes.length,
              itemBuilder: (context, index) {
                final item = incidentes[index];
                // Ajusta 'titulo' y 'descripcion' a como se llamen en tu base de datos
                return Card(
                  color: Colors.red[50], // Color de alerta suave
                  margin: EdgeInsets.all(8),
                  child: ListTile(
                    leading: Icon(Icons.warning, color: Colors.red),
                    title: Text(item['titulo'] ?? 'Sin título',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(item['descripcion'] ?? '...'),
                  ),
                );
              },
            ),
    );
  }
}
