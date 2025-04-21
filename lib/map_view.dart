import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tuple/tuple.dart';
import 'dart:async';
import 'dart:math' as math;

class MapView extends StatefulWidget {
  final String startPoint;
  final String endPoint;
  final VoidCallback onSearch;
  final Function(List<Map<String, dynamic>>)? onBusSpeedsUpdated;

  const MapView({
    super.key,
    required this.startPoint,
    required this.endPoint,
    required this.onSearch,
    this.onBusSpeedsUpdated,
  });

  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;

  // Route options for each path (Sidest Kilo to Piassa, 4 Kilo, Kebena)
  List<List<LatLng>> _routeOptions1 = [];
  List<List<LatLng>> _routeOptions2 = [];
  List<List<LatLng>> _routeOptions3 = [];

  // Congestion levels for each route option
  List<List<String>> _congestionOptions1 = [];
  List<List<String>> _congestionOptions2 = [];
  List<List<String>> _congestionOptions3 = [];

  // Selected route for each path (least congested)
  List<LatLng> _routePoints1 = [];
  List<LatLng> _routePoints2 = [];
  List<LatLng> _routePoints3 = [];

  List<String> _congestionLevels1 = [];
  List<String> _congestionLevels2 = [];
  List<String> _congestionLevels3 = [];

  final int n1 = 2; // Sidest Kilo to Piasa
  final int n2 = 1; // Sidest Kilo to 4 Kilo
  final int n3 = 4; // Sidest Kilo to Kebena

  List<LatLng> _busPositions1 = [];
  List<LatLng> _busPositions2 = [];
  List<LatLng> _busPositions3 = [];
  List<bool> _busDirections1 = [];
  List<bool> _busDirections2 = [];
  List<bool> _busDirections3 = [];
  List<double> _busProgress1 = [];
  List<double> _busProgress2 = [];
  List<double> _busProgress3 = [];
  List<int> _busIndices1 = [];
  List<int> _busIndices2 = [];
  List<int> _busIndices3 = [];
  List<double> _busSpeeds1 = [];
  List<double> _busSpeeds2 = [];
  List<double> _busSpeeds3 = [];

  Timer? _simulationTimer;
  Timer? _trafficUpdateTimer;

  final String _mapboxAccessToken =
      'pk.eyJ1IjoibXVoYTIwMjQiLCJhIjoiY202M21neXNtMWFldjJpc2J4ZWNoc3hkbCJ9.-pNf8Yml7UJNDzTPtFlssA';

  static const LatLng _initialCenter = LatLng(9.040196, 38.761931);
  static const LatLng _artKiloBusStation = LatLng(9.032286, 38.763561);
  static const LatLng _sidestKiloBusStation = LatLng(9.047464, 38.761687);
  static const LatLng _piasaBusStation = LatLng(9.035831, 38.752432);
  static const LatLng _kebenaBusStation = LatLng(9.034743, 38.777151);

  final GlobalKey _trafficTileLayerKey = GlobalKey();

