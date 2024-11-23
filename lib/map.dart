import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'graphMaker.dart';

class MapScreen extends StatefulWidget {
  final LatLng currentUserLocation;
  final String geoJsonData;
  final Function(List<LatLng> pathCoordinates) onPathSelected;

  const MapScreen({
    super.key,
    required this.currentUserLocation,
    required this.geoJsonData,
    required this.onPathSelected,
  });

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Polyline> polylines = [];
  LatLng? selectedDestination;
  late GraphManager graphManager;

  @override
  void initState() {
    super.initState();
    graphManager = GraphManager();
    graphManager.parseGeoJson(widget.geoJsonData);

    // Load initial polylines from GeoJSON
    polylines = graphManager.nodes.entries.map((entry) {
      final neighbors = graphManager.edges[entry.key]?.keys ?? [];
      return neighbors.map((neighbor) {
        return Polyline(
          points: [
            LatLng(entry.value[1], entry.value[0]),
            LatLng(
              graphManager.nodes[neighbor]![1],
              graphManager.nodes[neighbor]![0],
            ),
          ],
          strokeWidth: 4.0,
          color: Colors.blue,
        );
      });
    }).expand((e) => e).toList();
  }

  void calculateAndShowPath(LatLng destination) {
    try {
      // Find shortest path
      List<int> pathNodeIds = graphManager.findShortestPath(
        widget.currentUserLocation.latitude,
        widget.currentUserLocation.longitude,
        destination.latitude,
        destination.longitude,
      );

      // Convert to LatLng list
      List<LatLng> pathCoordinates = graphManager
          .getPathCoordinates(pathNodeIds)
          .map((coords) => LatLng(coords[1], coords[0]))
          .toList();

      widget.onPathSelected(pathCoordinates); // Send path back to main screen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Map Screen")),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: widget.currentUserLocation,
          initialZoom: 18,
          onTap: (tapPosition, point) {
            setState(() {
              selectedDestination = point;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'dev.fleaflet.flutter.flutter_map.example',
          ),
          PolylineLayer(polylines: polylines),
          MarkerLayer(
            markers: [
              Marker(
                point: widget.currentUserLocation,
                child: Icon(Icons.my_location, color: Colors.blue, size: 30),
              ),
              if (selectedDestination != null)
                Marker(
                  point: selectedDestination!,
                  child: Icon(Icons.location_on, color: Colors.red, size: 30),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: selectedDestination != null
          ? FloatingActionButton(
              onPressed: () => calculateAndShowPath(selectedDestination!),
              child: Icon(Icons.check),
            )
          : null,
    );
  }
}
