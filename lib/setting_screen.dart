import 'package:flutter/material.dart';


// Settings Screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.green,
        leading: IconButton(onPressed: () => {}, icon: Icon(Icons.arrow_back)),
      ),
      body: const Center(
        child: Text(
          'Settings Screen',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
