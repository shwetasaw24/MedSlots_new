import 'package:flutter/material.dart';
import 'package:flutter_medslots/upload_report.dart';
import 'patient_profile_screen.dart';
import 'doctor_clinic_details.dart';
import 'package:shared_preferences/shared_preferences.dart';
export 'doctor_clinic_details.dart';
import 'package:fluttertoast/fluttertoast.dart';

 // Import the clinic details screen

class PatientDashboard extends StatelessWidget {
  final String? patientProfileImage; // Patient's uploaded profile image

  PatientDashboard({this.patientProfileImage});

  final List<Map<String, String>> clinics = [
    {
      'name': 'Healing Hands Clinic',
      'doctor': 'Dr. Diksha Gidwani',
      'specialty': 'Physiotherapist',
      'availabilityTime': 'Mon-Fri, 10AM - 5PM',
      'contactNumber': '+91 9876543210',
      'location': 'Mumbai, India',
      'imageUrl': 'assets/clinic1.png'
    },
    {
      'name': 'Care & Cure Center',
      'doctor': 'Dr. Rajesh Sharma',
      'specialty': 'General Physician',
      'availabilityTime': 'Mon-Sat, 9AM - 6PM',
      'contactNumber': '+91 9123456789',
      'location': 'Delhi, India',
      'imageUrl': 'assets/clinic2.png'
    },
    {
      'name': 'Wellness Hub',
      'doctor': 'Dr. Nita Kapoor',
      'specialty': 'Orthopedic',
      'availabilityTime': 'Tue-Sun, 8AM - 3PM',
      'contactNumber': '+91 9988776655',
      'location': 'Bangalore, India',
      'imageUrl': 'assets/clinic3.png'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MedSlots', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              // Handle notification click
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade100, Colors.teal.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: patientProfileImage != null
                      ? AssetImage(patientProfileImage!)
                      : AssetImage('assets/default_profile.png'), // Default profile icon
                ),
                SizedBox(width: 10),
                Text('Welcome, Patient!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: clinics.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: EdgeInsets.all(10),
                  elevation: 5,
                  shadowColor: Colors.teal,
                  child: ListTile(
                    title: Text(
                      clinics[index]['name']!,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                    ),
                    subtitle: Text('${clinics[index]['doctor']} - ${clinics[index]['specialty']}'),
                    trailing: Icon(Icons.arrow_forward_ios, color: Colors.teal),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DoctorDetailsScreen(
                            clinicName: clinics[index]['name']!,
                            doctorName: clinics[index]['doctor']!,
                            specialization: clinics[index]['specialty']!,
                            availability: clinics[index]['availabilityTime']!,
                            contact: clinics[index]['contactNumber']!,
                            location: clinics[index]['location']!,
                            imageUrl: clinics[index]['imageUrl']!,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard, color: Colors.teal),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload_file, color: Colors.teal),
            label: 'Upload Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, color: Colors.teal),
            label: 'Profile',
          ),
        ],
        selectedItemColor: Colors.teal.shade700,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UploadReportsScreen()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              // MaterialPageRoute(builder: (context) => PatientProfileScreen(name: "",address: "",contactNumber: "",age: index,gender: '',email: '',bloodGroup: ''))

              MaterialPageRoute(builder: (context) => PatientProfileScreen(
                name: "John Doe", 
                address: "123 Street, City", 
                contactNumber: "+91 9876543210",
                age: 25,
                gender: 'male',
                email: 'abc@gmail.com',
                bloodGroup: 'O+',

              )
              ),
            );
          }
        },
      ),
    );
  }
}


class DoctorDetailsScreen extends StatefulWidget {
  final String doctorName;
  final String specialization;
  final String clinicName;
  final String availability;
  final String contact;
  final String location;
  final String imageUrl;

  DoctorDetailsScreen({
    required this.doctorName,
    required this.specialization,
    required this.clinicName,
    required this.availability,
    required this.contact,
    required this.location,
    required this.imageUrl,
  });

  @override
  _DoctorDetailsScreenState createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  final List<String> timeSlots = [
    "9:00 AM - 9:15 AM",
    "9:15 AM - 9:30 AM",
    "9:30 AM - 9:45 AM",
    "9:45 AM - 10:00 AM",
    "10:00 AM - 10:15 AM",
    "10:15 AM - 10:30 AM",
  ];
  String? selectedTimeSlot;

  Future<void> _saveBookingDetails() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("latest_booking", "Appointment booked for $selectedTimeSlot at ${widget.clinicName} with Dr. ${widget.doctorName}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Doctor Details"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              String? latestBooking = prefs.getString("latest_booking");
              Fluttertoast.showToast(
                msg: latestBooking ?? "No recent bookings",
                toastLength: Toast.LENGTH_LONG,
                gravity: ToastGravity.TOP,
                backgroundColor: Colors.blue,
                textColor: Colors.white,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(widget.imageUrl),
            ),
            SizedBox(height: 20),
            Text(widget.doctorName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(widget.specialization, style: TextStyle(fontSize: 18, color: Colors.grey[700])),
            SizedBox(height: 10),
            Text("${widget.clinicName}\nAvailability: ${widget.availability}\nContact: ${widget.contact}\nLocation: ${widget.location}",
                textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: "Select Time Slot",
                border: OutlineInputBorder(),
              ),
              value: selectedTimeSlot,
              items: timeSlots.map((slot) {
                return DropdownMenuItem(
                  value: slot,
                  child: Text(slot),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedTimeSlot = value;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: selectedTimeSlot == null
                  ? null
                  : () async {
                      await _saveBookingDetails();
                      Fluttertoast.showToast(
                        msg: "Appointment booked successfully for $selectedTimeSlot!",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        backgroundColor: Colors.green,
                        textColor: Colors.white,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              child: Text("Book", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : items.first,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
        items: items.toSet().map((String item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}


