import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
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
  final double _sidePanelWidth =200.0;
  final double _messagePanelWidth = 350.0;

  double _bottomHeight = 200.0;
  final double _minHeight = 100.0;
  final double _maxHeight = 500.0;

  bool _isHovering = false;

  bool _isDragging = false;
  bool? _isDraggingUp;

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
          child: CustomPaint(child: Container()),
        ),
        elevation: 4.0,
      ),
      floatingActionButton: _isMessagePanelOpen
          ? null // Hide FAB when message panel is open
          : FloatingActionButton(
        onPressed: _toggleMessagePanel,
        backgroundColor: Colors.green,
        child: const Icon(
          Icons.message,
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          // Main content (Map + bottom sheet)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: EdgeInsets.only(
              left: _isSidePanelOpen ? _sidePanelWidth : 0.0,
              right: _isMessagePanelOpen ? _messagePanelWidth : 0.0,
            ),
            color: Colors.white,
            child: Column(
              children: [
                // Map
                SizedBox(
                  height: mapHeight,
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.only(top: 10.0, left: 10.0, right: 10),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.0),
                        child: Image.asset(
                          'assets/map image.png',
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ),
                // Drag handle
                // Drag handle

                MouseRegion(
                  onEnter: (_) {
                    setState(() {
                      _isHovering = true;
                    });
                  },
                  onExit: (_) {
                    setState(() {
                      _isHovering = false;
                    });
                  },
                  child: GestureDetector(
                    onVerticalDragUpdate: _onVerticalDragUpdate,
                    onVerticalDragStart: _onVerticalDragStart,
                    onVerticalDragEnd: _onVerticalDragEnd,
                    child: Container(
                      height: 20, // Responsive height from previous updates
                      alignment: Alignment.center,
                      child:  _isDragging && _isDraggingUp == true
                          ? Icon(
                        Icons.arrow_upward,
                        size:  18.0, // Responsive icon size
                        color: _isDragging ? Colors.blue : Colors.grey.shade600,
                      ):
                      _isDragging && _isDraggingUp == false
                          ? Icon(
                        Icons.arrow_downward,
                        size:  18.0, // Responsive icon size
                        color: _isDragging ? Colors.blue : Colors.grey.shade600,
                      )
                          : Container(
                        width: 80, // Responsive width from previous updates
                        height: 8,
                        decoration: BoxDecoration(
                          color:  _isHovering ? Colors.blue : Colors.green,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Sheet
                Expanded(
                    child:SizedBox(
                      height: _bottomHeight - 10,
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 10.0, left: 10.0, right: 10),
                        color: Colors.transparent,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          child: Container(
                            color: const Color.fromARGB(255, 168, 255, 130),
                            child: const Center(child: Text("Resizable Bottom Panel")),
                          ),
                        ),
                      ),
                    ),
                )
              ],
            ),
          ),
          // Side panel (left)
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
                  children: [
                    ListTile(
                      leading: const Icon(Icons.map),
                      title: const Text('Map Options'),
                      onTap: () {},
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text('Settings'),
                      onTap: () {},
                    ),
                    ListTile(
                      leading: const Icon(Icons.info),
                      title: const Text('About'),
                      onTap: () {},
                    ),
                  ],
                ),
              )
                  : null,
            ),
          ),
          // Message panel (right)
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
                            onPressed: _toggleMessagePanel, // Close message panel
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Messages',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          children: const [
                            ListTile(
                              leading: Icon(Icons.person),
                              title: Text('Driver 1'),
                              subtitle: Text('Need more drivers in Zone A'),
                            ),
                            ListTile(
                              leading: Icon(Icons.person),
                              title: Text('Driver 2'),
                              subtitle: Text('ETA updated: 5 mins'),
                            ),
                          ],
                        ),
                      ),
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
                            icon: const Icon(Icons.send, color: Colors.green),
                            onPressed: () {
                              // Add send message logic here
                            },
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
}