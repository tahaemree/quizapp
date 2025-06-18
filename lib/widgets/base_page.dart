import 'package:flutter/material.dart';
import 'drawer.dart' show DrawerMenu;
import 'custom_app_bar.dart';

class BasePage extends StatelessWidget {
  final String title;
  final Widget content;

  const BasePage({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: title),
      drawer: const DrawerMenu(),
      body: Center(child: content),
    );
  }
}