  Color _getCongestionColor(String congestionLevel) {
    switch (congestionLevel.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'moderate':
        return Colors.yellow;
      case 'heavy':
      case 'severe':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Calculate average congestion score for a route
  double _calculateCongestionScore(List<String> congestionLevels) {
    if (congestionLevels.isEmpty) return double.infinity;

    double totalScore = 0;
    for (var level in congestionLevels) {
      switch (level.toLowerCase()) {
        case 'low':
          totalScore += 1;
          break;
        case 'moderate':
          totalScore += 2;
          break;
        case 'heavy':
          totalScore += 3;
          break;
        case 'severe':
          totalScore += 4;
          break;
        default:
          totalScore += 0;
      }
    }
    return totalScore / congestionLevels.length;
  }

  // Select the least congested route from the options
  void _selectLeastCongestedRoute(int routeIndex) {
    List<List<LatLng>> routeOptions;
    List<List<String>> congestionOptions;

    switch (routeIndex) {
      case 0:
        routeOptions = _routeOptions1;
        congestionOptions = _congestionOptions1;
        break;
      case 1:
        routeOptions = _routeOptions2;
        congestionOptions = _congestionOptions2;
        break;
      case 2:
        routeOptions = _routeOptions3;
        congestionOptions = _congestionOptions3;
        break;
      default:
        return;
    }

    if (routeOptions.isEmpty) return;

    int leastCongestedIndex = 0;
    double minScore = double.infinity;

    for (int i = 0; i < routeOptions.length; i++) {
      double score = _calculateCongestionScore(congestionOptions[i]);
      if (score < minScore) {
        minScore = score;
        leastCongestedIndex = i;
      }
    }

    setState(() {
      switch (routeIndex) {
        case 0:
          _routePoints1 = routeOptions[leastCongestedIndex];
          _congestionLevels1 = congestionOptions[leastCongestedIndex];
          // Update bus indices to match new route length
          for (int j = 0; j < _busIndices1.length; j++) {
            _busIndices1[j] = (_busIndices1[j] * (_routePoints1.length / (_routePoints1.length + 1))).round().clamp(0, _routePoints1.length - 2);
          }
          break;
        case 1:
          _routePoints2 = routeOptions[leastCongestedIndex];
          _congestionLevels2 = congestionOptions[leastCongestedIndex];
          for (int j = 0; j < _busIndices2.length; j++) {
            _busIndices2[j] = (_busIndices2[j] * (_routePoints2.length / (_routePoints2.length + 1))).round().clamp(0, _routePoints2.length - 2);
          }
          break;
        case 2:
          _routePoints3 = routeOptions[leastCongestedIndex];
          _congestionLevels3 = congestionOptions[leastCongestedIndex];
          for (int j = 0; j < _busIndices3.length; j++) {
            _busIndices3[j] = (_busIndices3[j] * (_routePoints3.length / (_routePoints3.length + 1))).round().clamp(0, _routePoints3.length - 2);
          }
          break;
      }
    });
  }

  List<Polyline> _createColoredPolylines(List<LatLng> routePoints, List<String> congestionLevels) {
    if (routePoints.isEmpty || routePoints.length < 2) {
      return [];
    }

    if (congestionLevels.isEmpty) {
      return [
        Polyline(
          points: routePoints,
          strokeWidth: 4.0,
          color: Colors.grey,
        ),
      ];
    }

    List<Polyline> polylines = [];
    int pointsPerSegment = (routePoints.length / congestionLevels.length).ceil();

    for (int i = 0; i < congestionLevels.length; i++) {
      int startIndex = i * pointsPerSegment;
      int endIndex = math.min((i + 1) * pointsPerSegment, routePoints.length);
      if (endIndex <= startIndex) continue;

      List<LatLng> segmentPoints = routePoints.sublist(startIndex, endIndex);
      polylines.add(
        Polyline(
          points: segmentPoints,
          strokeWidth: 4.0,
          color: _getCongestionColor(congestionLevels[i]),
        ),
      );
    }

    return polylines;
  }

  void _notifyBusSpeeds() {
    if (widget.onBusSpeedsUpdated != null) {
      List<Map<String, dynamic>> busSpeeds = [
        ..._busSpeeds1.asMap().entries.map(
              (e) => {
            'routeIndex': 0,
            'busIndex': e.key,
            'speed': e.value,
            'routeName': 'Sidest Kilo to Piasa',
            'color': Colors.blue,
          },
        ),
        ..._busSpeeds2.asMap().entries.map(
              (e) => {
            'routeIndex': 1,
            'busIndex': e.key,
            'speed': e.value,
            'routeName': 'Sidest Kilo to 4 Kilo',
            'color': Colors.green,
          },
        ),
        ..._busSpeeds3.asMap().entries.map(
              (e) => {
            'routeIndex': 2,
            'busIndex': e.key,
            'speed': e.value,
            'routeName': 'Sidest Kilo to Kebena',
            'color': Colors.red,
          },
        ),
      ];
      widget.onBusSpeedsUpdated!(busSpeeds);
    }
  }

  Future<void> _fetchRoute(List<Tuple2<LatLng, LatLng>> routePairs, {bool initialFetch = true}) async {
    try {
      for (int i = 0; i < routePairs.length; i++) {
        String profile = 'driving';
        String urlString = 'https://api.mapbox.com/directions/v5/mapbox/$profile/'
            '${routePairs[i].item1.longitude},${routePairs[i].item1.latitude};'
            '${routePairs[i].item2.longitude},${routePairs[i].item2.latitude}'
            '?geometries=geojson&alternatives=true&access_token=$_mapboxAccessToken';
        Uri url = Uri.parse(urlString);
        var response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          debugPrint('Route $i response: $data');

          if (data['routes'] == null || data['routes'].isEmpty) {
            debugPrint('No routes found for route $i');
            continue;
          }

          List<List<LatLng>> routeOptions = [];
          List<List<String>> congestionOptions = [];

          // Process all route options
          for (var routeData in data['routes']) {
            final route = routeData['geometry']['coordinates'] as List<dynamic>;
            final routePoints = route.map((coord) => LatLng(coord[1], coord[0])).toList();

            // Synthetic congestion based on time of day
            List<String> congestionLevels = [];
            if (routePoints.length >= 2) {
              DateTime now = DateTime.now();
              int hour = now.hour;
              String congestionLevel = (hour >= 7 && hour < 9) || (hour >= 17 && hour < 19)
                  ? 'heavy'
                  : (hour >= 9 && hour < 17)
                  ? 'moderate'
                  : 'low';
              congestionLevels = List.filled((routePoints.length / 2).ceil(), congestionLevel);
            }

            routeOptions.add(routePoints);
            congestionOptions.add(congestionLevels);
          }

          setState(() {
            switch (i) {
              case 0:
                _routeOptions1 = routeOptions;
                _congestionOptions1 = congestionOptions;
                _selectLeastCongestedRoute(0);
                if (initialFetch && _routePoints1.length >= 2) {
                  _fitBounds(routePairs[i].item1, routePairs[i].item2, _routePoints1);
                }
                break;
              case 1:
                _routeOptions2 = routeOptions;
                _congestionOptions2 = congestionOptions;
                _selectLeastCongestedRoute(1);
                if (initialFetch && _routePoints2.length >= 2) {
                  _fitBounds(routePairs[i].item1, routePairs[i].item2, _routePoints2);
                }
                break;
              case 2:
                _routeOptions3 = routeOptions;
                _congestionOptions3 = congestionOptions;
                _selectLeastCongestedRoute(2);
                if (initialFetch && _routePoints3.length >= 2) {
                  _fitBounds(routePairs[i].item1, routePairs[i].item2, _routePoints3);
                }
                break;
            }
          });
        } else {
          debugPrint('Failed to fetch route $i: ${response.statusCode} - ${response.body}');
        }
      }

      if (initialFetch) {
        _startBusSimulation();
      }
    } catch (e) {
      debugPrint('Error fetching routes: $e');
    }
  }

  Future<void> _updateTrafficData(List<Tuple2<LatLng, LatLng>> routePairs) async {
    await _fetchRoute(routePairs, initialFetch: false);

    // Re-select the least congested route based on updated data
    _selectLeastCongestedRoute(0);
    _selectLeastCongestedRoute(1);
    _selectLeastCongestedRoute(2);

    // Force rebuild of the traffic tile layer
    setState(() {
      _trafficTileLayerKey.currentState?.setState(() {});
    });
  }

  void _fitBounds(LatLng startPoint, LatLng endPoint, List<LatLng> routePoints) {
    if (routePoints.length < 2) {
      debugPrint('Not enough points to fit bounds');
      return;
    }

    final bounds = LatLngBounds.fromPoints([startPoint, endPoint, ...routePoints]);
    final cameraFit = CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.all(50),
    );
    _mapController.fitCamera(cameraFit);
  }

