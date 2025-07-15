import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:intl/intl.dart';

class RouteData {
  final DateTime time;
  final int demand;
  final String routeName;

  RouteData(this.time, this.demand, this.routeName);
}

class StockAnalyticsPage extends StatefulWidget {
  const StockAnalyticsPage({super.key});

  @override
  _StockAnalyticsPageState createState() => _StockAnalyticsPageState();
}

class _StockAnalyticsPageState extends State<StockAnalyticsPage> {
  // State variables
  List<List<RouteData>> routeData = [];
  String selectedTimeFrame = 'Hourly';
  late WebSocketChannel channel;
  final ScrollController _scrollController = ScrollController();
  bool _isPaused = false;

  // Configuration
  // --- CORRECTED STATION NAMES HERE ---
  final List<String> stations = [
    '6 Kilo',
    '4 Kilo',
    'Piassa',
    'Kebena',
  ];
  late List<String> routeCombinations;
  late Map<String, bool> routeVisibility;
  final List<Color> routeColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.cyan,
    Colors.pink,
    Colors.yellow,
    Colors.teal,
    Colors.indigo,
    Colors.lime,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
    _connectWebSocket();
  }

  void _initialize() {
    routeCombinations = [];
    // Ensure the order of combinations matches how your backend defines them if important,
    // though the map lookup (`routeNameToIndex`) should handle reordering.
    // However, to prevent `Unknown routeName` initially, defining the exact combinations
    // as the backend would send them is the safest approach.
    // Let's explicitly list them as the backend does to guarantee a match.

    // This section needs to match the `self.routes` list in your Python backend
    // `TimeBasedDemandCalculator.__init__` method.
    routeCombinations = [
      '6 Kilo to 4 Kilo', '6 Kilo to Piassa', '6 Kilo to Kebena',
      '4 Kilo to 6 Kilo', '4 Kilo to Piassa', '4 Kilo to Kebena',
      'Piassa to 6 Kilo', 'Piassa to 4 Kilo', 'Piassa to Kebena',
      'Kebena to 6 Kilo', 'Kebena to 4 Kilo', 'Kebena to Piassa'
    ];


    routeVisibility = {for (var route in routeCombinations) route: false};
    if (routeCombinations.isNotEmpty) {
      // Set the first few routes to be visible by default, or just one
      for (int i = 0; i < math.min(3, routeCombinations.length); i++) {
        routeVisibility[routeCombinations[i]] = true;
      }
    }

    routeData = List.generate(routeCombinations.length, (_) => []);
  }

  void _connectWebSocket() {
    channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:8000/ws/multi_route/'),
    );
    channel?.stream.listen(
          (data) {
        if (!mounted) return;

        final decodedData = jsonDecode(data as String) as List<dynamic>;

        final Map<String, int> routeNameToIndex = {
          for (var i = 0; i < routeCombinations.length; i++)
            routeCombinations[i]: i
        };

        for (final item in decodedData) {
          if (item is Map<String, dynamic>) {
            final String routeName = item['routeName'];
            final int? index = routeNameToIndex[routeName];

            if (index != null) {
              final DateTime time = DateTime.parse(item['time']).toLocal();
              // CORRECTED: Parse demand directly as int
              final int demand = (item['demand'] ?? 0).toInt();

              final RouteData newRouteData = RouteData(time, demand, routeName);

              // Check if the routeData[index] list has been initialized
              if (routeData.length <= index) {
                // This scenario should ideally not happen if routeCombinations are correctly matched
                // However, as a safeguard, extend the list
                setState(() {
                  while (routeData.length <= index) {
                    routeData.add([]);
                  }
                });
              }

              routeData[index].add(newRouteData);

              // Optional: Limit historical entries
              // if (routeData[index].length > 100) {
              //   routeData[index].removeAt(0);
              // }
            } else {
              print('WebSocket Client: Unknown routeName received: $routeName');
            }
          }
        }

        if (!_isPaused) {
          setState(() {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
              );
            }
          });
        }
      },
      onError: (error) => print('WebSocket error: $error'),
      onDone: () => print('WebSocket connection closed'),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    channel.sink.close();
    super.dispose();
  }

  double _getAxisInterval() {
    // This logic might need refinement based on how many data points are expected
    // per time frame. Assuming data arrives every 2 seconds, and if a 1-minute view
    // shows, say, 30 points, then every 15 points (30 seconds) might be a good interval.
    // Let's make it dynamic based on the actual number of points.
    if (routeData.isEmpty || routeData[0].isEmpty) return 1.0;

    final int numberOfPoints = routeData[0].length;
    double interval = 1.0; // Default to showing every point

    switch (selectedTimeFrame) {
      case '1 Minute':
      // If we expect 30 points per minute (2-second interval), show every 10 points
        interval = (numberOfPoints / 3).floorToDouble(); // Approximately 20 seconds apart
        if (interval < 1) interval = 1;
        break;
      case '5 Minutes':
      // Show every minute mark (30 points * 5 minutes = 150 points total)
        interval = (numberOfPoints / 5).floorToDouble(); // Approximately 1 minute apart
        if (interval < 1) interval = 1;
        break;
      case 'Hourly':
      // Show every 10 minutes (30 points * 60 minutes / 6 = 300 points)
        interval = (numberOfPoints / 6).floorToDouble(); // Approximately 10 minutes apart
        if (interval < 1) interval = 1;
        break;
      case 'Weekly':
      case 'Monthly':
      case 'Yearly':
      // For longer timeframes, intervals will be much larger.
      // This will need more sophisticated date-based grouping.
      // For now, a simple proportion:
        interval = (numberOfPoints / 10).floorToDouble();
        if (interval < 1) interval = 1;
        break;
    }
    return interval;
  }

  // Helper method to format the X-axis labels based on the selected view
  Widget _getBottomTitleWidget(double value, TitleMeta meta) {
    final index = value.toInt();
    if (routeData.isEmpty ||
        routeData[0].isEmpty ||
        index < 0 ||
        index >= routeData[0].length) {
      return const SizedBox.shrink();
    }

    final currentData = routeData[0][index];
    // This check for previous data is only relevant for "Weekly", "Monthly", "Yearly"
    // where you only want to show labels at specific time boundaries.
    final prevData = index > 0 ? routeData[0][index - 1] : null; // Changed to nullable

    String text = '';

    // Always show time for '1 Minute', '5 Minutes', 'Hourly'
    if (selectedTimeFrame == '1 Minute' || selectedTimeFrame == '5 Minutes' || selectedTimeFrame == 'Hourly') {
      text = DateFormat('HH:mm').format(currentData.time);
    } else if (selectedTimeFrame == 'Weekly') {
      if (prevData == null || currentData.time.day != prevData.time.day) {
        text = DateFormat('EEE, d').format(currentData.time);
      }
    } else if (selectedTimeFrame == 'Monthly') {
      if (prevData == null || (currentData.time.day != prevData.time.day && (currentData.time.day == 1 || currentData.time.day == 15))) {
        text = DateFormat('MMM d, yy').format(currentData.time);
      }
    } else if (selectedTimeFrame == 'Yearly') {
      if (prevData == null || currentData.time.month != prevData.time.month) {
        text = DateFormat('MMM yy').format(currentData.time);
      }
    }


    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    // **CORRECTION APPLIED HERE**
    // Using the constructor as per the documentation
    return SideTitleWidget(
      meta: meta, // Use the provided axisSide from TitleMeta
      space: 8.0,
      child: Text(text, style: const TextStyle(fontSize: 10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Real-Time Route Analytics"),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            tooltip: _isPaused ? 'Resume' : 'Pause',
            onPressed: () {
              setState(() {
                _isPaused = !_isPaused;
              });
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text( // Made const as it doesn't change
                  'Demand (Passengers)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: selectedTimeFrame,
                  items:
                  <String>[
                    '1 Minute',
                    '5 Minutes',
                    'Hourly',
                    'Weekly',
                    'Monthly',
                    'Yearly',
                  ]
                      .map(
                        (String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                      .toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedTimeFrame = newValue;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
              child: _buildChart(),
            ),
          ),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildChart() {
    const double yAxisWidth = 50;
    return LayoutBuilder(
      builder: (context, constraints) {
        const double pointSpacing = 10.0;
        final double dataWidth =
        routeData.isNotEmpty && routeData[0].isNotEmpty
            ? routeData[0].length * pointSpacing
            : 0.0;
        final double chartWidth = math.max( // Use math.max for clarity
          constraints.maxWidth - yAxisWidth,
          dataWidth,
        );

        return Row(
          children: [
            SizedBox(
              width: yAxisWidth,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 170,
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: yAxisWidth,
                        interval: 20,
                        getTitlesWidget: (value, meta) {
                          // **CORRECTION APPLIED HERE**
                          // Using the constructor as per the documentation
                          return SideTitleWidget(
                            meta: meta, // Pass the axisSide
                            space: 4.0,
                            child: Text(
                              value.toStringAsFixed(0),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: chartWidth,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 170,
                      minX: 0,
                      maxX:
                      routeData.isNotEmpty && routeData[0].isNotEmpty
                          ? (routeData[0].length - 1).toDouble()
                          : 10,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: 20,
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: const Border( // Made const
                          bottom: BorderSide(color: Colors.black26),
                          left: BorderSide(color: Colors.black26),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: _getAxisInterval(),
                            getTitlesWidget: _getBottomTitleWidget,
                          ),
                        ),
                      ),
                      lineBarsData: _getLineBarsData(),
                      lineTouchData: _getLineTouchData(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegend() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: routeCombinations.length,
        itemBuilder: (context, index) {
          final routeName = routeCombinations[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      color: routeColors[index % routeColors.length],
                    ),
                    const SizedBox(width: 8),
                    Text(routeName, style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 24,
                  child: Switch(
                    value: routeVisibility[routeName]!,
                    onChanged:
                        (bool value) =>
                        setState(() => routeVisibility[routeName] = value),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<LineChartBarData> _getLineBarsData() {
    return List.generate(routeCombinations.length, (index) {
      if (!routeVisibility[routeCombinations[index]]! ||
          routeData[index].isEmpty) {
        return LineChartBarData(spots: []);
      }
      return LineChartBarData(
        spots:
        routeData[index]
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), e.value.demand.toDouble()))
            .toList(),
        isCurved: true,
        color: routeColors[index % routeColors.length],
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: routeColors[index % routeColors.length].withOpacity(0.2),
        ),
      );
    });
  }

  LineTouchData _getLineTouchData() {
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            final data = routeData[spot.barIndex][spot.x.toInt()];
            return LineTooltipItem(
              '${data.routeName}\n${DateFormat('HH:mm:ss').format(data.time)}\nDemand: ${data.demand.toStringAsFixed(1)}',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            );
          }).toList();
        },
      ),
      handleBuiltInTouches: true,
    );
  }
}