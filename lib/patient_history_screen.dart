import 'package:flutter/material.dart';

class PatientHistoryScreen extends StatefulWidget {
  @override
  _PatientHistoryScreenState createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen> {
  final List<Map<String, String>> patients = [
    {
      "name": "John Doe",
      "contact": "+1 234 567 890",
      "illness": "Fever & Cough"
    },
    {
      "name": "Emma Smith",
      "contact": "+1 987 654 321",
      "illness": "Migraine"
    },
    {
      "name": "Michael Brown",
      "contact": "+1 543 210 987",
      "illness": "Back Pain"
    }
  ];

  void addPatient(String name, String contact, String illness) {
    setState(() {
      patients.add({"name": name, "contact": contact, "illness": illness});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Patient History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.teal.shade100],
          ),
        ),
        padding: EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: patients.length,
          itemBuilder: (context, index) {
            final patient = patients[index];
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: EdgeInsets.all(12),
                leading: CircleAvatar(
                  backgroundImage: AssetImage('assets/patient.jpg'),
                  radius: 28,
                ),
                title: Text(
                  patient["name"]!,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 16, color: Colors.grey),
                        SizedBox(width: 5),
                        Text(patient["contact"]!, style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.local_hospital, size: 16, color: Colors.grey),
                        SizedBox(width: 5),
                        Text(patient["illness"]!, style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ],
                ),
                trailing: Icon(Icons.check_circle, color: Colors.green, size: 28),
              ),
            );
          },
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: PatientHistoryScreen(),
  ));
}