  void _getCurrentLocation() {
    setState(() {
      _currentLocation = const LatLng(9.040196, 38.761931);
    });
  }

  void _animateToCurrentLocation(double bearing) {
    if (_currentLocation != null) {
      _mapController.moveAndRotate(_currentLocation!, 15.5, bearing);
    }
  }

  void _startBusSimulation() {
    _busPositions1 = List.generate(n1, (_) => _sidestKiloBusStation);
    _busPositions2 = List.generate(n2, (_) => _sidestKiloBusStation);
    _busPositions3 = List.generate(n3, (_) => _sidestKiloBusStation);

    _busDirections1 = List.generate(n1, (_) => true);
    _busDirections2 = List.generate(n2, (_) => true);
    _busDirections3 = List.generate(n3, (_) => true);

    _busProgress1 = List.generate(n1, (index) => index * (1.0 / n1));
    _busProgress2 = List.generate(n2, (index) => index * (1.0 / n2));
    _busProgress3 = List.generate(n3, (index) => index * (1.0 / n3));

    _busIndices1 = List.generate(
      n1,
          (index) => (index * (_routePoints1.length ~/ n1)).clamp(0, _routePoints1.length - 2),
    );
    _busIndices2 = List.generate(
      n2,
          (index) => (index * (_routePoints2.length ~/ n2)).clamp(0, _routePoints2.length - 2),
    );
    _busIndices3 = List.generate(
      n3,
          (index) => (index * (_routePoints3.length ~/ n3)).clamp(0, _routePoints3.length - 2),
    );

    _busSpeeds1 = List.generate(n1, (_) => 0.5);
    _busSpeeds2 = List.generate(n2, (_) => 0.5);
    _busSpeeds3 = List.generate(n3, (_) => 0.5);

    _notifyBusSpeeds();

    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(Duration(milliseconds: 16), (timer) {
      setState(() {
        _updateBusPositions(
          _busPositions1,
          _busIndices1,
          _busDirections1,
          _busProgress1,
          _routePoints1,
          _busSpeeds1,
        );
        _updateBusPositions(
          _busPositions2,
          _busIndices2,
          _busDirections2,
          _busProgress2,
          _routePoints2,
          _busSpeeds2,
        );
        _updateBusPositions(
          _busPositions3,
          _busIndices3,
          _busDirections3,
          _busProgress3,
          _routePoints3,
          _busSpeeds3,
        );
        _notifyBusSpeeds();
      });
    });
  }

