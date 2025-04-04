import 'package:flutter/material.dart';




// About Screen
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: Colors.green,
        leading: IconButton(onPressed: () => {Navigator.pop(context)}, icon: Icon(Icons.arrow_back)),
      ),
      body: const Center(
        child: Text(
          'About Screen',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

