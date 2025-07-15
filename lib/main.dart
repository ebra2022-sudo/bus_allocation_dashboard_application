import 'package:bus_allocation_dashboard_application/system_data_analytic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Keep if MapController is passed
import 'package:latlong2/latlong.dart'; // Keep if LatLng is used in signatures
import 'map_view.dart'; // Import your MapView widget
// Assume StockAnalyticsPage is defined in 'stock_analytics_page.dart' or similar
// Import StockAnalyticsPage

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const DashboardScreen(),
    );
  }
}

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

  // --- MODIFIED STATE VARIABLES ---
  // Define a fixed height for the analytics panel. This will not change.
  final double _fixedAnalyticsPanelHeight = 700.0;

  // This variable controls the 'bottom' property of the map panel.
  // When _mapPanelBottomOffset == _fixedAnalyticsPanelHeight, map is fully above analytics.
  // When _mapPanelBottomOffset == 0, map covers analytics fully (its bottom aligns with screen bottom).
  late double _mapPanelBottomOffset;
  // --- END MODIFIED STATE VARIABLES ---

  bool _isHovering = false;
  bool _isDragging = false;
  bool? _isDraggingUp;

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  String startPoint = '';
  String endPoint = '';

  List<Map<String, dynamic>> _busSpeeds = [];

  @override
  void initState() {
    super.initState();
    // Initialize _mapPanelBottomOffset to show map above analytics initially
    _mapPanelBottomOffset = _fixedAnalyticsPanelHeight;
  }

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
      // Dragging down (positive dy) reduces _mapPanelBottomOffset, pushing map down.
      // Dragging up (negative dy) increases _mapPanelBottomOffset, pulling map up.
      _mapPanelBottomOffset -= details.delta.dy;

      // Clamp _mapPanelBottomOffset:
      // Minimum: 0.0 (map's bottom is at the screen's bottom, covering analytics)
      // Maximum: _fixedAnalyticsPanelHeight (map's bottom is at the top of analytics, not covering it)
      _mapPanelBottomOffset = _mapPanelBottomOffset.clamp(
        0.0,
        _fixedAnalyticsPanelHeight,
      );

      // _analyticsHeight is no longer tied to _mapPanelBottomOffset.
      // The arrow direction indication will be based on the change in _mapPanelBottomOffset.
      _isDraggingUp =
          details.delta.dy <
          0; // True if dragging up (increasing offset, map goes up)
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;

      // Snap to fully covering analytics (mapPanelBottomOffset = 0)
      // or fully above analytics (mapPanelBottomOffset = _fixedAnalyticsPanelHeight)
      if (_mapPanelBottomOffset < _fixedAnalyticsPanelHeight / 2) {
        _mapPanelBottomOffset = 10.0; // Snap map down to cover analytics
      } else {
        _mapPanelBottomOffset =
            _fixedAnalyticsPanelHeight; // Snap map up to be above analytics
      }
      // Removed: _analyticsHeight = _mapBottomOffset; // This line caused the squeezing
    });
  }

  void _updateBusSpeeds(List<Map<String, dynamic>> busSpeeds) {
    setState(() {
      _busSpeeds = busSpeeds;
    });
  }

  @override
  Widget build(BuildContext context) {
    // The FloatingActionButton for the message panel should only be visible when the message panel is CLOSED.
    // AND when the map is NOT slid down to cover the FAB.
    // If _mapPanelBottomOffset is close to 0, it means the map is covering the bottom part of the screen where FAB is.
    bool isMapFullyDown =
        _mapPanelBottomOffset <=
        50.0; // Adjust threshold as needed for FAB disappearance

    final bool showMessageFab = !_isMessagePanelOpen && !isMapFullyDown;

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

      floatingActionButton:
          showMessageFab
              ? FloatingActionButton(
                heroTag: 'messageFab',
                onPressed: _toggleMessagePanel,
                hoverColor: Colors.blueAccent,
                backgroundColor: Colors.green,
                child: const Icon(Icons.message, color: Colors.white),
              )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          // Main content area for Analytics and Map
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: EdgeInsets.only(
              left: _isSidePanelOpen ? _sidePanelWidth : 0.0,
              // The right margin was removed in the previous fix to allow message panel to overlap.
              right: _isMessagePanelOpen ? _messagePanelWidth : 0.0,
            ),
            color: Colors.transparent,
            child: Stack(
              children: [
                // Analytics Graph (NOW WITH FIXED HEIGHT)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height:
                      _fixedAnalyticsPanelHeight, // <--- Using the fixed height here
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
                // Map View (SLIDES OVER ANALYTICS)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom:
                      _mapPanelBottomOffset, // <--- Controlled by drag to slide over analytics
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

                // Resizable Grab Handle (positioned just above the fixed analytics height)
                Positioned(
                  bottom:
                      _mapPanelBottomOffset, // <--- Handle stays at the top edge of analytics
                  left: 0,
                  right: 0,
                  height: 20,
                  child: Center(
                    child: MouseRegion(
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
                                          _isHovering
                                              ? Colors.blue
                                              : Colors.green,
                                      borderRadius: BorderRadius.circular(2.5),
                                    ),
                                  ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Side Panel (remains unchanged)
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
              child:
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
                                _toggleSidePanel();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.settings),
                              title: const Text('Settings'),
                              onTap: () {
                                _toggleSidePanel();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.info),
                              title: const Text('About'),
                              onTap: () {
                                _toggleSidePanel();
                              },
                            ),
                            SizedBox(
                              height: 200.0,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                ),
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
                            const SizedBox(height: 10),
                            Expanded(
                              child:
                                  _busSpeeds.isEmpty
                                      ? const Center(
                                        child: Text("No bus speeds available"),
                                      )
                                      : ListView.builder(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                        itemCount: _busSpeeds.length,
                                        itemBuilder: (context, index) {
                                          final bus = _busSpeeds[index];
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
                                                        bus['color'] as Color,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Bus ${bus['busIndex']}',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
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
                                        },
                                      ),
                            ),
                          ],
                        ),
                      )
                      : null,
            ),
          ),
          // Message Panel (remains unchanged from previous fix, allows overlap)
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
