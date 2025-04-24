import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'patient_dashboard.dart';
import 'upload_report.dart';

class PatientProfileScreen extends StatefulWidget {
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
  String _userId = ''; 
  String _userEmail = '';

  // Appointment details
  String _clinicName = "";
  String _status = "";
  String _timeSlot = "";
  String _date = "";
  bool _isLoading = true;
  bool _isEditMode = false; // Flag to control edit/view mode

  // Store original values to detect changes
  Map<String, dynamic> _originalValues = {};
  
  final List<String> genderOptions = ['Male', 'Female', 'Other'];
  final List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _ageController = TextEditingController();
    _contactNumberController = TextEditingController();
    _emailController = TextEditingController();
    
    // Initialize with default values
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
      
      await fetchUserData();
      await fetchAppointmentDetails();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not authenticated. Please login again.'))
      );
    }
  }

  // Fetch user data from Firestore
  Future<void> fetchUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // First try to fetch from 'patients' collection
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(_userId)
          .get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        
        setState(() {
          _nameController.text = userData['fullName'] ?? '';
          _contactNumberController.text = userData['contactNumber'] ?? '';
          _addressController.text = userData['address'] ?? '';
          _ageController.text = (userData['age'] ?? '').toString();
          
          String fetchedGender = userData['gender'] ?? '';
          _selectedGender = genderOptions.contains(fetchedGender) ? fetchedGender : genderOptions[0];
          
          String fetchedBloodGroup = userData['bloodGroup'] ?? '';
          _selectedBloodGroup = bloodGroups.contains(fetchedBloodGroup) ? fetchedBloodGroup : bloodGroups[0];
          
          // Store original values
          _storeOriginalValues();
        });
      } else {
        // If not found, try the 'Patient' collection
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
            
            // Store original values
            _storeOriginalValues();
          });
        } else {
          print("User document does not exist in Firestore");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('New profile created. Please add your details.'))
          );
          setState(() {
            _isEditMode = true; // Auto-enable edit mode for new users
          });
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

  // Store original values to detect changes
  void _storeOriginalValues() {
    _originalValues = {
      'name': _nameController.text,
      'address': _addressController.text,
      'age': _ageController.text,
      'contactNumber': _contactNumberController.text,
      'gender': _selectedGender,
      'bloodGroup': _selectedBloodGroup,
    };
  }

  Future<void> fetchAppointmentDetails() async {
    try {
      // First try 'patients' collection path
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
        // Try the old path structure
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
  
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "";
    if (timestamp is Timestamp) {
      DateTime dateTime = timestamp.toDate();
      return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    }
    return timestamp.toString();
  }
  
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
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(_userId)
          .set(updateData, SetOptions(merge: true));
      
      await FirebaseFirestore.instance
          .collection('Patient')
          .doc(_userEmail)
          .set(updateData, SetOptions(merge: true));
      
      // Update original values after successful save
      _storeOriginalValues();
      
      setState(() {
        _isEditMode = false; // Exit edit mode after saving
      });
      
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

  // Method to cancel editing and revert changes
  void _cancelEditing() {
    setState(() {
      // Restore original values
      _nameController.text = _originalValues['name'] ?? '';
      _addressController.text = _originalValues['address'] ?? '';
      _ageController.text = _originalValues['age'] ?? '';
      _contactNumberController.text = _originalValues['contactNumber'] ?? '';
      _selectedGender = _originalValues['gender'] ?? genderOptions[0];
      _selectedBloodGroup = _originalValues['bloodGroup'] ?? bloodGroups[0];
      
      _isEditMode = false; // Exit edit mode
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (!_isLoading && !_isEditMode)
            IconButton(
              icon: Icon(Icons.edit, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isEditMode = true;
                });
              },
              tooltip: 'Edit Profile',
            ),
        ],
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
                  
                  // Profile information section
                  _buildProfileInformation(),
                  
                  // Displaying the Booked Appointment
                  if (_clinicName.isNotEmpty) ...[
                    SizedBox(height: 25),
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

                  SizedBox(height: 30),
                  
                  // Button section - Only show in edit mode
                  if (_isEditMode)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _isLoading ? null : _cancelEditing,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text('Cancel', style: TextStyle(fontSize: 16)),
                        ),
                        ElevatedButton(
                          onPressed: _isLoading ? null : saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading 
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text('Save Changes', style: TextStyle(fontSize: 16)),
                        ),
                      ],
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
        },
      ),
    );
  }
  
  // Build profile information section based on view/edit mode
  Widget _buildProfileInformation() {
    if (_isEditMode) {
      // Edit mode - show editable fields
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                SizedBox(height: 5),
                Text(
                  'Email cannot be changed',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // View mode - show non-editable profile info
      return Container(
        padding: EdgeInsets.all(15),
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
            Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            Divider(color: Colors.teal.shade200, thickness: 1),
            SizedBox(height: 10),
            
            _buildProfileItem('Full Name', _nameController.text, Icons.person),
            _buildProfileItem('Address', _addressController.text, Icons.home),
            _buildProfileItem('Age', _ageController.text, Icons.calendar_today),
            _buildProfileItem('Gender', _selectedGender, Icons.people),
            _buildProfileItem('Blood Group', _selectedBloodGroup, Icons.bloodtype),
            _buildProfileItem('Contact Number', _contactNumberController.text, Icons.phone),
            _buildProfileItem('Email', _userEmail, Icons.email),
          ],
        ),
      );
    }
  }
  
  // Helper widget to display profile item in view mode
  Widget _buildProfileItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.teal),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Not set' : value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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