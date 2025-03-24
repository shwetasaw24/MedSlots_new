import 'package:flutter/material.dart';

class SearchDoctorScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Search Doctor'), leading: BackButton()),
      body: Column(
        children: [
          TextField(decoration: InputDecoration(labelText: 'Search Doctor by Name or Specialization')),
          ElevatedButton(
            onPressed: () {},
            child: Text('Search'),
          ),
          ElevatedButton(
            onPressed: () {},
            child: Text('Book Appointment'),
          ),
        ],
      ),
    );
  }
}
