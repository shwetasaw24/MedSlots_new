import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'patient_dashboard.dart';
import 'upload_report.dart';

class PatientProfileScreen extends StatefulWidget {
  // We'll fetch data using the current authenticated user
  // No need to pass email as parameter anymore
  
  @override
  _PatientProfileScreenState createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  // Controllers for editable fields
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _ageController;
  late TextEditingController _contactNumberController;
  late TextEditingController _emailController;
  
  String _selectedGender = '';
  String _selectedBloodGroup = '';
  String _userId = ''; // Store current user ID
  String _userEmail = ''; // Store current user email

  // Appointment details
  String _clinicName = "";
  String _status = "";
  String _timeSlot = "";
  String _date = "";
  bool _isLoading = true; // Start as loading

  final List<String> genderOptions = ['Male', 'Female', 'Other'];
  final List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with empty values first
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _ageController = TextEditingController();
    _contactNumberController = TextEditingController();
    _emailController = TextEditingController();
    
    // Initialize with default values to prevent dropdown errors
    _selectedGender = genderOptions[0];
    _selectedBloodGroup = bloodGroups[0];

    // Get current user and fetch data
    getCurrentUser();
  }

  // Get current authenticated user
  Future<void> getCurrentUser() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser != null) {
      setState(() {
        _userId = currentUser.uid;
        _userEmail = currentUser.email ?? '';
        _emailController.text = _userEmail;
      });
      
      // Now that we have the user ID, fetch the profile data
      await fetchUserData();
      await fetchAppointmentDetails();
    } else {
      // User not logged in, handle this case (e.g., navigate to login)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not authenticated. Please login again.'))
      );
      // Navigate back to login screen
      // You can add navigation code here
    }
  }

  // Fetch user data from Firestore
  Future<void> fetchUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // First try to fetch from 'patients' collection (as used in registration)
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(_userId)
          .get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        
        setState(() {
          // Update text controllers with data from registration
          _nameController.text = userData['fullName'] ?? '';
          _contactNumberController.text = userData['contactNumber'] ?? '';
          
          // These fields may not exist in a new user profile
          _addressController.text = userData['address'] ?? '';
          _ageController.text = (userData['age'] ?? '').toString();
          
          // Make sure gender exists in our options
          String fetchedGender = userData['gender'] ?? '';
          _selectedGender = genderOptions.contains(fetchedGender) ? fetchedGender : genderOptions[0];
          
          // Make sure blood group exists in our options
          String fetchedBloodGroup = userData['bloodGroup'] ?? '';
          _selectedBloodGroup = bloodGroups.contains(fetchedBloodGroup) ? fetchedBloodGroup : bloodGroups[0];
        });
      } else {
        // If not found in 'patients', try the 'Patient' collection
        // This is a fallback for existing users who might have data in the old path
        userDoc = await FirebaseFirestore.instance
            .collection('Patient')
            .doc(_userEmail)
            .get();
            
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          
          setState(() {
            _nameController.text = userData['name'] ?? '';
            _addressController.text = userData['address'] ?? '';
            _ageController.text = (userData['age'] ?? '').toString();
            _contactNumberController.text = userData['contactNumber'] ?? '';
            
            String fetchedGender = userData['gender'] ?? '';
            _selectedGender = genderOptions.contains(fetchedGender) ? fetchedGender : genderOptions[0];
            
            String fetchedBloodGroup = userData['bloodGroup'] ?? '';
            _selectedBloodGroup = bloodGroups.contains(fetchedBloodGroup) ? fetchedBloodGroup : bloodGroups[0];
          });
        } else {
          print("User document does not exist in Firestore");
          // Create empty profile for new users
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('New profile created. Please add your details.'))
          );
        }
      }
    } catch (e) {
      print("Error fetching user data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile data. Please try again.'))
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> fetchAppointmentDetails() async {
    try {
      // First try 'patients' collection path (new structure)
      QuerySnapshot appointmentQuery = await FirebaseFirestore.instance
          .collection('patients')
          .doc(_userId)
          .collection('appointments')
          .where('status', isNotEqualTo: 'cancelled')
          .orderBy('status')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (appointmentQuery.docs.isNotEmpty) {
        var appointmentData = appointmentQuery.docs.first.data() as Map<String, dynamic>;
        
        setState(() {
          _clinicName = appointmentData['clinicName'] ?? "";
          _status = appointmentData['status'] ?? "";
          _timeSlot = appointmentData['timeSlot'] ?? "";
          _date = appointmentData['date'] ?? _formatDate(appointmentData['appointmentDate']);
        });
      } else {
        // Try the old path structure with email as ID
        DocumentSnapshot appointmentDoc = await FirebaseFirestore.instance
            .collection('Patient')
            .doc(_userEmail)
            .collection('Bookings')
            .doc('Appointment')
            .get();
            
        if (appointmentDoc.exists) {
          var appointmentData = appointmentDoc.data() as Map<String, dynamic>;
          
          setState(() {
            _clinicName = appointmentData['ClinicsName'] ?? "";
            _status = appointmentData['Status'] ?? "";
            _timeSlot = appointmentData['TimeSlot'] ?? "";
            _date = appointmentData['date'] ?? "";
          });
        } else {
          // Try one more structure variation
          QuerySnapshot oldAppointmentQuery = await FirebaseFirestore.instance
              .collection('Patient')
              .doc(_userEmail)
              .collection('Bookings')
              .where('status', isEqualTo: true)
              .orderBy('Date', descending: true)
              .limit(1)
              .get();

          if (oldAppointmentQuery.docs.isNotEmpty) {
            var appointmentData = oldAppointmentQuery.docs.first.data() as Map<String, dynamic>;
            
            setState(() {
              _clinicName = appointmentData['Clinics Name'] ?? appointmentData['ClinicsName'] ?? "";
              _status = appointmentData['Status'] ?? (appointmentData['status'] == true ? "Confirmed" : "Pending");
              _timeSlot = appointmentData['TimeSlot'] ?? appointmentData['Booking Time'] ?? "";
              _date = appointmentData['date'] ?? _formatTimestamp(appointmentData['Date']) ?? "";
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching appointment: $e");
    }
  }
  
  // Helper method to format Timestamp
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "";
    if (timestamp is Timestamp) {
      DateTime dateTime = timestamp.toDate();
      return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    }
    return timestamp.toString();
  }
  
  // Helper method to format DateTime
  String _formatDate(dynamic date) {
    if (date == null) return "";
    if (date is DateTime) {
      return "${date.day}/${date.month}/${date.year}";
    } else if (date is Timestamp) {
      DateTime dateTime = date.toDate();
      return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    }
    return date.toString();
  }

  Future<void> saveChanges() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Prepare the data to update
      Map<String, dynamic> updateData = {
        'fullName': _nameController.text,
        'name': _nameController.text, // Add both keys for compatibility
        'address': _addressController.text,
        'age': int.tryParse(_ageController.text) ?? 0,
        'gender': _selectedGender,
        'bloodGroup': _selectedBloodGroup,
        'contactNumber': _contactNumberController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Update in both possible locations for compatibility
      // 1. Update in 'patients' collection with UID as document ID
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(_userId)
          .set(updateData, SetOptions(merge: true));
      
      // 2. Update in 'Patient' collection with email as document ID for backwards compatibility
      await FirebaseFirestore.instance
          .collection('Patient')
          .doc(_userEmail)
          .set(updateData, SetOptions(merge: true));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully!'))
      );
    } catch (e) {
      print("Error updating profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e'))
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: Colors.teal))
        : Container(
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
                      backgroundColor: Colors.teal.withOpacity(0.7),
                      child: Icon(Icons.person, size: 60, color: Colors.white),
                    ),
                  ),
                  SizedBox(height: 30),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: 15),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: 15),
                  TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Age',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: 15),
                  // Fixed dropdown for gender
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    items: genderOptions.map((gender) {
                      return DropdownMenuItem(
                        value: gender,
                        child: Text(gender),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedGender = value;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: 15),
                  // Fixed dropdown for blood group
                  DropdownButtonFormField<String>(
                    value: _selectedBloodGroup,
                    items: bloodGroups.map((bg) {
                      return DropdownMenuItem(
                        value: bg,
                        child: Text(bg),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedBloodGroup = value;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Blood Group',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: 15),
                  TextField(
                    controller: _contactNumberController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Contact Number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: 15),
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email Address:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.email, color: Colors.teal),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _userEmail,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // Displaying the Booked Appointment
                  if (_clinicName.isNotEmpty) Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booked Appointment:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      SizedBox(height: 10),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Clinic Name: $_clinicName', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                            SizedBox(height: 5),
                            Text('Status: $_status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                            SizedBox(height: 5),
                            Text('Time Slot: $_timeSlot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                            SizedBox(height: 5),
                            Text('Date: $_date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 30),
                  Center(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading 
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text('Save Changes', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.file_copy), label: 'Upload Records'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => PatientDashboard()));
          } else if (index == 1) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => UploadReportsScreen()));
          }
          // No need to navigate if index is 2 (current page)
        },
      ),
    );
  }
  
  @override
  void dispose() {
    // Dispose controllers to prevent memory leaks
    _nameController.dispose();
    _addressController.dispose();
    _ageController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}