import 'package:aftermidtermcompass/map.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_floating_search_bar_2/material_floating_search_bar_2.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math' as math;

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Sensor subscriptions
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription<Position>? _positionSubscription;

  LatLng? _currentUserLocation;
  LatLng? _selectedBuildingLocation;

  List<double> _accelerometerValues = [0.0, 0.0, 0.0];
  List<double> _magnetometerValues = [0.0, 0.0, 0.0];

  double _deviceAzimuth = 0.0;
  double _targetBearing = 0.0;
  double _pointerRotation = 0.0;

  // Target location (example: San Francisco)
  final double targetLatitude = 30.892657744694873;
  final double targetLongitude = 75.87247505760351;

  double _sheetHeight = 100.0; // Initial height of map sheet
  static const double _minSheetHeight = 80; // Height of handle area
  late double _maxSheetHeight;

  CameraController? cameraController;
  final FloatingSearchBarController _searchBarController = FloatingSearchBarController();

  // Define and initialize _filteredBuildings
  List<Map<String, dynamic>> _filteredBuildings = [];
  TextEditingController _searchController = TextEditingController();




  // Predefined building locations
  final List<Map<String, dynamic>> buildings = [
    {
      "name": "MBA Block",
      "latLng": LatLng(30.859876279893527, 75.86026916242005),
    },
    {
      "name": "IT Department",
      "latLng": LatLng(30.86031970848174, 75.86027307598508),
    },
    {
      "name": "Auditorium",
      "latLng": LatLng(30.859028903300768, 75.8607300986802),
    },
    {
      "name": "Lipton",
      "latLng": LatLng(30.860143010708967, 75.86114359506607),
    },
    {
      "name": "Tuck Shop",
      "latLng": LatLng(30.860512498582125, 75.86078838773383),
    },

  ];

  final List<Map<String, dynamic>> houseBuildings = [
    {
      "name": "Building A",
      "latLng": LatLng(30.8890344848989, 75.8717958207744),
    },
    {
      "name": "Building B",
      "latLng": LatLng(30.889318883371473, 75.86984716898593),
    },
    {
      "name": "Building C",
      "latLng": LatLng(30.890107637235303, 75.87171378647662),
    },

  ];

  @override
  void initState() {
    super.initState();

    _checkLocationPermission();

    // Gyroscope subscription
    _gyroscopeSubscription = gyroscopeEventStream(samplingPeriod: SensorInterval.normalInterval).listen((GyroscopeEvent event) {
      _updateRotationFromGyroscope(event);
    });

    // Accelerometer subscription
    _accelerometerSubscription = accelerometerEventStream(samplingPeriod: SensorInterval.normalInterval).listen((AccelerometerEvent event) {
      _accelerometerValues = [event.x, event.y, event.z];
    });

    // Magnetometer subscription
    _magnetometerSubscription = magnetometerEventStream(samplingPeriod: SensorInterval.normalInterval).listen((MagnetometerEvent event) {
      _magnetometerValues = [event.x, event.y, event.z];
      _updatePointerRotation(); // Use both accelerometer + magnetometer
    });

    _setupCameraController();
    _filteredBuildings = List.from(buildings);
  }

  // Method to filter buildings based on search input
  void _filterBuildings(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredBuildings = List.from(buildings);
      } else {
        _filteredBuildings = buildings
            .where((building) => building['name']
            .toLowerCase()
            .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  // Update rotation from gyroscope (smoother but prone to drift)
  void _updateRotationFromGyroscope(GyroscopeEvent event) {
    setState(() {
      _deviceAzimuth += event.z * (180 / math.pi); // Convert radians to degrees
      if (_deviceAzimuth < 0) _deviceAzimuth += 360;
      if (_deviceAzimuth >= 360) _deviceAzimuth -= 360;
    });
  }

  double _calculateAzimuthFromSensors(double ax, double ay, double az, double mx, double my, double mz) {
    // Normalize accelerometer vector
    double normA = math.sqrt(ax * ax + ay * ay + az * az);
    ax /= normA;
    ay /= normA;
    az /= normA;

    // Normalize magnetometer vector
    double normM = math.sqrt(mx * mx + my * my + mz * mz);
    mx /= normM;
    my /= normM;
    mz /= normM;

    // Calculate rotation matrix elements (simplified for 2D)
    double hx = my * az - mz * ay;
    double hy = mz * ax - mx * az;

    // Compute azimuth in degrees
    double azimuth = math.atan2(hy, hx) * (180 / math.pi);

    // Normalize azimuth to [0, 360] degrees
    if (azimuth < 0) azimuth += 360;

    return azimuth;
  }

  void _updatePointerRotation() {
    double ax = _accelerometerValues[0];
    double ay = _accelerometerValues[1];
    double az = _accelerometerValues[2];

    double mx = _magnetometerValues[0];
    double my = _magnetometerValues[1];
    double mz = _magnetometerValues[2];

    // Calculate device azimuth from sensors
    double azimuth = _calculateAzimuthFromSensors(ax, ay, az, mx, my, mz);



    setState(() {
      // Adjust pointer rotation by combining gyroscope and sensor-calculated azimuth
      _deviceAzimuth = azimuth; // Correct gyroscope drift with sensor azimuth
      _pointerRotation = _targetBearing - _deviceAzimuth;

      // Normalize the rotation
      if (_pointerRotation < 0) _pointerRotation += 360;
    });
  }


  Future<void> _setupCameraController() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      cameraController = CameraController(cameras.first, ResolutionPreset.high);
      await cameraController!.initialize();
      setState(() {});
    }
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 1, // Update when user moves at least 1 meter
        ),
      ).listen((Position position) {
        setState(() {
          _currentUserLocation = LatLng(position.latitude, position.longitude);
        });
      });
    }
  }


  @override
  void dispose() {
    _gyroscopeSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _positionSubscription?.cancel();
    cameraController?.dispose();
    super.dispose();
  }

  Widget buildCameraView() {
    if (cameraController == null || cameraController?.value.isInitialized == false) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Expanded(
        child: Container(
            child: Stack(
                children: [
                  CameraPreview(cameraController!),
                  Center(
                      child: Transform.rotate(
                        angle: _pointerRotation * (math.pi / 180),
                        child: const Icon(
                          Icons.navigation,
                          size: 100,
                          color: Colors.blue,
                        ),
                      )
                  )
                ]
            )
        )
    );
  }

  Widget buildDragHandle() {
    return Container(
      width: double.infinity,
      height: _minSheetHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(height: 10),
          Container(
            width: 50,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Navigation Map',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }


  Widget buildFloatingSearchBar() {
  
    return FloatingSearchBar(
      controller: _searchBarController,
      hint: 'Search for buildings...',
      scrollPadding: const EdgeInsets.only(top: 16, bottom: 56),
      transitionDuration: const Duration(milliseconds: 300),
      transitionCurve: Curves.easeInOut,
      physics: const BouncingScrollPhysics(),
      axisAlignment: 0.0,
      openAxisAlignment: 0.0,
      width: MediaQuery.of(context).size.width * 0.95,
      debounceDelay: const Duration(milliseconds: 300),
      onQueryChanged: (query) {
        setState(() {
          _filteredBuildings = buildings
              .where((building) =>
              building['name'].toLowerCase().contains(query.toLowerCase()))
              .toList();
        });
      },
      transition: CircularFloatingSearchBarTransition(),
      actions: [
        FloatingSearchBarAction.searchToClear(),
      ],
      builder: (context, transition) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Material(
            color: Colors.white,
            elevation: 4,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredBuildings.length,
              itemBuilder: (context, index) {
                final building = _filteredBuildings[index];
                return ListTile(
                  title: Text(building['name']),
                  onTap: () {
                    _searchBarController.close();
                    setState(() {
                      _selectedBuildingLocation=building['latLng'];
                    });
                    
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget buildMapSheet(LatLng userLocation) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            _sheetHeight = (_sheetHeight - details.delta.dy)
                .clamp(_minSheetHeight, _maxSheetHeight);
          });
        },
        child: Container(
          height: _sheetHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              buildDragHandle(),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  child: MapScreen(currentUserLocation: userLocation,selectedBuildingLocation: _selectedBuildingLocation,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Initialize maxSheetHeight in build to ensure we have MediaQuery
    _maxSheetHeight = MediaQuery.of(context).size.height * 0.85; // 85% of screen height

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold( // Makes the body extend behind the AppBar
        appBar: AppBar(
          backgroundColor: Colors.blueAccent,
          elevation: 0,
          title: const Text(
            'Navigation Assistant',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold) ,
          ),
        ),
        body: Stack(
          children: [
            buildCameraView(),
            buildMapSheet(_currentUserLocation!),
            buildFloatingSearchBar()
          ],
        ),
      ),
    );
  }
}