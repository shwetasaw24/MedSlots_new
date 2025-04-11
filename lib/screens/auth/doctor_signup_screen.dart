import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import
import '../doctor/doctor_dashboard.dart';
import 'doctor_login.dart';

class DoctorSignUpScreen extends StatefulWidget {
  @override
  _DoctorSignUpScreenState createState() => _DoctorSignUpScreenState();
}

class _DoctorSignUpScreenState extends State<DoctorSignUpScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Add Firestore instance
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController clinicNameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();

  bool isLoading = false;
  String errorMessage = '';

  Future<void> _registerDoctor() async {
    if (emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        fullNameController.text.isEmpty ||
        clinicNameController.text.isEmpty ||
        locationController.text.isEmpty ||
        usernameController.text.isEmpty) {
      setState(() {
        errorMessage = "All fields are required!";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Create user with email and password
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // If user creation is successful, store additional data in Firestore
      if (userCredential.user != null) {
        // Create a doctor profile document in Firestore
        await _firestore.collection('doctors').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': emailController.text.trim(),
          'fullName': fullNameController.text.trim(),
          'clinicName': clinicNameController.text.trim(),
          'location': locationController.text.trim(),
          'username': usernameController.text.trim(),
          'role': 'doctor',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Navigate to doctor dashboard after successful registration
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DoctorDashboard()),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  // Rest of the code remains the same...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal, Colors.lightBlueAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'MedSlots',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Doctor Registration',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildTextField(emailController, 'Email or Phone Number'),
                  _buildTextField(fullNameController, 'Full Name'),
                  _buildTextField(clinicNameController, 'Clinics Name'),
                  _buildTextField(locationController, 'Location'),
                  _buildTextField(usernameController, 'Username'),
                  _buildTextField(passwordController, 'Password', obscureText: true),
                  SizedBox(height: 10),

                  // Display Error Message
                  if (errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        errorMessage,
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),

                  SizedBox(height: 10),

                  // Register Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onPressed: isLoading ? null : _registerDoctor,
                    child: isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Register',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                  
                  SizedBox(height: 15),

                  // Login Navigation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Have an account? ",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => DoctorLoginScreen()),
                          );
                        },
                        child: Text(
                          'Log In',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 10),

                  // Learn More
                  Text(
                    "We need permission for the service you use",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Add Learn More functionality
                    },
                    child: Text(
                      'Learn More',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hintText, {bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}