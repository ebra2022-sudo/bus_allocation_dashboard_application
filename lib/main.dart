import 'package:bus_allocation_dashboard_application/map_view.dart';
import 'package:bus_allocation_dashboard_application/setting_screen.dart';
import 'package:flutter/material.dart';
import 'about_screen.dart';
import 'map_option_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      theme: ThemeData(primarySwatch: Colors.green),
      initialRoute: '/dashboard',
      routes: {
        '/dashboard': (context) => const DashboardScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/map-options': (context) => const MapOptionsScreen(),
        '/about': (context) => const AboutScreen(),
      },
    );
  }
}

// Dashboard Screen
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isSidePanelOpen = false;
  bool _isMessagePanelOpen = false;
  final double _sidePanelWidth = 350.0;
  final double _messagePanelWidth = 350.0;

  double _bottomHeight = 200.0;
  final double _minHeight = 100.0;
  final double _maxHeight = 500.0;

  bool _isHovering = false;
  bool _isDragging = false;
  bool? _isDraggingUp;

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  String startPoint = '';
  String endPoint = '';

  // Store bus speeds from MapView
  List<Map<String, dynamic>> _busSpeeds = [];

  void _triggerSearch() {
    setState(() {
      startPoint = _startController.text;
      endPoint = _endController.text;
    });
  }

  void _toggleSidePanel() {
    setState(() {
      _isSidePanelOpen = !_isSidePanelOpen;
    });
  }

  void _toggleMessagePanel() {
    setState(() {
      _isMessagePanelOpen = !_isMessagePanelOpen;
    });
  }

  void _onVerticalDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _bottomHeight -= details.delta.dy;
      _bottomHeight = _bottomHeight.clamp(_minHeight, _maxHeight);
      _isDraggingUp = details.delta.dy < 0;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
  }

  // Callback to receive bus speeds from MapView
  void _updateBusSpeeds(List<Map<String, dynamic>> busSpeeds) {
    setState(() {
      _busSpeeds = busSpeeds;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double totalHeight = MediaQuery.of(context).size.height;
    final double mapHeight = totalHeight - _bottomHeight - kToolbarHeight;

    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'Admin Dashboard',
            style: TextStyle(
              color: Colors.black,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            _isSidePanelOpen ? Icons.arrow_back : Icons.menu,
            color: Colors.white,
          ),
          onPressed: _toggleSidePanel,
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 10, 184, 85),
                Color.fromARGB(255, 255, 255, 255),
                Color.fromARGB(255, 10, 184, 85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4.0,
      ),
      floatingActionButton: _isMessagePanelOpen
          ? null
          : FloatingActionButton(
        onPressed: _toggleMessagePanel,
        hoverColor: Colors.blueAccent,
        backgroundColor: Colors.green,
        child: const Icon(Icons.message, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: EdgeInsets.only(
              left: _isSidePanelOpen ? _sidePanelWidth : 0.0,
              right: _isMessagePanelOpen ? _messagePanelWidth : 0.0,
            ),
            color: Colors.white,
            child: Column(
              children: [
                SizedBox(
                  height: mapHeight,
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.only(
                      top: 10.0,
                      left: 10.0,
                      right: 10,
                    ),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.0),
                        child: MapView(
                          startPoint: startPoint,
                          endPoint: endPoint,
                          onSearch: () {},
                          onBusSpeedsUpdated: _updateBusSpeeds,
                        ),
                      ),
                    ),
                  ),
                ),
                MouseRegion(
                  onEnter: (_) => setState(() => _isHovering = true),
                  onExit: (_) => setState(() => _isHovering = false),
                  child: GestureDetector(
                    onVerticalDragUpdate: _onVerticalDragUpdate,
                    onVerticalDragStart: _onVerticalDragStart,
                    onVerticalDragEnd: _onVerticalDragEnd,
                    child: Container(
                      height: 20,
                      alignment: Alignment.center,
                      child: _isDragging && _isDraggingUp == true
                          ? Icon(
                        Icons.arrow_upward,
                        size: 18.0,
                        color: _isDragging ? Colors.blue : Colors.grey.shade600,
                      )
                          : _isDragging && _isDraggingUp == false
                          ? Icon(
                        Icons.arrow_downward,
                        size: 18.0,
                        color: _isDragging ? Colors.blue : Colors.grey.shade600,
                      )
                          : Container(
                        width: 80,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isHovering ? Colors.blue : Colors.green,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: _bottomHeight - 10,
                    child: Container(
                      padding: const EdgeInsets.only(
                        bottom: 10.0,
                        left: 10.0,
                        right: 10,
                      ),
                      color: Colors.transparent,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.0),
                        child: Container(
                          color: const Color.fromARGB(255, 168, 255, 130),
                          child: const Center(
                            child: StockAnalyticsPage(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _isSidePanelOpen ? _sidePanelWidth : 0.0,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(10.0),
                  bottomRight: Radius.circular(10.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(5, 0),
                    blurRadius: 10.0,
                    spreadRadius: 2.0,
                  ),
                ],
              ),
              child: _isSidePanelOpen
                  ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.map),
                      title: const Text('Map Options'),
                      onTap: () {
                        Navigator.pushNamed(context, '/map-options');
                        _toggleSidePanel();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text('Settings'),
                      onTap: () {
                        Navigator.pushNamed(context, '/settings');
                        _toggleSidePanel();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.info),
                      title: const Text('About'),
                      onTap: () {
                        Navigator.pushNamed(context, '/about');
                        _toggleSidePanel();
                      },
                    ),
                    SizedBox(
                      height: 200.0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            TextField(
                              controller: _startController,
                              decoration: const InputDecoration(
                                labelText: 'Start Location',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextField(
                              controller: _endController,
                              decoration: const InputDecoration(
                                labelText: 'End Location',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _triggerSearch,
                              child: const Text('Plot Route'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10), // Spacer before card list
                    Expanded(
                      child: _busSpeeds.isEmpty
                          ? const Center(child: Text("No bus speeds available"))
                          : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        children: _busSpeeds.map((bus) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Icon(Icons.directions_bus,
                                      color: bus['color'] as Color),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bus ${bus['busIndex'] + 1} (${bus['routeName']})',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Speed: ${(bus['speed'] * 100).toStringAsFixed(0)}%',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              )
                  : null,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isMessagePanelOpen ? _messagePanelWidth : 0.0,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10.0),
                    bottomLeft: Radius.circular(10.0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      offset: Offset(-5, 0),
                      blurRadius: 10.0,
                      spreadRadius: 2.0,
                    ),
                  ],
                ),
                child: _isMessagePanelOpen
                    ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: _toggleMessagePanel,
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'Messages',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: ListView(children: const [])),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.send,
                              color: Colors.green,
                            ),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }
}



class StockData {
  final DateTime time;
  final double price;

  StockData(this.time, this.price);
}

class StockAnalyticsPage extends StatefulWidget {
  const StockAnalyticsPage({super.key});

  @override
  _StockAnalyticsPageState createState() => _StockAnalyticsPageState();
}

class _StockAnalyticsPageState extends State<StockAnalyticsPage> {
  List<StockData> stockData = [];
  String selectedTimeFrame = 'Hourly';
  Random random = Random();
  double updateInterval = 1.0; // Default: 1 second
  String intervalUnit = 'Seconds'; // Default unit
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    generateInitialData();
    startDataUpdate();
  }

  void generateInitialData() {
    stockData.clear();
    DateTime now = DateTime.now();
    double basePrice = 100.0;

    int points = getPointsForTimeFrame(selectedTimeFrame);
    for (int i = points; i >= 0; i--) {
      DateTime time = getTimeForFrame(now, i);
      double variation = random.nextDouble() * 2 - 1;
      basePrice += variation;
      stockData.add(StockData(time, basePrice));
    }
  }

  void updateData() {
    setState(() {
      DateTime now = DateTime.now();
      double lastPrice = stockData.last.price;
      double variation = random.nextDouble() * 2 - 1;
      stockData.add(StockData(now, lastPrice + variation));

      int points = getPointsForTimeFrame(selectedTimeFrame);
      if (stockData.length > points) {
        stockData.removeAt(0);
      }
    });
  }

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
      case 'Hourly': return 48; // 2 days worth for scrolling
      case 'Daily': return 60; // 2 months
      case 'Weekly': return 104; // 2 years
      case 'Monthly': return 24; // 2 years
      case 'Yearly': return 20; // 20 years
      default: return 48;
    }
  }

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

  String getAxisLabel(double value) {
    int index = value.toInt();
    if (index >= 0 && index < stockData.length) {
      DateTime time = stockData[index].time;
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
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: stockData.length * 30.0, // Dynamic width based on data points
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(drawHorizontalLine: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) => Text(
                            value.toStringAsFixed(1),
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        axisNameWidget: Text('Stock Price'),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 30, // Space labels every 30 units
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                getAxisLabel(value),
                                style: TextStyle(fontSize: 12),
                              ),
                            );
                          },
                        ),
                        axisNameWidget: Text('Time'),
                      ),
                    ),
                    minX: 0,
                    maxX: stockData.length.toDouble() - 1,
                    lineBarsData: [
                      LineChartBarData(
                        spots: stockData
                            .asMap()
                            .entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value.price))
                            .toList(),
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 2,
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.blue.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}