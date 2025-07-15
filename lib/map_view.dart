import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';

// --- Bus and RouteData Classes ---
class RouteData {
  final List<List<LatLng>> routeOptions;
  final List<List<String>> congestionOptions;
  final List<double> durations;
  final List<double> distances;

  RouteData({
    required this.routeOptions,
    required this.congestionOptions,
    required this.durations,
    required this.distances,
  });
}

class Bus {
  final String id;
  final String busName;
  LatLng position;
  List<LatLng> routePoints;
  List<String> congestionLevels;
  double progress; // 0.0 to 1.0 along the current segment
  int currentSegmentIndex; // Index of the current segment of routePoints
  double speed; // Current effective speed based on multiplier and congestion
  LatLng currentStartStation;
  LatLng currentEndStation;
  final Color color;
  double baseSpeedMultiplier; // User-controlled speed multiplier
  bool isWaitingAtStation;
  DateTime? arrivalTimeAtStation;
  // New fields for backend reporting
  double totalRouteDistanceKm; // Total distance of current route in Km
  double totalRouteDurationMinutes; // Total duration of current route in Minutes (from Mapbox)

  Bus({
    required this.id,
    required this.busName,
    required this.position,
    this.routePoints = const [],
    this.congestionLevels = const [],
    this.progress = 0.0,
    this.currentSegmentIndex = 0,
    this.speed = 0.0,
    required this.currentStartStation,
    required this.currentEndStation,
    required this.color,
    this.baseSpeedMultiplier = 1.0,
    this.isWaitingAtStation = false,
    this.arrivalTimeAtStation,
    this.totalRouteDistanceKm = 0.0, // Initialize new fields
    this.totalRouteDurationMinutes = 0.0, // Initialize new fields
  });

  Bus copyWith({
    LatLng? position,
    List<LatLng>? routePoints,
    List<String>? congestionLevels,
    double? progress,
    int? currentSegmentIndex,
    double? speed,
    LatLng? currentStartStation,
    LatLng? currentEndStation,
    double? baseSpeedMultiplier,
    bool? isWaitingAtStation,
    DateTime? arrivalTimeAtStation,
    String? busName,
    double? totalRouteDistanceKm, // Add to copyWith
    double? totalRouteDurationMinutes, // Add to copyWith
  }) {
    return Bus(
      id: id,
      busName: busName ?? this.busName,
      position: position ?? this.position,
      routePoints: routePoints ?? List.from(this.routePoints),
      congestionLevels: congestionLevels ?? List.from(this.congestionLevels),
      progress: progress ?? this.progress,
      currentSegmentIndex: currentSegmentIndex ?? this.currentSegmentIndex,
      speed: speed ?? this.speed,
      currentStartStation: currentStartStation ?? this.currentStartStation,
      currentEndStation: currentEndStation ?? this.currentEndStation,
      color: this.color,
      baseSpeedMultiplier: baseSpeedMultiplier ?? this.baseSpeedMultiplier,
      isWaitingAtStation: isWaitingAtStation ?? this.isWaitingAtStation,
      arrivalTimeAtStation: arrivalTimeAtStation ?? this.arrivalTimeAtStation,
      totalRouteDistanceKm: totalRouteDistanceKm ?? this.totalRouteDistanceKm, // Assign new fields
      totalRouteDurationMinutes: totalRouteDurationMinutes ?? this.totalRouteDurationMinutes, // Assign new fields
    );
  }
}

// --- MapView Class ---
class MapView extends StatefulWidget {
  final String startPoint;
  final String endPoint;
  final VoidCallback onSearch;
  final Function(List<Map<String, dynamic>>) onBusSpeedsUpdated;

  const MapView({
    super.key,
    required this.startPoint,
    required this.endPoint,
    required this.onSearch,
    required this.onBusSpeedsUpdated,
  });

  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;

  List<Bus> _buses = [];

  Timer? _simulationTimer;
  Timer? _trafficUpdateTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _hasUserInteractedWithMap = false;

  static const Duration _simulationTickDuration = Duration(milliseconds: 20);
  static const Duration _stationWaitDuration = Duration(seconds: 20);

  final String _mapboxAccessToken = 'pk.eyJ1IjoibXVoYTIwMjQiLCJhIjoiY202M21neXNtMWFldjJpc2J4ZWNoc3hkbCJ9.-pNf8Yml7UJNDzTPtFlssA'; // Your Mapbox token

  static const LatLng _initialMapCenter = LatLng(9.040541, 38.762119); // Addis Ababa
  static const double _initialMapZoom = 15.0;
  static const double _initialMapBearing = 0.0;

  static const List<LatLng> _busStations = [
    LatLng(9.035831, 38.752432), // Piassa
    LatLng(9.034743, 38.777151), // Kebena
    LatLng(9.047464, 38.761687), // Sidist Kilo (6 Kilo)
    LatLng(9.032286, 38.763561), // 4 Kilo
  ];

