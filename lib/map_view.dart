import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

//9.032286, 38.763561 // 4 kilo

// 9.034743, 38.777151 // kebena

//9.047464, 38.761687 // 6 kilo

// 9.035831, 38.752432 // piasa

class MapView extends StatefulWidget {
  final String startPoint;
  final String endPoint;
  final VoidCallback onSearch; // Function passed from parent to trigger search

  const MapView({
    super.key,
    required this.startPoint,
    required this.endPoint,
    required this.onSearch,
  });

  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  LatLng? _startPoint;
  LatLng? _endPoint;
  LatLng? _currentLocation; // Store current device location
  List<LatLng> _routePoints = [];

  // Your Mapbox access token
  final String _mapboxAccessToken =
      'pk.eyJ1IjoibXVoYTIwMjQiLCJhIjoiY202M21neXNtMWFldjJpc2J4ZWNoc3hkbCJ9.-pNf8Yml7UJNDzTPtFlssA';

  // Initial center point (New York)
  final LatLng _initialCenter = const LatLng(9.040196, 38.761931);
  final _artKiloBusStation = const LatLng(9.032286, 38.763561);
  final _sidestKiloBusStation = const LatLng(9.047464, 38.761687);
  final _piasaBusStation = const LatLng(9.035831, 38.752432);
  final _kebenaBusStation = const LatLng(9.034743, 38.777151);

  // Search for a location using Mapbox Geocoding API
  Future<LatLng?> _searchLocation(String query) async {
    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json?access_token=$_mapboxAccessToken&limit=1',
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final features = data['features'] as List<dynamic>;
      if (features.isNotEmpty) {
        final coordinates =
            features[0]['geometry']['coordinates'] as List<dynamic>;
        return LatLng(coordinates[1] as double, coordinates[0] as double);
      }
    }
    return null;
  }

  // Fetch route between start and end points using Mapbox Directions API
  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&access_token=$_mapboxAccessToken',
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final route =
          data['routes'][0]['geometry']['coordinates'] as List<dynamic>;
      setState(() {
        _routePoints =
            route
                .map((coord) => LatLng(coord[1] as double, coord[0] as double))
                .toList();
      });
      _fitBounds();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fetch route: ${response.statusCode}'),
        ),
      );
    }
  }

  // Fit map bounds to show the route
  void _fitBounds() {
    if (_startPoint != null && _endPoint != null) {
      final bounds = LatLngBounds.fromPoints([
        _startPoint!,
        _endPoint!,
        ..._routePoints,
      ]);
      final cameraFit = CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      );
      _mapController.fitCamera(cameraFit);
    }
  }

  // Handle search and route plotting
  void _onSearchPressed(LatLng start, LatLng end) async {
    setState(() {
      _startPoint = start;
      _endPoint = end;
      _routePoints.clear();
    });
    await _fetchRoute(start, end);
  }

  // Get current device location
  void _getCurrentLocation() {
    setState(() {
      _currentLocation = LatLng(9.040196, 38.761931);
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getCurrentLocation();
    _onSearchPressed(_sidestKiloBusStation, _artKiloBusStation);
    _onSearchPressed(_sidestKiloBusStation, _piasaBusStation);
    _onSearchPressed(_sidestKiloBusStation, _kebenaBusStation);
  }

  // Animate map to current location with bearing
  void _animateToCurrentLocation(double bearing) {
    if (_currentLocation != null) {
      _mapController.moveAndRotate(
        _currentLocation!,
        15.5, // Zoom level
        bearing, // Device heading (bearing)
        // 3-second animation
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Map view
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: 10.0,
                initialRotation: 0.0, // Initial bearing
                interactionOptions: const InteractionOptions(
                  flags:
                      InteractiveFlag
                          .all, // Enable all interactions for desktop
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$_mapboxAccessToken',
                  additionalOptions: {'accessToken': _mapboxAccessToken},
                ),
                MarkerLayer(
                  markers: [
                    // piasa bus station marker
                    Marker(
                      point: _piasaBusStation,
                      child: const Icon(
                        Icons.directions_bus_sharp,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),

                    // sidest kilo bus station marker
                    Marker(
                      point: _sidestKiloBusStation,
                      child: const Icon(
                        Icons.directions_bus_sharp,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),

                    // 4 kilo bus station marker
                    Marker(
                      point: _artKiloBusStation,
                      child: const Icon(
                        Icons.directions_bus_sharp,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),

                    // kebena bus station marker

                    Marker(
                      point: _kebenaBusStation,
                      child: const Icon(
                        Icons.directions_bus_sharp,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
                PolylineLayer(
                  polylines: [
                    if (_routePoints.isNotEmpty)
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4.0,
                        color: Colors.green,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: IconButton(
        onPressed: () => _animateToCurrentLocation(0.0),
        icon: const Icon(Icons.my_location, color: Colors.green),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
