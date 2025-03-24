import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
export 'package:flutter_medslots/doctor_clinic_details.dart';

class DoctorClinicDetails extends StatefulWidget {
  final String clinicName;
  final String doctorName;
  final String specialty;
  final String availabilityTime;
  final String contactNumber;
  final String location;

  DoctorClinicDetails({
    required this.clinicName,
    required this.doctorName,
    required this.specialty,
    required this.availabilityTime,
    required this.contactNumber,
    required this.location,
  });

  @override
  _DoctorClinicDetailsState createState() => _DoctorClinicDetailsState();
}

class _DoctorClinicDetailsState extends State<DoctorClinicDetails> {
  final List<String> timeSlots = [
    "10:00 AM - 10:30 AM",
    "11:00 AM - 11:30 AM",
    "12:00 PM - 12:30 PM",
    "02:00 PM - 02:30 PM",
    "03:00 PM - 03:30 PM"
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
        title: Text(widget.clinicName,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: AssetImage('assets/doctor_image.png'), // Replace with actual image asset
              ),
            ),
            SizedBox(height: 10),
            Center(
              child: Column(
                children: [
                  Text(widget.doctorName,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                  SizedBox(height: 5),
                  Text(widget.specialty, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                  SizedBox(height: 5),
                  Text(widget.clinicName, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                  SizedBox(height: 5),
                  Text("Availability: ${widget.availabilityTime}", style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                  SizedBox(height: 5),
                  Text("Contact: ${widget.contactNumber}", style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                  SizedBox(height: 5),
                  Text("Location: ${widget.location}", style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text("Select Time Slot:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            DropdownButton<String>(
              hint: Text("Choose a time slot"),
              value: selectedTimeSlot,
              onChanged: (String? newValue) {
                setState(() {
                  selectedTimeSlot = newValue;
                });
              },
              items: timeSlots.map<DropdownMenuItem<String>>((String slot) {
                return DropdownMenuItem<String>(
                  value: slot,
                  child: Text(slot),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
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
                  disabledBackgroundColor: Colors.grey,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text("Book", style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
