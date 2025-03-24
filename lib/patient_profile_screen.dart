import 'package:flutter/material.dart';
import '../../patient_dashboard.dart';
import '../../upload_report.dart';

class PatientProfileScreen extends StatefulWidget {
  final String name;
  final String address;
  final String contactNumber;
  final String email;
  final int age;
  final String gender;
  final String bloodGroup;

  PatientProfileScreen({
    required this.name,
    required this.address,
    required this.contactNumber,
    required this.email,
    required this.age,
    required this.gender,
    required this.bloodGroup,
  });

  @override
  _PatientProfileScreenState createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _ageController;
  String _selectedGender = '';
  String _selectedBloodGroup = '';

  final List<String> genderOptions = ['Male', 'Female', 'Other'];
  final List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _addressController = TextEditingController(text: widget.address);
    _ageController = TextEditingController(text: widget.age.toString());
    _selectedGender = widget.gender;
    _selectedBloodGroup = widget.bloodGroup;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade100, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade300,
                  child: Icon(Icons.person, size: 60, color: Colors.white),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              SizedBox(height: 15),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(labelText: 'Address'),
              ),
              SizedBox(height: 15),
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Age'),
              ),
              SizedBox(height: 15),
              DropdownButtonFormField(
                value: _selectedGender,
                items: genderOptions.map((gender) {
                  return DropdownMenuItem(
                    value: gender,
                    child: Text(gender),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value.toString();
                  });
                },
                decoration: InputDecoration(labelText: 'Gender'),
              ),
              SizedBox(height: 15),
              DropdownButtonFormField(
                value: _selectedBloodGroup,
                items: bloodGroups.map((bg) {
                  return DropdownMenuItem(
                    value: bg,
                    child: Text(bg),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBloodGroup = value.toString();
                  });
                },
                decoration: InputDecoration(labelText: 'Blood Group'),
              ),
              SizedBox(height: 15),
              Text(
                'Contact No: ${widget.contactNumber}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              SizedBox(height: 10),
              Text(
                'Email: ${widget.email}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      // Save updated values
                    });
                  },
                  child: Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.file_copy), label: 'Upload Records'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.teal,
        onTap: (index) {
          if (index == 0) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => PatientDashboard()));
          } else if (index == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => UploadReportsScreen()));
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PatientProfileScreen(
                  name: widget.name,
                  address: widget.address,
                  contactNumber: widget.contactNumber,
                  email: widget.email,
                  age: widget.age,
                  gender: widget.gender,
                  bloodGroup: widget.bloodGroup,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