  final GlobalKey _trafficTileLayerKey = GlobalKey();
  final math.Random _random = math.Random();
  final Distance _distance = const Distance();

  final List<Color> _busColors = [
    Colors.blue.shade700,
    Colors.red.shade700,
    Colors.green.shade700,
    Colors.purple.shade700,
    Colors.orange.shade700,
    Colors.teal.shade700,
    Colors.pink.shade700,
    Colors.brown.shade700,
    Colors.indigo.shade700,
    Colors.cyan.shade700,
    Colors.lime.shade700,
    Colors.amber.shade700,
    Colors.deepOrange.shade700,
    Colors.lightBlue.shade700,
    Colors.deepPurple.shade700,
  ];

  void _resetMapToInitialView() {
    _mapController.move(_initialMapCenter, _initialMapZoom);
    _mapController.rotate(_initialMapBearing);
    setState(() {
      _hasUserInteractedWithMap = false;
    });
  }

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

  List<Polyline> _createColoredPolylinesForBus(Bus bus) {
    if (bus.routePoints.isEmpty || bus.routePoints.length < 2) return [];

    List<Polyline> polylines = [];
    if (bus.congestionLevels.isEmpty) {
      polylines.add(Polyline(points: bus.routePoints, strokeWidth: 4.0, color: Colors.grey));
      return polylines;
    }

    double pointsPerCongestionSegment = bus.routePoints.length / bus.congestionLevels.length;

    for (int i = 0; i < bus.congestionLevels.length; i++) {
      int startIndex = (i * pointsPerCongestionSegment).floor();
      int endIndex = ((i + 1) * pointsPerCongestionSegment).floor();

      endIndex = math.min(endIndex, bus.routePoints.length - 1);
      if (i == bus.congestionLevels.length - 1) {
        endIndex = bus.routePoints.length - 1;
      }

      if (startIndex >= endIndex) {
        endIndex = math.min(startIndex + 1, bus.routePoints.length - 1);
        if (startIndex >= endIndex) continue;
      }

      List<LatLng> segmentPoints = bus.routePoints.sublist(startIndex, endIndex + 1);

      if (segmentPoints.length > 1) {
        polylines.add(Polyline(
          points: segmentPoints,
          strokeWidth: 4.0,
          color: _getCongestionColor(bus.congestionLevels[i]),
        ));
      }
    }
    return polylines;
  }

  String _getStationName(LatLng station) {
    if (station == const LatLng(9.035831, 38.752432)) return 'Piassa';
    if (station == const LatLng(9.034743, 38.777151)) return 'Kebena';
    if (station == const LatLng(9.047464, 38.761687)) return '6 Kilo';
    if (station == const LatLng(9.032286, 38.763561)) return '4 Kilo';
    return 'Lat: ${station.latitude.toStringAsFixed(4)}, Lon: ${station.longitude.toStringAsFixed(4)}';
  }

  Future<RouteData?> fetchRoute(LatLng start, LatLng end) async {
    try {
      const profile = 'driving-traffic';
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/$profile/'
            '${start.longitude},${start.latitude};'
            '${end.longitude},${end.latitude}'
            '?geometries=geojson&alternatives=true&overview=full&annotations=congestion&access_token=$_mapboxAccessToken',
      );
      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint('ERROR: Failed to fetch route for ${_getStationName(start)} to ${_getStationName(end)}: ${response.statusCode} - ${response.body}');
        return null;
      }

      final data = json.decode(response.body);
      if (data['routes'] == null || data['routes'].isEmpty) {
        debugPrint('WARNING: No routes found for the given pair: ${_getStationName(start)} to ${_getStationName(end)}.');
        return null;
      }

      final List<List<LatLng>> routeOptions = [];
      final List<List<String>> congestionOptions = [];
      final List<double> durations = [];
      final List<double> distances = [];

