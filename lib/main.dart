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
        primarySwatch: Colors.blue,
      ),
      home: DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isSidePanelOpen = false; // Tracks if the side panel is open
  final double _sidePanelWidth = 200.0; // Width of the side panel

  void _toggleSidePanel() {
    setState(() {
      _isSidePanelOpen = !_isSidePanelOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child:  Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.black, fontSize: 40,fontWeight: FontWeight.bold ), // White text for contrast
        )),
        leading: IconButton(
          icon: Icon(
            _isSidePanelOpen ? Icons.arrow_back : Icons.menu,
            color: Colors.white, // White icon for contrast
          ),
          onPressed: _toggleSidePanel,
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 10, 184, 85), // Darker grey again
                Color.fromARGB(255, 255, 255, 255), // Darker grey again
                Color.fromARGB(255, 10, 184, 85), // Darker grey again
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: CustomPaint(
            child: Container(),
          ),
        ),
        elevation: 4.0, // Add shadow for depth
      ),
      body: Stack(
        children: [
          // Main content (Map view)
          AnimatedContainer(
            color: Colors.white ,
            duration: Duration(milliseconds: 300),
            margin: EdgeInsets.only(
              left: _isSidePanelOpen ? _sidePanelWidth : 0.0,
            ),
            child: Column(
              children: [
                // Map view (using a placeholder image)
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Colors.transparent,
                    padding: EdgeInsets.all(10.0),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.0), // Apply corner radius
                        child: Image.asset(
                          'assets/map image.png', // Path to your asset image
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    ),
                  ),
                ),
                // Bottom section (white space below the map)
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.transparent,
                    padding: EdgeInsets.only(top: 0.0, bottom: 10.0, right: 10.0, left: 10.0),
                    child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10.0), // Apply corner radius
                          child: Container(
                            color: Color.fromARGB(255, 168, 255, 130),
                          ),
                        )
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Side panel with shadow and corner radius
          Padding(
            padding: EdgeInsets.only(top: 10, bottom: 10), // Adds 10px spacing from AppBar and Bottom
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              width: _isSidePanelOpen ? _sidePanelWidth : 0.0,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(10.0), // Rounded top-right corner
                  bottomRight: Radius.circular(10.0), // Rounded bottom-right corner
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20), // Shadow color
                    offset: Offset(5, 0), // Shadow offset (X-axis only)
                    blurRadius: 10.0, // Softness of the shadow
                    spreadRadius: 2.0, // Spread of the shadow
                  ),
                ],
              ),
              child: _isSidePanelOpen
                  ? Padding(
                padding: EdgeInsets.symmetric(vertical: 10), // Inner padding for content
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.map),
                      title: Text('Map Options'),
                      onTap: () {},
                    ),
                    ListTile(
                      leading: Icon(Icons.settings),
                      title: Text('Settings'),
                      onTap: () {},
                    ),
                    ListTile(
                      leading: Icon(Icons.info),
                      title: Text('About'),
                      onTap: () {},
                    ),
                  ],
                ),
              )
                  : null,
            ),
          )
        ],
      ),
    );
  }
}