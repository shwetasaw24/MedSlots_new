import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/firebase_options.dart';
import '../screens/auth/doctor_signup_screen.dart';
import 'screens/auth/patient_signup_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
        width: double.infinity,
        height: double.infinity,
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
              Image.asset('assets/logo.png', height: screenHeight * 0.15),
              SizedBox(height: screenHeight * 0.05),
              Text(
                'MedSlots',
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
                    style: _buttonStyle(screenWidth, screenHeight),
                    onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (context) => DoctorSignUpScreen())),
                    child: Text('Doctor', style: TextStyle(fontSize: screenWidth * 0.05)),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  ElevatedButton(
                    style: _buttonStyle(screenWidth, screenHeight),
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

  ButtonStyle _buttonStyle(double screenWidth, double screenHeight) {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.teal,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.15,
        vertical: screenHeight * 0.02,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
