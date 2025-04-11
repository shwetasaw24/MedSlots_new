import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import
import '../patient/patient_dashboard.dart';

class PatientSignUpScreen extends StatefulWidget {
  @override
  _PatientSignUpScreenState createState() => _PatientSignUpScreenState();
}

class _PatientSignUpScreenState extends State<PatientSignUpScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance; // Add Firestore instance
  final _formKey = GlobalKey<FormState>();
  
  String fullName = '';
  String email = '';
  String password = '';
  String contactNumber = '';
  bool isLoading = false;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => isLoading = true);
    
    try {
      // Create the user account
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      // Store additional user data in Firestore
      await _firestore.collection('patients').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'fullName': fullName,
        'email': email,
        'contactNumber': contactNumber,
        'role': 'patient',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Patient Account Created Successfully!'))
      );

      // Navigate to Patient Dashboard
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => PatientDashboard())
      );
    
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred. Please try again.';
      if (e.code == 'weak-password') {
        message = 'Password should be at least 6 characters.';
      } else if (e.code == 'email-already-in-use') {
        message = 'This email is already in use.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      setState(() => isLoading = false);
    }
  }

  // The rest of the widget code remains the same
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Patient Registration'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Patient Icon and Title
                  Icon(Icons.personal_injury, size: 70, color: Colors.teal),
                  Text(
                    'PATIENT SIGN UP',
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.teal
                    ),
                  ),
                  Text(
                    'Create your patient account',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 30),

                  // Patient role indicator
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.health_and_safety, color: Colors.teal),
                        SizedBox(width: 8),
                        Text(
                          'Registering as Patient',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 30),

                  // Full Name Input
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person, color: Colors.teal),
                    ),
                    onChanged: (value) => fullName = value,
                    validator: (value) => value!.isEmpty ? 'Enter your full name' : null,
                  ),
                  SizedBox(height: 15),

                  // Contact Number Input
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Contact Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone, color: Colors.teal),
                    ),
                    keyboardType: TextInputType.phone,
                    onChanged: (value) => contactNumber = value,
                    validator: (value) => value!.length < 10 ? 'Enter a valid contact number' : null,
                  ),
                  SizedBox(height: 15),

                  // Email Input
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email, color: Colors.teal),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) => email = value,
                    validator: (value) => value!.isEmpty || !value.contains('@') ? 'Enter a valid email' : null,
                  ),
                  SizedBox(height: 15),

                  // Password Input
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock, color: Colors.teal),
                    ),
                    obscureText: true,
                    onChanged: (value) => password = value,
                    validator: (value) => value!.length < 6 ? 'Password must be at least 6 characters' : null,
                  ),
                  SizedBox(height: 30),

                  // Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: isLoading 
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('REGISTER AS PATIENT', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Login Redirect
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have a patient account?'),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => PatientLoginScreen()),
                          );
                        },
                        child: Text('Login', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PatientLoginScreen extends StatefulWidget {
  @override
  _PatientLoginScreenState createState() => _PatientLoginScreenState();
}

class _PatientLoginScreenState extends State<PatientLoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance; // Add Firestore instance
  final _formKey = GlobalKey<FormState>();

  String email = '';
  String password = '';
  bool isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      // Attempt to sign in
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      // Check if user exists in the patients collection
      DocumentSnapshot patientDoc = await _firestore
          .collection('patients')
          .doc(userCredential.user!.uid)
          .get();
      
      if (patientDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Patient Login Successful!'))
        );
        
        // Navigate to Patient Dashboard
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => PatientDashboard())
        );
      } else {
        // User is not a patient
        await _auth.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No patient account found with these credentials.'))
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred. Please try again.';
      if (e.code == 'user-not-found') {
        message = 'No patient account found with this email.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      setState(() => isLoading = false);
    }
  }

  // The rest of the widget code remains the same...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Patient Login'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Patient Icon and Title
                  Icon(Icons.personal_injury, size: 70, color: Colors.teal),
                  Text(
                    'PATIENT LOGIN',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  Text(
                    'Access your patient account',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 30),

                  // Patient role indicator
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.health_and_safety, color: Colors.teal),
                        SizedBox(width: 8),
                        Text(
                          'Logging in as Patient',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 30),

                  // Email Input
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Patient Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email, color: Colors.teal),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) => email = value,
                    validator: (value) => value!.isEmpty || !value.contains('@') ? 'Enter a valid email' : null,
                  ),
                  SizedBox(height: 15),

                  // Password Input
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock, color: Colors.teal),
                    ),
                    obscureText: true,
                    onChanged: (value) => password = value,
                    validator: (value) => value!.length < 6 ? 'Password must be at least 6 characters' : null,
                  ),
                  SizedBox(height: 30),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text('LOGIN AS PATIENT', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Sign Up Redirect
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Don\'t have a patient account?'),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PatientSignUpScreen()),
                          );
                        },
                        child: Text('Sign Up', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}