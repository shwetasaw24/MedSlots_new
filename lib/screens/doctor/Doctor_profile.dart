import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';

class DoctorProfileScreen extends StatefulWidget {
  @override
  _DoctorProfileScreenState createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  String currentAvailability = "9:00am - 12:00pm";
  String availabilityDay1 = "10:00am - 1:00pm";
  String availabilityDay2 = "4:00pm - 7:00pm";
  String clinicAddress = "Shree Girdhar Krupa Orthopedic Clinic";

  void _updateAvailability(int day) async {
    TimeOfDay? pickedStartTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedStartTime != null) {
      TimeOfDay? pickedEndTime = await showTimePicker(
        context: context,
        initialTime: pickedStartTime,
      );
      if (pickedEndTime != null) {
        setState(() {
          String formattedStartTime = pickedStartTime.format(context);
          String formattedEndTime = pickedEndTime.format(context);
          if (day == 0) {
            currentAvailability = "$formattedStartTime - $formattedEndTime";
          } else if (day == 1) {
            availabilityDay1 = "$formattedStartTime - $formattedEndTime";
          } else {
            availabilityDay2 = "$formattedStartTime - $formattedEndTime";
          }
        });
      }
    }
  }

  void _updateAddress() {
    TextEditingController addressController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Update Clinic Address"),
        content: TextField(
          controller: addressController,
          decoration: InputDecoration(hintText: "Enter new address"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                clinicAddress = addressController.text;
              });
              Navigator.pop(context);
            },
            child: Text("Save"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor Profile'),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage('assets/doctor.jpg'),
                ),
              ),
              SizedBox(height: 20),
              Text("Doctor’s Name: Dr. Diksha Gidwani", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("Specialization: Physiotherapist", style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text("Clinic’s Name: $clinicAddress", style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text("Current Availability: $currentAvailability", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text("Availability Tomorrow: $availabilityDay1", style: TextStyle(fontSize: 16)),
              Text("Availability Day After Tomorrow: $availabilityDay2", style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text("Contact Number: 7738999937", style: TextStyle(fontSize: 16)),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _updateAvailability(0),
                child: Text("Update Today's Availability"),
              ),
              ElevatedButton(
                onPressed: () => _updateAvailability(1),
                child: Text("Update Availability Tomorrow"),
              ),
              ElevatedButton(
                onPressed: () => _updateAvailability(2),
                child: Text("Update Availability Day After Tomorrow"),
              ),
              ElevatedButton(
                onPressed: _updateAddress,
                child: Text("Update Clinic Address"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: DoctorProfileScreen(),
  ));
}
