import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {

  LatLng? currentUserLocation;
  LatLng? selectedBuildingLocation;

  MapScreen({super.key, required this.currentUserLocation ,  this.selectedBuildingLocation});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {


  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: map(widget.currentUserLocation!)
    );
  }

  Widget map(LatLng userLocation){
     List<LatLng> polylinePoints = [];

    // Add polyline points if both locations are available
    if (widget.currentUserLocation != null && widget.selectedBuildingLocation != null) {
      polylinePoints = [
        widget.currentUserLocation!,
        widget.selectedBuildingLocation!,
      ];
    }
    return FlutterMap(
        options:  MapOptions(
            initialCenter: userLocation,
            initialZoom: 18,
            minZoom: 8,
            maxZoom: 20,
            interactionOptions: InteractionOptions(flags: InteractiveFlag.all)
        ),
  children: [
        openStreetMapLayer,
        PolylineLayer(
          polylines: [
            Polyline(
              points: polylinePoints,
              color: Colors.blue,
              strokeWidth: 4.0,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: userLocation,
              child: Icon(
                Icons.location_on,
                color: Colors.red,
                size: 40,
              ),
            ),
            if (widget.selectedBuildingLocation != null)
              Marker(
                point: widget.selectedBuildingLocation!,
                child: Icon(
                  Icons.location_city,
                  color: Colors.red,
                  size: 50,
                ),
              ),
          ],
        ),
      ],
    );
  }

  TileLayer get openStreetMapLayer => TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'dev.fleaflet.flutter.flutter_map.example',
  );

}