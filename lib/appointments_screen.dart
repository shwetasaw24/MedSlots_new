import 'package:flutter/material.dart';

class AppointmentsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Appointments')),
      body: ListView(
        children: [
          AppointmentCard(name: "John Doe", contact: "1234567890", illness: "Flu"),
          AppointmentCard(name: "Jane Doe", contact: "9876543210", illness: "Cold"),
        ],
      ),
    );
  }
}

class AppointmentCard extends StatelessWidget {
  final String name, contact, illness;

  AppointmentCard({required this.name, required this.contact, required this.illness});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(10),
      child: ListTile(
        title: Text(name),
        subtitle: Text("Contact: $contact\nIllness: $illness"),
        trailing: Checkbox(value: false, onChanged: (bool? value) {}),
      ),
    );
  }
}
