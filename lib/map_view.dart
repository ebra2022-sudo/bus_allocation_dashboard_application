import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  LatLng? _startPoint;
  LatLng? _endPoint;
  LatLng? _currentLocation; // Store current device location
  List<LatLng> _routePoints = [];

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  // Your Mapbox access token
  final String _mapboxAccessToken =
      'pk.eyJ1IjoibXVoYTIwMjQiLCJhIjoiY202M21neXNtMWFldjJpc2J4ZWNoc3hkbCJ9.-pNf8Yml7UJNDzTPtFlssA';

  // Initial center point (New York)
  final LatLng _initialCenter = const LatLng(9.040196, 38.761931);

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
        final coordinates = features[0]['geometry']['coordinates'] as List<dynamic>;
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
      final route = data['routes'][0]['geometry']['coordinates'] as List<dynamic>;
      setState(() {
        _routePoints = route.map((coord) => LatLng(coord[1] as double, coord[0] as double)).toList();
      });
      _fitBounds();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch route: ${response.statusCode}')),
      );
    }
  }

  // Fit map bounds to show the route
  void _fitBounds() {
    if (_startPoint != null && _endPoint != null) {
      final bounds = LatLngBounds.fromPoints([_startPoint!, _endPoint!, ..._routePoints]);
      final cameraFit = CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      );
      _mapController.fitCamera(cameraFit);
    }
  }

  // Handle search and route plotting
  void onSearchPressed() async {
    final startQuery = _startController.text.trim();
    final endQuery = _endController.text.trim();

    if (startQuery.isNotEmpty && endQuery.isNotEmpty) {
      final start = await _searchLocation(startQuery);
      final end = await _searchLocation(endQuery);

      if (start != null && end != null) {
        setState(() {
          _startPoint = start;
          _endPoint = end;
          _routePoints.clear();
        });
        await _fetchRoute(start, end);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find one or both locations')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both start and end locations')),
      );
    }
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
                  flags: InteractiveFlag.all, // Enable all interactions for desktop
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$_mapboxAccessToken',
                  additionalOptions: {
                    'accessToken': _mapboxAccessToken,
                  },
                ),
                MarkerLayer(
                  markers: [
                    if (_startPoint != null)
                      Marker(
                        point: _startPoint!,
                        child: const Icon(Icons.location_pin, color: Colors.blue, size: 40),
                      ),
                    if (_endPoint != null)
                      Marker(
                        point: _endPoint!,
                        child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                      ),
                    if (_currentLocation != null)
                      Marker(
                        point: _currentLocation!,
                        child: const Icon(Icons.location_pin, color: Colors.green, size: 40),
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
        icon:  const Icon(Icons.my_location, color: Colors.green),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }
}