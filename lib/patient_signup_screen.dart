import 'package:flutter/material.dart';
import '../patient_dashboard.dart';
// import 'login_screen.dart';

class PatientSignUpScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Sign Up', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal)),
              SizedBox(height: 20),
              TextField(decoration: InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
              SizedBox(height: 10),
              TextField(decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
              SizedBox(height: 10),
              TextField(decoration: InputDecoration(labelText: 'Password', border: OutlineInputBorder()), obscureText: true),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PatientDashboard()));
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
                child: Text('Sign Up', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
              SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen()));
                },
                child: Text('Already have an account? Login', style: TextStyle(color: Colors.teal)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Login', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal)),
              SizedBox(height: 20),
              TextField(decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
              SizedBox(height: 10),
              TextField(decoration: InputDecoration(labelText: 'Password', border: OutlineInputBorder()), obscureText: true),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PatientDashboard()));
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
                child: Text('Login', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
              SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PatientSignUpScreen()));
                },
                child: Text("Don't have an account? Sign Up", style: TextStyle(color: Colors.teal)),
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
    home: PatientSignUpScreen(),
  ));
}