  double _calculateAngle(LatLng p1, LatLng p2, LatLng p3) {
    final double v1x = p2.longitude - p1.longitude;
    final double v1y = p2.latitude - p1.latitude;
    final double v2x = p3.longitude - p2.longitude;
    final double v2y = p3.latitude - p2.latitude;

    final double dotProduct = v1x * v2x + v1y * v2y;
    final double mag1 = math.sqrt(v1x * v1x + v1y * v1y);
    final double mag2 = math.sqrt(v2x * v2x + v2y * v2y);

    if (mag1 == 0 || mag2 == 0) return 0.0;

    final double cosTheta = dotProduct / (mag1 * mag2);
    final double angleRad = math.acos(cosTheta.clamp(-1.0, 1.0));
    return angleRad * 180 / math.pi;
  }

  void _updateBusPositions(
      List<LatLng> positions,
      List<int> indices,
      List<bool> directions,
      List<double> progress,
      List<LatLng> routePoints,
      List<double> speeds,
      ) {
    if (routePoints.length < 2) return;

    for (int i = 0; i < positions.length; i++) {
      if (speeds[i] <= 0) continue;

      double baseSpeedFactor = speeds[i] * 0.005;

      double speedFactor = baseSpeedFactor;
      if (indices[i] > 0 && indices[i] < routePoints.length - 2) {
        final prevPoint = routePoints[indices[i] - 1];
        final currentPoint = routePoints[indices[i]];
        final nextPoint = routePoints[indices[i] + 1];
        final angle = _calculateAngle(prevPoint, currentPoint, nextPoint);

        if (angle > 45) {
          speedFactor = baseSpeedFactor * 0.75;
        }
      }

      if (directions[i]) {
        progress[i] += speedFactor;
      } else {
        progress[i] -= speedFactor;
      }

      if (progress[i] >= 1.0) {
        progress[i] = 1.0;
        indices[i]++;
        if (indices[i] >= routePoints.length - 1) {
          directions[i] = false;
          indices[i] = routePoints.length - 2;
          progress[i] = 1.0;
        } else {
          progress[i] = 0.0;
        }
      } else if (progress[i] <= 0.0) {
        progress[i] = 0.0;
        indices[i]--;
        if (indices[i] < 0) {
          directions[i] = true;
          indices[i] = 0;
          progress[i] = 0.0;
        } else {
          progress[i] = 1.0;
        }
      }

      final startPoint = routePoints[indices[i]];
      final endPoint = routePoints[indices[i] + 1];
      positions[i] = LatLng(
        startPoint.latitude + (endPoint.latitude - startPoint.latitude) * progress[i],
        startPoint.longitude + (endPoint.longitude - startPoint.longitude) * progress[i],
      );
    }
  }

