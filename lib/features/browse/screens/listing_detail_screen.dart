import 'package:flutter/material.dart';

class ListingDetailScreen extends StatelessWidget {
  final String id;
  const ListingDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Listing $id')));
}
