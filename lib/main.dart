import 'package:bus_allocation_dashboard_application/map_view.dart';
import 'package:bus_allocation_dashboard_application/setting_screen.dart';
import 'package:bus_allocation_dashboard_application/system_data_analytic.dart';
import 'package:flutter/material.dart';
import 'about_screen.dart';
import 'map_option_screen.dart';


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



// ample of  the current
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

  double _bottomHeight = 240.0;
  final double _minHeight = 240.0;
  final double _maxHeight = 600.0;

  bool _isHovering = false;
  bool _isDragging = false;
  bool? _isDraggingUp;

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  // design the  ste of the  deig
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

      // design the  stat oe ghte
      floatingActionButton:
          _isMessagePanelOpen
              ? null
              : FloatingActionButton(
                onPressed: _toggleMessagePanel,
                hoverColor: Colors.blueAccent,
                backgroundColor: Colors.green,
                child: const Icon(Icons.message, color: Colors.white),
              ),
      //floting action buttton
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
                      child:
                          _isDragging && _isDraggingUp == true
                              ? Icon(
                                Icons.arrow_upward,
                                size: 18.0,
                                color:
                                    _isDragging
                                        ? Colors.blue
                                        : Colors.grey.shade600,
                              )
                              : _isDragging && _isDraggingUp == false
                              ? Icon(
                                Icons.arrow_downward,
                                size: 18.0,
                                color:
                                    _isDragging
                                        ? Colors.blue
                                        : Colors.grey.shade600,
                              )
                              : Container(
                                width: 80,
                                height: 8,
                                decoration: BoxDecoration(
                                  color:
                                      _isHovering ? Colors.blue : Colors.green,
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
                          child: const Center(child: StockAnalyticsPage()),
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
                //  design the sate of the current value
              ),
              child:
                  // design the  sample of the current vahe
                  _isSidePanelOpen
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                ),

                                /**
                                 * dwsign the state of the current
                                 * */
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
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
                            const SizedBox(
                              height: 10,
                            ), // Spacer before card list
                            Expanded(
                              child:
                                  _busSpeeds.isEmpty
                                      ? const Center(
                                        child: Text("No bus speeds available"),
                                      )
                                      : ListView(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                        children:
                                            _busSpeeds.map((bus) {
                                              return Card(
                                                margin: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    8.0,
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    children: [
                                                      Icon(
                                                        Icons.directions_bus,
                                                        color:
                                                            bus['color']
                                                                as Color,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Bus ${bus['busIndex'] + 1} (${bus['routeName']})',
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
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
          // Align thestt
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
                child:
                    _isMessagePanelOpen
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
                                          borderRadius: BorderRadius.circular(
                                            8.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // state ase of the  current   value pf the die
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

  // sample the current vlaue

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }
}
