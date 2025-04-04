import 'package:flutter/material.dart';




// Map Options Screen
class MapOptionsScreen extends StatelessWidget {
  const MapOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Options'),
        backgroundColor: Colors.green,
        leading: IconButton(onPressed: () => {}, icon: Icon(Icons.arrow_back)),
      ),
      body: const Center(
        child: Text(
          'Map Options Screen',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}