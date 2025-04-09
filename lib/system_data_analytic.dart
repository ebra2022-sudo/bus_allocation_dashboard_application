import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'dart:async';

class RouteData {
  final DateTime time;
  final double price;
  final String routeName;

  RouteData(this.time, this.price, this.routeName);
}

class StockAnalyticsPage extends StatefulWidget {
  const StockAnalyticsPage({super.key});

  @override
  _StockAnalyticsPageState createState() => _StockAnalyticsPageState();
}

class _StockAnalyticsPageState extends State<StockAnalyticsPage> {
  List<List<RouteData>> routeData = [];
  String selectedTimeFrame = 'Hourly';
  Random random = Random();
  double updateInterval = 1.0;
  String intervalUnit = 'Seconds';
  Timer? _timer;

  final List<String> stations = ['Station A', 'Station B', 'Station C', 'Station D'];
  late List<String> routeCombinations;
  late Map<String, bool> routeVisibility; // Track visibility of each route

  @override
  void initState() {
    super.initState();
    routeCombinations = [];
    for (int i = 0; i < stations.length; i++) {
      for (int j = 0; j < stations.length; j++) {
        if (i != j) {
          routeCombinations.add('${stations[i]} -> ${stations[j]}');
        }
      }
    }

    // Initialize visibility map (all routes visible by default)
    routeVisibility = { for (var route in routeCombinations) route : false };

    for (int i = 0; i < routeCombinations.length; i++) {
      routeData.add([]);
    }

    generateInitialData();
    startDataUpdate();
  }

  void generateInitialData() {
    for (int routeIndex = 0; routeIndex < routeCombinations.length; routeIndex++) {
      routeData[routeIndex].clear();
      DateTime now = DateTime.now();
      double basePrice = 100.0 + routeIndex * 10;

      int points = getPointsForTimeFrame(selectedTimeFrame);
      for (int i = points; i >= 0; i--) {
        DateTime time = getTimeForFrame(now, i);
        double variation = random.nextDouble() * 2 - 1;
        basePrice += variation;
        routeData[routeIndex].add(RouteData(time, basePrice, routeCombinations[routeIndex]));
      }
    }
  }

  void updateData() {
    setState(() {
      DateTime now = DateTime.now();
      for (int routeIndex = 0; routeIndex < routeCombinations.length; routeIndex++) {
        double lastPrice = routeData[routeIndex].last.price;
        double variation = random.nextDouble() * 2 - 1;
        routeData[routeIndex].add(RouteData(now, lastPrice + variation, routeCombinations[routeIndex]));

        int points = getPointsForTimeFrame(selectedTimeFrame);
        if (routeData[routeIndex].length > points) {
          routeData[routeIndex].removeAt(0);
        }
      }
    });
  }


  // sytem  deisng the
  void startDataUpdate() {
    _timer?.cancel();
    Duration duration;
    switch (intervalUnit) {
      case 'Seconds':
        duration = Duration(milliseconds: (updateInterval * 1000).toInt());
        break;
      case 'Minutes':
        duration = Duration(seconds: (updateInterval * 60).toInt());
        break;
      default:
        duration = Duration(milliseconds: (updateInterval * 1000).toInt());
    }
    _timer = Timer.periodic(duration, (timer) => updateData());
  }

  int getPointsForTimeFrame(String timeFrame) {
    switch (timeFrame) {
      case 'Hourly': return 48;
      case 'Daily': return 60;
      case 'Weekly': return 104;
      case 'Monthly': return 24;
      case 'Yearly': return 20;
      default: return 48;
    }
  }
  // design
  DateTime getTimeForFrame(DateTime now, int i) {
    switch (selectedTimeFrame) {
      case 'Hourly':
        return now.subtract(Duration(hours: i));
      case 'Daily':
        return now.subtract(Duration(days: i));
      case 'Weekly':
        return now.subtract(Duration(days: i * 7));
      case 'Monthly':
        return DateTime(now.year, now.month - i, now.day);
      case 'Yearly':
        return DateTime(now.year - i, now.month, now.day);
      default:
        return now.subtract(Duration(hours: i));
    }
  }

  // get axis labal


  String getAxisLabel(double value) {
    int index = value.toInt();
    if (index >= 0 && index < routeData[0].length) {
      DateTime time = routeData[0][index].time;
      switch (selectedTimeFrame) {
        case 'Hourly':
          return '${time.hour % 12 == 0 ? 12 : time.hour % 12}${time.hour < 12 ? 'AM' : 'PM'}';
        case 'Daily':
          return '${time.day}';
        case 'Weekly':
          List<String> days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
          return days[time.weekday % 7];
        case 'Monthly':
          List<String> months = [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
          ];
          return '${months[time.month - 1]} ${time.day}';
        case 'Yearly':
          return '${time.year}';
      }
    }
    return '';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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


    // colum of the  deisn ghe sat

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.all(8.0),
              child: DropdownButton<String>(
                value: selectedTimeFrame,
                items: <String>['Hourly', 'Daily', 'Weekly', 'Monthly', 'Yearly']
                    .map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedTimeFrame = newValue!;
                    generateInitialData();
                  });
                },
              ),
            ),
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Interval'),
                    onChanged: (value) {
                      setState(() {
                        updateInterval = double.tryParse(value) ?? 1.0;
                        startDataUpdate();
                      });
                    },
                  ),
                ),
                SizedBox(width: 8),
                DropdownButton<String>(
                  value: intervalUnit,
                  items: <String>['Seconds', 'Minutes']
                      .map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      intervalUnit = newValue!;
                      startDataUpdate();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        // sample of the current vlaue of the  deiang he
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: routeData[0].length * 30.0,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(drawHorizontalLine: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          getTitlesWidget: (value, meta) => Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Text(
                              value.toStringAsFixed(1),
                              style: TextStyle(fontSize: 10, color: Colors.white),
                            ),
                          ),
                        ),
                        axisNameWidget: Text('Price', style: TextStyle(color: Colors.white)),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 30,
                          reservedSize: 60,
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                getAxisLabel(value),
                                style: TextStyle(fontSize: 10, color: Colors.white),
                              ),
                            );
                          },
                        ),
                        axisNameWidget: Text('Time', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    minX: 0,
                    maxX: routeData[0].length.toDouble() - 1,
                    lineBarsData: List.generate(routeCombinations.length, (index) {
                      if (!routeVisibility[routeCombinations[index]]!) {
                        return LineChartBarData(spots: []); // Empty line if not visible
                      }
                      return LineChartBarData(
                        spots: routeData[index]
                            .asMap()
                            .entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value.price))
                            .toList(),
                        isCurved: true,
                        color: routeColors[index % routeColors.length],
                        barWidth: 2,
                        belowBarData: BarAreaData(show: false),
                      );
                    }),
                    backgroundColor: Colors.black87,
                    borderData: FlBorderData(show: true, border: Border.all(color: Colors.white30)),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Legend with toggle switches
        Container(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: List.generate(routeCombinations.length, (index) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 100),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      color: routeColors[index % routeColors.length],
                    ),
                    SizedBox(width: 4),
                    Text(
                      routeCombinations[index],
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    SizedBox(width: 4),
                    Switch(
                      value: routeVisibility[routeCombinations[index]]!,
                      onChanged: (bool value) {
                        setState(() {
                          routeVisibility[routeCombinations[index]] = value;
                        });
                      },
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.grey,
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}