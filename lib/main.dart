import 'package:flutter/material.dart';
import 'package:flutter_medslots/doctor_signup_screen.dart';
import 'package:flutter_medslots/patient_signup_screen.dart';

void main() {
  runApp(AppointmentApp());
}

class AppointmentApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedSlots',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: WelcomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      body: Container(
        width: double.infinity, // Full width
        height: double.infinity, // Full height
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal, Colors.lightBlueAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/logo.png', height: screenHeight * 0.15), // Responsive Logo
              SizedBox(height: screenHeight * 0.05),
              
              Text(
                'Welcome to MedSlots',
                style: TextStyle(
                  fontSize: screenWidth * 0.07, 
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: screenHeight * 0.04),

              Column(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.teal,
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.15, 
                        vertical: screenHeight * 0.02,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (context) => DoctorSignUpScreen())),
                    child: Text('Doctor', style: TextStyle(fontSize: screenWidth * 0.05)),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.teal,
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.15, 
                        vertical: screenHeight * 0.02,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (context) => PatientSignUpScreen())),
                    child: Text('Patient', style: TextStyle(fontSize: screenWidth * 0.05)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
