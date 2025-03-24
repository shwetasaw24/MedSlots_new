import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
// import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';



void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: DoctorDashboard(),
  ));
}

class DoctorDashboard extends StatefulWidget {
  @override
  _DoctorDashboardState createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  int _selectedIndex = 0;
  List<Map<String, String>> patientHistory = [];

  final Map<String, List<Map<String, dynamic>>> appointments = {
    "Today": [
      {"name": "John Doe", "time": "10:00 AM", "contact": "123-456-7890", "done": false},
      {"name": "Emma Smith", "time": "11:30 AM", "contact": "987-654-3210", "done": false},
    ],
    "Tomorrow": [
      {"name": "Michael Brown", "time": "1:00 PM", "contact": "555-123-4567", "done": false},
      {"name": "Sophia Wilson", "time": "2:30 PM", "contact": "444-987-6543", "done": false},
    ],
    "Day After Tomorrow": [
      {"name": "James Anderson", "time": "9:30 AM", "contact": "333-567-8901", "done": false},
      {"name": "Olivia Taylor", "time": "3:00 PM", "contact": "222-234-5678", "done": false},
    ]
  };

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleDone(String day, int index, bool? value) {
    if (day == "Today") {
      setState(() {
        var patient = appointments[day]!.removeAt(index);
        patientHistory.add({"name": patient["name"], "contact": patient["contact"], "illness": "General Checkup"});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedIndex == 0
          ? HomeScreen(appointments: appointments, toggleDone: _toggleDone)
          : _selectedIndex == 1
              ? PatientHistoryScreen(patientHistory: patientHistory)
              : DoctorProfileScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> appointments;
  final Function(String, int, bool?) toggleDone;
  HomeScreen({required this.appointments, required this.toggleDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('MedSlots', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: ListView(
          children: appointments.keys.map((day) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                ...appointments[day]!.asMap().entries.map((entry) {
                  int index = entry.key;
                  var appointment = entry.value;
                  return Card(
                    child: ListTile(
                      title: Text(appointment["name"]!),
                      subtitle: Text('Time: ${appointment["time"]}\nContact: ${appointment["contact"]}'),
                      trailing: Checkbox(
                        value: appointment["done"],
                        onChanged: (day == "Today") ? (value) => toggleDone(day, index, value) : null,
                      ),
                    ),
                  );
                }).toList(),
                SizedBox(height: 10),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class PatientHistoryScreen extends StatelessWidget {
  final List<Map<String, String>> patientHistory;
  PatientHistoryScreen({required this.patientHistory});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Patient History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: patientHistory.length,
        itemBuilder: (context, index) {
          final patient = patientHistory[index];
          return Card(
            child: ListTile(
              title: Text(patient["name"]!),
              subtitle: Text('Contact: ${patient["contact"]}\nIllness: ${patient["illness"]}'),
              trailing: Icon(Icons.check_circle, color: Colors.green, size: 28),
            ),
          );
        },
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';

// import 'package:flutter/material.dart';
// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:async';


class DoctorProfileScreen extends StatefulWidget {
  @override
  _DoctorProfileScreenState createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  String currentAvailability = "9:00am - 12:00pm";
  String availabilityDay1 = "10:00am - 1:00pm";
  String availabilityDay2 = "4:00pm - 7:00pm";
  String clinicAddress = "Shree Girdhar Krupa Orthopedic Clinic";
  bool isBookingEnabled = true;
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currentAvailability = prefs.getString('currentAvailability') ?? currentAvailability;
      availabilityDay1 = prefs.getString('availabilityDay1') ?? availabilityDay1;
      availabilityDay2 = prefs.getString('availabilityDay2') ?? availabilityDay2;
      clinicAddress = prefs.getString('clinicAddress') ?? clinicAddress;
      isBookingEnabled = prefs.getBool('isBookingEnabled') ?? true;
    });
    _updateAvailabilityDaily();
  }

  Future<void> _updateAvailabilityDaily() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String lastUpdate = prefs.getString('lastUpdate') ?? "";
    String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    if (lastUpdate != todayDate) {
      setState(() {
        currentAvailability = availabilityDay1;
        availabilityDay1 = availabilityDay2;
        availabilityDay2 = "Not Set";
      });
      prefs.setString('currentAvailability', currentAvailability);
      prefs.setString('availabilityDay1', availabilityDay1);
      prefs.setString('availabilityDay2', availabilityDay2);
      prefs.setString('lastUpdate', todayDate);
    }
  }

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
          if (day == 1) {
            availabilityDay1 = "$formattedStartTime - $formattedEndTime";
          } else {
            availabilityDay2 = "$formattedStartTime - $formattedEndTime";
          }
        });
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setString(day == 1 ? 'availabilityDay1' : 'availabilityDay2', day == 1 ? availabilityDay1 : availabilityDay2);
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
            onPressed: () async {
              setState(() {
                clinicAddress = addressController.text;
              });
              SharedPreferences prefs = await SharedPreferences.getInstance();
              prefs.setString('clinicAddress', clinicAddress);
              Navigator.pop(context);
            },
            child: Text("Save"),
          )
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
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
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _profileImage != null ? FileImage(_profileImage!) : AssetImage('assets/doctor.jpg') as ImageProvider,
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text("Doctor’s Name: Dr. Diksha Gidwani", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("Specialization: Physiotherapist", style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text("Clinic’s Name: $clinicAddress", style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text("Current Availability: $currentAvailability", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text("Availability Tomorrow: $availabilityDay1", style: TextStyle(fontSize: 16)),
              Text("Availability Day After Tomorrow: $availabilityDay2", style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              SwitchListTile(
                title: Text("Enable Appointments"),
                value: isBookingEnabled,
                onChanged: (bool value) async {
                  setState(() {
                    isBookingEnabled = value;
                  });
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  prefs.setBool('isBookingEnabled', isBookingEnabled);
                },
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