      for (var routeDataEntry in data['routes']) {
        final route = routeDataEntry['geometry']['coordinates'] as List<dynamic>;
        final routePoints = route.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();

        List<String> congestionLevels = [];
        if (routeDataEntry['legs'] != null && routeDataEntry['legs'].isNotEmpty) {
          for (var leg in routeDataEntry['legs']) {
            if (leg['annotation'] != null && leg['annotation']['congestion'] != null) {
              congestionLevels.addAll(List<String>.from(leg['annotation']['congestion']));
            } else if (leg['steps'] != null) {
              for (var step in leg['steps']) {
                if (step['annotation'] != null && step['annotation']['congestion'] != null) {
                  congestionLevels.addAll(List<String>.from(step['annotation']['congestion']));
                }
              }
            }
          }
        }

        if (congestionLevels.isEmpty) {
          debugPrint('WARNING: No granular congestion data from Mapbox for route. Using time-based heuristic fallback.');
          DateTime now = DateTime.now();
          int hour = now.hour;
          String fallbackLevel = 'low';
          if ((hour >= 7 && hour < 9) || (hour >= 17 && hour < 19)) {
            fallbackLevel = 'heavy';
          } else if (hour >= 9 && hour < 17) {
            fallbackLevel = 'moderate';
          }
          congestionLevels = List.filled(routePoints.length, fallbackLevel);
        }

        routeOptions.add(routePoints);
        congestionOptions.add(congestionLevels);
        durations.add((routeDataEntry['duration'] ?? 0).toDouble() / 60);
        distances.add((routeDataEntry['distance'] ?? 0).toDouble() / 1000);
      }
      return RouteData(routeOptions: routeOptions, congestionOptions: congestionOptions, durations: durations, distances: distances);
    } catch (e) {
      debugPrint('CRITICAL ERROR: Exception occurred while fetching route for ${_getStationName(start)} to ${_getStationName(end)}: $e');
      return null;
    }
  }

  void _assignLeastCongestedRoute(Bus bus, RouteData routeData) {
    if (routeData.routeOptions.isEmpty) {
      bus.routePoints = [];
      bus.congestionLevels = [];
      debugPrint('WARNING: No route options available to assign for Bus ${bus.id}.');
      return;
    }
    int leastCongestedIndex = 0;
    double minScore = double.infinity;

    for (int i = 0; i < routeData.routeOptions.length; i++) {
      double score = _calculateCongestionScore(routeData.congestionOptions[i]);
      if (score < minScore) {
        minScore = score;
        leastCongestedIndex = i;
      }
    }
    bus.routePoints = routeData.routeOptions[leastCongestedIndex];
    bus.congestionLevels = routeData.congestionOptions[leastCongestedIndex];
    // Update bus with the total distance and duration for the assigned route
    bus.totalRouteDistanceKm = routeData.distances[leastCongestedIndex];
    bus.totalRouteDurationMinutes = routeData.durations[leastCongestedIndex];
    bus.currentSegmentIndex = 0;
    bus.progress = 0.0;
    debugPrint('Bus ${bus.id}: Assigned least congested route (score: ${minScore.toStringAsFixed(2)}) with ${bus.routePoints.length} points. Distance: ${bus.totalRouteDistanceKm.toStringAsFixed(2)} km, Duration: ${bus.totalRouteDurationMinutes.toStringAsFixed(1)} min.');
  }

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

  Future<void> _fetchRouteDataForBus(Bus bus) async {
    debugPrint('Bus ${bus.id}: Attempting to fetch route from ${_getStationName(bus.currentStartStation)} to ${_getStationName(bus.currentEndStation)}');
    RouteData? routeData = await fetchRoute(bus.currentStartStation, bus.currentEndStation);

    final int busIndex = _buses.indexWhere((b) => b.id == bus.id);
    if (busIndex == -1) {
      debugPrint('WARNING: Bus ${bus.id} not found in _buses list during route fetch. It might have been removed.');
      return;
    }
    Bus currentBusInList = _buses[busIndex];

    setState(() {
      if (routeData != null && routeData.routeOptions.isNotEmpty) {
        // Assign route and update bus object directly with distance and duration
        _assignLeastCongestedRoute(currentBusInList, routeData);

        if (currentBusInList.routePoints.isNotEmpty) {
          if (currentBusInList.isWaitingAtStation || currentBusInList.position == const LatLng(0,0)) {
            currentBusInList.position = currentBusInList.routePoints.first;
          }
          currentBusInList = currentBusInList.copyWith(
            isWaitingAtStation: false,
            arrivalTimeAtStation: null,
            speed: _calculateEffectiveBusSpeed(currentBusInList),
            // totalRouteDistanceKm and totalRouteDurationMinutes are already updated by _assignLeastCongestedRoute
          );
          debugPrint('Bus ${currentBusInList.id} successfully fetched route (${_getStationName(currentBusInList.currentStartStation)} to ${_getStationName(currentBusInList.currentEndStation)}). Route points: ${currentBusInList.routePoints.length}. Ready to move.');

          // --- Send Departure Report ---
          _sendBusStatusToBackend(currentBusInList, 'departure');

        } else {
          debugPrint("Bus ${currentBusInList.id}: Failed to find valid route points from Mapbox. Setting to waiting and retrying route fetch.");
          currentBusInList = currentBusInList.copyWith(isWaitingAtStation: true, arrivalTimeAtStation: DateTime.now(), speed: 0.0);
          Future.delayed(const Duration(seconds: 5), () => _fetchRouteDataForBus(currentBusInList));
        }
      } else {
        debugPrint("Bus ${currentBusInList.id}: Failed to fetch any route data from Mapbox (routeData null/empty). Setting to waiting and retrying route fetch.");
        currentBusInList = currentBusInList.copyWith(isWaitingAtStation: true, arrivalTimeAtStation: DateTime.now(), speed: 0.0);
        Future.delayed(const Duration(seconds: 5), () => _fetchRouteDataForBus(currentBusInList));
      }
      _buses[busIndex] = currentBusInList;
    });
  }

  void _fitBounds(List<Bus> buses) {
    List<LatLng> allPoints = [];

    allPoints.addAll(_busStations);

    for (var bus in buses) {
      if (bus.position.latitude != 0.0 || bus.position.longitude != 0.0) {
        allPoints.add(bus.position);
      }
      if (bus.routePoints.isNotEmpty) {
        allPoints.addAll(bus.routePoints.where((point) => point.latitude != 0.0 || point.longitude != 0.0));
      }
    }

    if (allPoints.isEmpty) {
      _mapController.move(_initialMapCenter, _initialMapZoom);
      debugPrint("Warning: No valid points found to fit bounds. Centering on initial map location.");
      return;
    }

    if (allPoints.length == 1) {
      _mapController.move(allPoints.first, _initialMapZoom);
      return;
    }

    try {
      final bounds = LatLngBounds.fromPoints(allPoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50.0),
          maxZoom: 18.0,
        ),
      );
    } catch (e) {
      debugPrint("Error fitting bounds: $e. Using initial map center.");
      _mapController.move(_initialMapCenter, _initialMapZoom);
    }
  }

  void _getCurrentLocation() {
    setState(() => _currentLocation = _initialMapCenter);
  }

  void _dispatchBusToNewRandomRoute(Bus bus) {
    LatLng newStart;
    LatLng newEnd;

    newStart = bus.position;

    List<LatLng> possibleDestinations = List.from(_busStations);
    possibleDestinations.removeWhere((dest) => dest == newStart);

    if (possibleDestinations.isEmpty) {
      newEnd = newStart;
      debugPrint('WARNING: Only one station available. Bus ${bus.id} will try to route to itself.');
    } else {
      newEnd = possibleDestinations[_random.nextInt(possibleDestinations.length)];
    }

    debugPrint('Bus ${bus.id}: Preparing for new route from ${_getStationName(newStart)} to ${_getStationName(newEnd)}');

    final int busIndex = _buses.indexWhere((b) => b.id == bus.id);
    if (busIndex == -1) {
      debugPrint('ERROR: Bus ${bus.id} not found in _buses list during dispatch. Cannot dispatch.');
      return;
    }

    setState(() {
      _buses[busIndex] = bus.copyWith(
        currentStartStation: newStart,
        currentEndStation: newEnd,
        routePoints: [],
        congestionLevels: [],
        currentSegmentIndex: 0,
        progress: 0.0,
        speed: 0.0,
        isWaitingAtStation: false,
        arrivalTimeAtStation: null,
        totalRouteDistanceKm: 0.0, // Reset for new route
        totalRouteDurationMinutes: 0.0, // Reset for new route
      );
    });
    _fetchRouteDataForBus(_buses[busIndex]);
  }

  double _calculateEffectiveBusSpeed(Bus bus) {
    if (bus.isWaitingAtStation || bus.routePoints.length < 2) {
      return 0.0;
    }

    String currentCongestionLevel = 'low';
    if (bus.congestionLevels.isNotEmpty && bus.currentSegmentIndex < bus.routePoints.length - 1) {
      int congestionLevelIndex = (bus.currentSegmentIndex / (bus.routePoints.length / (bus.congestionLevels.length > 0 ? bus.congestionLevels.length : 1)))
          .floor()
          .clamp(0, bus.congestionLevels.length - 1);
      currentCongestionLevel = bus.congestionLevels[congestionLevelIndex];
    } else if (bus.congestionLevels.isNotEmpty && bus.currentSegmentIndex == bus.routePoints.length - 1) {
      currentCongestionLevel = bus.congestionLevels.last;
    }

    double congestionMultiplier;
    switch (currentCongestionLevel.toLowerCase()) {
      case 'low':
        congestionMultiplier = 1.0;
        break;
      case 'moderate':
        congestionMultiplier = 0.7;
        break;
      case 'heavy':
        congestionMultiplier = 0.4;
        break;
      case 'severe':
        congestionMultiplier = 0.2;
        break;
      default:
        congestionMultiplier = 1.0;
    }
    return 50.0 * congestionMultiplier * bus.baseSpeedMultiplier;
  }

  void _updateBusSpeedMultiplier(String busId, double newMultiplier) {
    setState(() {
      final int busIndex = _buses.indexWhere((b) => b.id == busId);
      if (busIndex != -1) {
        Bus updatedBus = _buses[busIndex].copyWith(baseSpeedMultiplier: newMultiplier);
        updatedBus.speed = _calculateEffectiveBusSpeed(updatedBus);
        _buses[busIndex] = updatedBus;
        debugPrint('Bus $busId speed multiplier updated to ${newMultiplier.toStringAsFixed(2)}. Effective speed: ${updatedBus.speed.toStringAsFixed(1)} km/h.');
      }
    });
  }

  // --- New: Function to send bus status data to backend ---
  Future<void> _sendBusStatusToBackend(Bus bus, String eventType) async {
    const String backendUrl = 'http://your-backend-url/api/bus_status_updates'; // !!! REPLACE WITH YOUR ACTUAL BACKEND URL !!!

    Map<String, dynamic> data = {
      "busId": bus.id,
      "eventType": eventType, // "arrival" or "departure"
      "timestamp": DateTime.now().toUtc().toIso8601String(),
      "location": {
        "latitude": bus.position.latitude,
        "longitude": bus.position.longitude,
      },
    };

    if (eventType == 'departure') {
      // Data specific to a bus departing on a new route
      data["currentStationName"] = _getStationName(bus.currentStartStation); // The station it just left
      data["nextDestinationName"] = _getStationName(bus.currentEndStation);
      data["estimatedArrivalTimeIso8601"] = DateTime.now().add(Duration(minutes: bus.totalRouteDurationMinutes.toInt())).toUtc().toIso8601String();
      data["distanceToDestinationKm"] = bus.totalRouteDistanceKm;
      data["totalRouteDurationMinutes"] = bus.totalRouteDurationMinutes;
      data["actualSpeedKmh"] = bus.speed;
      data["baseSpeedMultiplier"] = bus.baseSpeedMultiplier;
    } else if (eventType == 'arrival') {
      // Data specific to a bus arriving at a station
      data["arrivedAtStationName"] = _getStationName(bus.position); // The station it arrived at
      data["waitDurationSeconds"] = _stationWaitDuration.inSeconds;
    }

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Backend: Successfully sent $eventType report for Bus ${bus.id}');
      } else {
        debugPrint('Backend ERROR: Failed to send $eventType report for Bus ${bus.id}. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      debugPrint('Backend CRITICAL ERROR: Exception sending $eventType report for Bus ${bus.id}: $e');
    }
  }

  void _startBusSimulation() {
    _simulationTimer?.cancel();
    debugPrint("Starting bus simulation timer...");
    _simulationTimer = Timer.periodic(_simulationTickDuration, (timer) {
      setState(() {
        for (int i = 0; i < _buses.length; i++) {
          Bus bus = _buses[i];

          if (bus.isWaitingAtStation) {
            final now = DateTime.now();
            final Duration? timeSpentWaiting = bus.arrivalTimeAtStation != null ? now.difference(bus.arrivalTimeAtStation!) : null;

            if (timeSpentWaiting != null && timeSpentWaiting >= _stationWaitDuration) {
              debugPrint('Bus ${bus.id} finished waiting at ${_getStationName(bus.position)} after ${timeSpentWaiting.inSeconds} seconds.');
              bus = bus.copyWith(isWaitingAtStation: false, arrivalTimeAtStation: null);
              _buses[i] = bus;
              _dispatchBusToNewRandomRoute(bus); // This will eventually trigger a 'departure' report
              continue;
            } else {
              if (timeSpentWaiting == null || timeSpentWaiting.inSeconds % 5 == 0 || timeSpentWaiting.inSeconds == 0) {
                debugPrint('Bus ${bus.id} is waiting at ${_getStationName(bus.position)}. Remaining: ${_stationWaitDuration.inSeconds - (timeSpentWaiting?.inSeconds ?? 0)}s.');
              }
              bus = bus.copyWith(speed: 0.0);
              _buses[i] = bus;
              continue;
            }
          }

          if (bus.routePoints.length < 2) {
            debugPrint('Bus ${bus.id} has no valid route points to move on. Setting to waiting and re-fetching route. (Current route: ${_getStationName(bus.currentStartStation)} to ${_getStationName(bus.currentEndStation)})');
            bus = bus.copyWith(isWaitingAtStation: true, arrivalTimeAtStation: DateTime.now(), speed: 0.0);
            _buses[i] = bus;
            Future.delayed(const Duration(seconds: 5), () => _fetchRouteDataForBus(bus));
            continue;
          }

          bus.speed = _calculateEffectiveBusSpeed(bus);

          if (bus.speed == 0.0) {
            _buses[i] = bus;
            continue;
          }

          double tickDurationSeconds = _simulationTickDuration.inMilliseconds / 1000.0;
          double speedMps = bus.speed * (1000.0 / 3600.0);
          double distanceCoveredThisTickMeters = speedMps * tickDurationSeconds;

          while (distanceCoveredThisTickMeters > 0 && bus.currentSegmentIndex < bus.routePoints.length - 1) {
            final startPoint = bus.routePoints[bus.currentSegmentIndex];
            final endPoint = bus.routePoints[bus.currentSegmentIndex + 1];
            final double segmentDistanceMeters = _distance.distance(startPoint, endPoint);

            if (segmentDistanceMeters < 1e-6) { // Skip near-zero length segments
              debugPrint('WARNING: Bus ${bus.id}: Segment ${bus.currentSegmentIndex} has near-zero length (${segmentDistanceMeters.toStringAsFixed(6)}m). Skipping segment.');
              bus = bus.copyWith(
                currentSegmentIndex: bus.currentSegmentIndex + 1,
                progress: 0.0,
              );
              _buses[i] = bus;
              continue;
            }

            double remainingSegmentDistanceMeters = segmentDistanceMeters * (1.0 - bus.progress);
            double distanceToCoverThisTick = math.min(distanceCoveredThisTickMeters, remainingSegmentDistanceMeters);

            bus = bus.copyWith(
              progress: bus.progress + (distanceToCoverThisTick / segmentDistanceMeters),
            );

            distanceCoveredThisTickMeters -= distanceToCoverThisTick;

            if (bus.progress >= 1.0 - 1e-6) { // Account for floating-point precision
              debugPrint('Bus ${bus.id}: Completed segment ${bus.currentSegmentIndex}. Moving to next segment.');
              bus = bus.copyWith(
                currentSegmentIndex: bus.currentSegmentIndex + 1,
                progress: 0.0,
              );
            }

            _buses[i] = bus;
          }

          // Update bus position
          if (bus.currentSegmentIndex < bus.routePoints.length - 1) {
            final LatLng currentStartSeg = bus.routePoints[bus.currentSegmentIndex];
            final LatLng currentEndSeg = bus.routePoints[bus.currentSegmentIndex + 1];

            // Clamp progress to [0, 1] to prevent overshooting
            double clampedProgress = bus.progress.clamp(0.0, 1.0);

            bus = bus.copyWith(
              position: LatLng(
                currentStartSeg.latitude + (currentEndSeg.latitude - currentStartSeg.latitude) * clampedProgress,
                currentStartSeg.longitude + (currentEndSeg.longitude - currentStartSeg.longitude) * clampedProgress,
              ),
            );
            debugPrint('Bus ${bus.id}: Moving on segment ${bus.currentSegmentIndex}, progress: ${clampedProgress.toStringAsFixed(4)}, position: (${bus.position.latitude.toStringAsFixed(6)}, ${bus.position.longitude.toStringAsFixed(6)})');
          } else {
            // Bus has reached or is at the last point
            bus = bus.copyWith(
              position: bus.routePoints.last,
              currentSegmentIndex: bus.routePoints.length - 1,
              progress: 1.0,
              isWaitingAtStation: true,
              arrivalTimeAtStation: DateTime.now(),
              speed: 0.0,
            );
            debugPrint('Bus ${bus.id} arrived at station ${_getStationName(bus.position)}. Starting ${_stationWaitDuration.inSeconds} seconds wait.');
            // --- Send Arrival Report ---
            _sendBusStatusToBackend(bus, 'arrival');
          }
          _buses[i] = bus;
        }

        final List<Map<String, dynamic>> currentBusSpeeds = _buses.map((bus) {
          return {
            'busIndex': int.parse(bus.id),
            'speed': bus.speed / 50.0,
            'color': bus.color,
          };
        }).toList();
        widget.onBusSpeedsUpdated(currentBusSpeeds);
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeBuses();
      if (_buses.isNotEmpty) {
        _fitBounds(_buses);
        _startBusSimulation();
      }
    });

    _trafficUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      debugPrint("Fetching updated traffic data for all active buses (every 1 minute)...");
      for (var bus in _buses) {
        if (!bus.isWaitingAtStation && bus.routePoints.isNotEmpty) {
          _fetchRouteDataForBus(bus);
        }
      }
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final bool isOnline = results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
      if (isOnline) {
        debugPrint('Connectivity Restored! Attempting to re-sync route data for all buses.');
        for (var bus in _buses) {
          if (bus.isWaitingAtStation || bus.routePoints.isEmpty) {
            _fetchRouteDataForBus(bus);
          }
        }
      } else {
        debugPrint('Connectivity Lost!');
      }
    });
  }

  Future<void> _initializeBuses() async {
    List<Bus> initialBuses = [];
    int numberOfBusesToCreate = math.min(15, _busColors.length);

    for (int i = 0; i < numberOfBusesToCreate; i++) {
      LatLng initialStation = _busStations[_random.nextInt(_busStations.length)];
      List<LatLng> possibleEnds = List.from(_busStations);
      possibleEnds.removeWhere((dest) => dest == initialStation);

      LatLng initialEnd;
      if (possibleEnds.isEmpty) {
        initialEnd = initialStation;
        debugPrint('WARNING: Only one station available. Bus ${i+1} will try to route to itself.');
      } else {
        initialEnd = possibleEnds[_random.nextInt(possibleEnds.length)];
      }

      initialBuses.add(
        Bus(
          id: '${i + 1}',
          busName: 'Bus ${i + 1}',
          position: initialStation,
          currentStartStation: initialStation,
          currentEndStation: initialEnd,
          color: _busColors[i % _busColors.length],
          baseSpeedMultiplier: 1.0,
          isWaitingAtStation: true,
          arrivalTimeAtStation: DateTime.now(),
          speed: 0.0,
          totalRouteDistanceKm: 0.0, // Initial value
          totalRouteDurationMinutes: 0.0, // Initial value
        ),
      );
    }

    setState(() {
      _buses = initialBuses;
    });

    debugPrint('Initial bus routes assigned and buses set to initial wait state.');
  }

  void _showBusDetailsDialog(BuildContext context, Bus bus) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final currentBusState = _buses.firstWhere((b) => b.id == bus.id, orElse: () => bus);

            String waitStatus = 'Not Waiting';
            int remainingSeconds = 0;
            if (currentBusState.isWaitingAtStation && currentBusState.arrivalTimeAtStation != null) {
              final Duration timeSpentWaiting = DateTime.now().difference(currentBusState.arrivalTimeAtStation!);
              final Duration remainingTime = _stationWaitDuration - timeSpentWaiting;
              if (remainingTime.isNegative) {
                waitStatus = 'Finished Waiting (overdue by ${remainingTime.inSeconds.abs()}s)';
              } else {
                remainingSeconds = remainingTime.inSeconds;
                waitStatus = 'Waiting for $remainingSeconds seconds';
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 10,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [currentBusState.color.withOpacity(0.8), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currentBusState.busName,
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: currentBusState.color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                              shadows: [
                                Shadow(
                                  blurRadius: 4.0,
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(1.0, 1.0),
                                )
                              ]
                          ),
                        ),
                        Icon(Icons.directions_bus, size: 40, color: currentBusState.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white),
                      ],
                    ),
                    const Divider(height: 25, thickness: 1.5, color: Colors.black26),
                    _buildInfoRow(
                      icon: Icons.alt_route,
                      label: 'Route:',
                      value: '${_getStationName(currentBusState.currentStartStation)} to ${_getStationName(currentBusState.currentEndStation)}',
                      textColor: Colors.black87,
                    ),
                    _buildInfoRow(
                      icon: Icons.speed,
                      label: 'Current Speed:',
                      value: '${currentBusState.speed.toStringAsFixed(1)} km/h',
                      textColor: Colors.black87,
                    ),
                    _buildInfoRow(
                      icon: currentBusState.isWaitingAtStation ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      label: 'Status:',
                      value: currentBusState.isWaitingAtStation ? 'Waiting' : 'Driving',
                      textColor: currentBusState.isWaitingAtStation ? Colors.orange.shade700 : Colors.green.shade700,
                    ),
                    if (currentBusState.isWaitingAtStation)
                      _buildInfoRow(
                        icon: Icons.access_time,
                        label: 'Wait Status:',
                        value: waitStatus,
                        textColor: Colors.deepOrange.shade700,
                      ),
                    _buildInfoRow(
                      icon: Icons.location_on,
                      label: 'Position:',
                      value: 'Lat ${currentBusState.position.latitude.toStringAsFixed(4)}, Lon ${currentBusState.position.longitude.toStringAsFixed(4)}',
                      textColor: Colors.black87,
                    ),
                    _buildInfoRow(
                      icon: Icons.traffic,
                      label: 'Congestion:',
                      value: currentBusState.congestionLevels.isNotEmpty && currentBusState.currentSegmentIndex < currentBusState.congestionLevels.length
                          ? currentBusState.congestionLevels[currentBusState.currentSegmentIndex].toUpperCase()
                          : 'N/A',
                      textColor: _getCongestionColor(currentBusState.congestionLevels.isNotEmpty && currentBusState.currentSegmentIndex < currentBusState.congestionLevels.length
                          ? currentBusState.congestionLevels[currentBusState.currentSegmentIndex]
                          : ''),
                    ),
                    _buildInfoRow(
                      icon: Icons.directions,
                      label: 'Route Distance:',
                      value: '${currentBusState.totalRouteDistanceKm.toStringAsFixed(2)} km',
                      textColor: Colors.black87,
                    ),
                    _buildInfoRow(
                      icon: Icons.timer,
                      label: 'Route Duration:',
                      value: '${currentBusState.totalRouteDurationMinutes.toStringAsFixed(1)} min',
                      textColor: Colors.black87,
                    ),
                    const SizedBox(height: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adjust Speed Multiplier: x${currentBusState.baseSpeedMultiplier.toStringAsFixed(1)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                        ),
                        Slider(
                          value: currentBusState.baseSpeedMultiplier,
                          min: 0.1,
                          max: 2.0,
                          divisions: 19,
                          label: 'x${currentBusState.baseSpeedMultiplier.toStringAsFixed(1)}',
                          activeColor: currentBusState.color,
                          inactiveColor: currentBusState.color.withOpacity(0.3),
                          onChanged: (newValue) {
                            setState(() {
                              _updateBusSpeedMultiplier(currentBusState.id, newValue);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.close, color: Colors.blueGrey),
                        label: const Text('Close', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color textColor = Colors.black,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _trafficUpdateTimer?.cancel();
    _connectivitySubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialMapCenter,
            initialZoom: _initialMapZoom,
            initialRotation: _initialMapBearing,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onMapEvent: (event) {
              if (event is MapEventMove || event is MapEventRotate || event is MapEventMove) {
                if (event.source != MapEventSource.mapController && event.source != MapEventSource.onDrag) {
                  if (!_hasUserInteractedWithMap) {
                    setState(() {
                      _hasUserInteractedWithMap = true;
                    });
                  }
                }
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$_mapboxAccessToken',
              additionalOptions: {'accessToken': _mapboxAccessToken},
            ),
            TileLayer(
              key: _trafficTileLayerKey,
              urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/traffic-day-v2/tiles/{z}/{x}/{y}?access_token=$_mapboxAccessToken',
              additionalOptions: {'accessToken': _mapboxAccessToken},
              tileProvider: NetworkTileProvider(),
            ),
            PolylineLayer(
              polylines: _buses.expand((bus) => _createColoredPolylinesForBus(bus)).toList(),
            ),
            MarkerLayer(
              markers: [
                ..._busStations.map((station) {
                  String stationName = _getStationName(station);
                  return Marker(
                    point: station,
                    width: 80,
                    height: 50,
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.red.shade700, size: 25),
                        Text(
                          stationName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            backgroundColor: Colors.white70,
                            fontSize: 11,
                          ),
                        )
                      ],
                    ),
                  );
                }).toList(),
                ..._buses.map((bus) => Marker(
                  point: bus.position,
                  width: 60,
                  height: 55,
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: () {
                      _showBusDetailsDialog(context, bus);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black87.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Bus ${bus.id}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Tooltip(
                          message: 'Bus ${bus.id} (${_getStationName(bus.currentStartStation)} to ${_getStationName(bus.currentEndStation)})\n'
                              'Speed: ${bus.speed.toStringAsFixed(1)} km/h\n'
                              'Status: ${bus.isWaitingAtStation ? 'Waiting' : 'Driving'}',
                          child: Icon(Icons.directions_bus, color: bus.color, size: 35),
                        ),
                      ],
                    ),
                  ),
                )).toList(),
              ],
            ),
          ],
        ),
        Positioned(
          bottom: 16.0,
          right: 16.0,
          child: FloatingActionButton(
            heroTag: 'mapResetBtn',
            onPressed: () async {
              debugPrint('User pressed reset button. Resetting map and simulation...');
              _simulationTimer?.cancel();
              _trafficUpdateTimer?.cancel();
              _connectivitySubscription?.cancel();
              setState(() {
                _buses.clear();
              });

              await _initializeBuses();
              if (_buses.isNotEmpty) {
                _fitBounds(_buses);
                _startBusSimulation();
              }

              _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
                final bool isOnline = results.contains(ConnectivityResult.mobile) ||
                    results.contains(ConnectivityResult.wifi) ||
                    results.contains(ConnectivityResult.ethernet);
                if (isOnline) {
                  debugPrint('Connectivity Restored! Attempting to re-sync route data for all buses.');
                  for (var bus in _buses) {
                    if (bus.isWaitingAtStation || bus.routePoints.isEmpty) {
                      _fetchRouteDataForBus(bus);
                    }
                  }
                } else {
                  debugPrint('Connectivity Lost!');
                }
              });
            },
            backgroundColor: Colors.orange,
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        ),
        if (_hasUserInteractedWithMap)
          Positioned(
            bottom: 80.0,
            right: 16.0,
            child: FloatingActionButton(
              heroTag: 'resetViewBtn',
              onPressed: _resetMapToInitialView,
              backgroundColor: Colors.blue,
              mini: true,
              child: const Icon(Icons.location_searching, color: Colors.white),
            ),
          ),
      ],
    );
  }
}