import 'package:flutter/material.dart';
import 'package:flutter_medslots/doctor_signup_screen.dart';
import 'package:flutter_medslots/patient_signup_screen.dart'; // ✅ Correct Import

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal, Colors.lightBlueAccent], // Matching gradient
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'MedSlots', // ✅ Only the app name
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 10),
            Text(
              'Choose your category', // ✅ Subtitle added
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            SizedBox(height: 40),

            // Doctor Signup Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // ✅ Blue color to match the design
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 80, vertical: 15), // ✅ Wider buttons
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (context) => DoctorSignUpScreen())),
              child: Text('Doctor', style: TextStyle(fontSize: 20)),
            ),
            SizedBox(height: 20),

            // Patient Signup Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // ✅ Blue color to match the design
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 80, vertical: 15), // ✅ Wider buttons
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (context) => PatientSignUpScreen())), // ✅ Fixed
              child: Text('Patient', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}