  void _setBusSpeed(int routeIndex, int busIndex, double speed) {
    setState(() {
      if (routeIndex == 0 && busIndex < _busSpeeds1.length) {
        _busSpeeds1[busIndex] = speed.clamp(0.0, 1.0);
      } else if (routeIndex == 1 && busIndex < _busSpeeds2.length) {
        _busSpeeds2[busIndex] = speed.clamp(0.0, 1.0);
      } else if (routeIndex == 2 && busIndex < _busSpeeds3.length) {
        _busSpeeds3[busIndex] = speed.clamp(0.0, 1.0);
      }
      _notifyBusSpeeds();
    });
  }

  void _showSpeedDialog(BuildContext context, int routeIndex, int busIndex) {
    double currentSpeed = routeIndex == 0
        ? _busSpeeds1[busIndex]
        : routeIndex == 1
        ? _busSpeeds2[busIndex]
        : _busSpeeds3[busIndex];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Bus ${busIndex + 1} Speed (Route ${routeIndex + 1})'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Speed: ${(currentSpeed * 100).toStringAsFixed(0)}%'),
              Slider(
                value: currentSpeed,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                label: (currentSpeed * 100).toStringAsFixed(0),
                onChanged: (value) {
                  setDialogState(() {
                    currentSpeed = value;
                  });
                  _setBusSpeed(routeIndex, busIndex, value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchRoute([
      Tuple2(_sidestKiloBusStation, _piasaBusStation),
      Tuple2(_sidestKiloBusStation, _artKiloBusStation),
      Tuple2(_sidestKiloBusStation, _kebenaBusStation),
    ], initialFetch: true);

    _trafficUpdateTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _updateTrafficData([
        Tuple2(_sidestKiloBusStation, _piasaBusStation),
        Tuple2(_sidestKiloBusStation, _artKiloBusStation),
        Tuple2(_sidestKiloBusStation, _kebenaBusStation),
      ]);
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _trafficUpdateTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 12.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$_mapboxAccessToken',
                additionalOptions: {'accessToken': _mapboxAccessToken},
              ),
              TileLayer(
                key: _trafficTileLayerKey,
                urlTemplate:
                'https://api.mapbox.com/styles/v1/mapbox/traffic-day-v2/tiles/{z}/{x}/{y}?access_token=$_mapboxAccessToken',
                additionalOptions: {'accessToken': _mapboxAccessToken},
                tileProvider: NetworkTileProvider(),
              ),
              PolylineLayer(
                polylines: [
                  ..._createColoredPolylines(_routePoints1, _congestionLevels1),
                  ..._createColoredPolylines(_routePoints2, _congestionLevels2),
                  ..._createColoredPolylines(_routePoints3, _congestionLevels3),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _artKiloBusStation,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.circle, color: Colors.red),
                  ),
                  Marker(
                    point: _sidestKiloBusStation,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.circle, color: Colors.red),
                  ),
                  Marker(
                    point: _piasaBusStation,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.circle, color: Colors.red),
                  ),
                  Marker(
                    point: _kebenaBusStation,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.circle, color: Colors.red),
                  ),
                  ..._busPositions1.asMap().entries.map(
                        (entry) => Marker(
                      point: entry.value,
                      width: 30,
                      height: 30,
                      child: GestureDetector(
                        onTap: () => _showSpeedDialog(context, 0, entry.key),
                        child: const Icon(
                          Icons.directions_bus,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  ..._busPositions2.asMap().entries.map(
                        (entry) => Marker(
                      point: entry.value,
                      width: 30,
                      height: 30,
                      child: GestureDetector(
                        onTap: () => _showSpeedDialog(context, 1, entry.key),
                        child: const Icon(
                          Icons.directions_bus,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ),
                  ..._busPositions3.asMap().entries.map(
                        (entry) => Marker(
                      point: entry.value,
                      width: 30,
                      height: 30,
                      child: GestureDetector(
                        onTap: () => _showSpeedDialog(context, 2, entry.key),
                        child: const Icon(
                          Icons.directions_bus,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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