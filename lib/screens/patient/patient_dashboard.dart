import 'package:flutter/material.dart';
import 'package:flutter_medslots/screens/patient/upload_report.dart';
import 'package:flutter_medslots/services/firestorestore_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'patient_profile_screen.dart';
import '..//patient/doctor_clinic_details.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '..//patient/AppointmentHistoryScreen.dart';
// Add these imports at the top of your files
import 'package:intl/intl.dart';  // For date formatting

class PatientDashboard extends StatefulWidget {
  final String? patientProfileImage;
  final String? patientEmail;

  PatientDashboard({this.patientProfileImage, this.patientEmail});

  @override
  _PatientDashboardState createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  final FirebaseServices _firebaseServices = FirebaseServices();
  List<Map<String, dynamic>> doctors = [];
  List<Map<String, dynamic>> filteredDoctors = []; // For search results
  String searchQuery = ""; // To store search query
  String patientName = "Patient";
  String patientAddress = "";
  String patientAge = "";
  String patientGender = "";
  String patientBloodGroup = "";
  String patientContactNumber = "";
  String patientEmail = "";
  String userId = "";
  bool isLoading = true;
  int recentAppointmentsCount = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  // Get current authenticated user and then load data
  Future<void> _getCurrentUser() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser != null) {
      setState(() {
        userId = currentUser.uid;
        patientEmail = currentUser.email ?? widget.patientEmail ?? '';
      });
      
      await _loadData();
      // Check for recent appointments
      await _checkRecentAppointments();
    } else {
      // User not logged in, try using the email passed to widget
      if (widget.patientEmail != null) {
        setState(() {
          patientEmail = widget.patientEmail!;
        });
        await _loadData();
        // Check for recent appointments
        await _checkRecentAppointments();
      } else {
        setState(() {
          isLoading = false;
        });
        
        Fluttertoast.showToast(
          msg: "User not authenticated. Please login again.",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  // Method to check recent appointments for notification badge
  Future<void> _checkRecentAppointments() async {
    try {
      if (patientEmail.isEmpty) return;
      
      // Calculate date 2 days ago
      DateTime twoDaysAgo = DateTime.now().subtract(Duration(days: 2));
      
      // Query Firestore for recent appointments
      QuerySnapshot appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientEmail', isEqualTo: patientEmail)
          .where('bookingDate', isGreaterThanOrEqualTo: Timestamp.fromDate(twoDaysAgo))
          .get();
      
      setState(() {
        recentAppointmentsCount = appointmentsSnapshot.docs.length;
      });
    } catch (e) {
      print('Error checking recent appointments: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      // First fetch patient profile data using the same approach as profile screen
      await _fetchPatientData();
      
      // Then fetch doctors list
      await _fetchDoctors();
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        isLoading = false;
      });
      
      Fluttertoast.showToast(
        msg: "Failed to load data. Please try again.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }
  
  // Fetch patient data the same way as in the profile screen
  Future<void> _fetchPatientData() async {
    try {
      if (userId.isNotEmpty) {
        // First try to fetch from 'patients' collection with userId
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('patients')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          
          setState(() {
            patientName = userData['fullName'] ?? userData['name'] ?? "Patient";
            patientAddress = userData['address'] ?? "";
            patientAge = (userData['age'] ?? '').toString();
            patientGender = userData['gender'] ?? "";
            patientBloodGroup = userData['bloodGroup'] ?? "";
            patientContactNumber = userData['contactNumber'] ?? "";
          });
          return;
        }
      }
      
      // If userId fetch fails or userId is empty, try with email from 'Patient' collection
      if (patientEmail.isNotEmpty) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('Patient')
            .doc(patientEmail)
            .get();
            
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          
          setState(() {
            patientName = userData['name'] ?? userData['fullName'] ?? "Patient";
            patientAddress = userData['address'] ?? "";
            patientAge = (userData['age'] ?? '').toString();
            patientGender = userData['gender'] ?? "";
            patientBloodGroup = userData['bloodGroup'] ?? "";
            patientContactNumber = userData['contactNumber'] ?? "";
          });
          return;
        }
      }
      
      // If both approaches fail, try using the service method as fallback
      if (patientEmail.isNotEmpty) {
        Map<String, dynamic>? patientData = 
            await _firebaseServices.getPatientProfile(patientEmail);
        if (patientData != null) {
          setState(() {
            patientName = patientData['name'] ?? patientData['fullName'] ?? "Patient";
            patientAddress = patientData['address'] ?? "";
            patientAge = (patientData['age'] ?? '').toString();
            patientGender = patientData['gender'] ?? "";
            patientBloodGroup = patientData['bloodGroup'] ?? "";
            patientContactNumber = patientData['contactNumber'] ?? "";
          });
        }
      }
    } catch (e) {
      print("Error fetching patient data: $e");
    }
  }
  
  // Fetch doctors list (unchanged)
  Future<void> _fetchDoctors() async {
    try {
      // Fetch doctors from Firestore
      QuerySnapshot doctorsSnapshot = 
          await FirebaseFirestore.instance.collection('doctors').get();
      
      List<Map<String, dynamic>> doctorsList = [];
      
      for (var doc in doctorsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // Debug print to see the raw data
        print("Doctor data: ${doc.id} - ${data.toString()}");
        
        // Safely extract data with fallbacks
        doctorsList.add({
          'id': doc.id,
          'name': _getValueOrDefault(data, ['fullName', 'name'], 'Unknown Doctor'),
          'email': _getValueOrDefault(data, ['email'], ''),
          'specialty': _getValueOrDefault(data, ['qualification', 'specialty'], 'General'),
          'clinicName': _getValueOrDefault(data, ['clinicName'], 'Not specified'),
          'availabilityTime': _getValueOrDefault(data, ['currentAvailability', 'Current Availaibility'], 'Not specified'),
          'tomorrowAvailability': _getValueOrDefault(data, ['tommorowsAvailability', 'Tommorows Availaibility'], 'Not specified'),
          'dayAfterAvailability': _getValueOrDefault(data, ['Day After Tommorows Availaibility'], 'Not specified'),
          'contactNumber': _getValueOrDefault(data, ['phone', 'contactNumber'], 'Not available'),
          'location': _getValueOrDefault(data, ['location'], 'Not specified'),
          'imageUrl': _getValueOrDefault(data, ['profileImage'], 'assets/default_doctor.png'),
          'bookingEnabled': _getBoolValueOrDefault(data, ['booking_enabled'], true),
          'role': _getValueOrDefault(data, ['role'], '')
        });
      }
      
      setState(() {
        doctors = doctorsList;
        filteredDoctors = doctorsList; // Initialize filtered list with all doctors
        isLoading = false;
      });
      
      // If no doctors found in database, use default data
      if (doctors.isEmpty) {
        setState(() {
          doctors = [
            {
              'name': 'Dr. Diksha Gidwani',
              'specialty': 'Physiotherapist',
              'clinicName': 'Healing Hands Clinic',
              'availabilityTime': 'Mon-Fri, 10AM - 5PM',
              'contactNumber': '+91 9876543210',
              'location': 'Mumbai, India',
              'imageUrl': 'assets/doctor1.png',
              'bookingEnabled': true
            },
            // Other default doctors...
          ];
          filteredDoctors = doctors; // Also update filtered list
        });
      }
    } catch (e) {
      print('Error fetching doctors: $e');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  // Helper method to safely get values from a map with fallbacks
  String _getValueOrDefault(Map<String, dynamic> data, List<String> possibleKeys, String defaultValue) {
    for (String key in possibleKeys) {
      if (data.containsKey(key) && data[key] != null && data[key].toString().isNotEmpty) {
        return data[key].toString();
      }
    }
    return defaultValue;
  }
  
  // Helper method to safely get boolean values
  bool _getBoolValueOrDefault(Map<String, dynamic> data, List<String> possibleKeys, bool defaultValue) {
    for (String key in possibleKeys) {
      if (data.containsKey(key) && data[key] != null) {
        // Handle various formats of boolean values
        if (data[key] is bool) {
          return data[key];
        } else if (data[key].toString().toLowerCase() == 'true') {
          return true;
        } else if (data[key].toString().toLowerCase() == 'false') {
          return false;
        }
      }
    }
    return defaultValue;
  }
  
  // Search functionality
  void _filterDoctors(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        // If search query is empty, show all doctors
        filteredDoctors = doctors;
      } else {
        // Convert query to lowercase for case-insensitive search
        String lowercaseQuery = query.toLowerCase();
        
        // Filter doctors based on name, specialty, or location
        filteredDoctors = doctors.where((doctor) {
          String name = doctor['name']?.toString().toLowerCase() ?? '';
          String specialty = doctor['specialty']?.toString().toLowerCase() ?? '';
          String location = doctor['location']?.toString().toLowerCase() ?? '';
          String clinicName = doctor['clinicName']?.toString().toLowerCase() ?? '';
          
          // Return true if query appears in any of these fields
          return name.contains(lowercaseQuery) || 
                specialty.contains(lowercaseQuery) || 
                location.contains(lowercaseQuery) ||
                clinicName.contains(lowercaseQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MedSlots', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: Icon(Icons.notifications, color: Colors.white),
                onPressed: () {
                  // Navigate to AppointmentHistoryScreen to view recent appointments
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AppointmentHistoryScreen(
                        patientEmail: patientEmail,
                        recentOnly: true,
                      ),
                    ),
                  ).then((_) {
                    // Refresh notification count when returning from the screen
                    _checkRecentAppointments();
                  });
                },
              ),
              if (recentAppointmentsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$recentAppointmentsCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade100, Colors.teal.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: widget.patientProfileImage != null
                          ? AssetImage(widget.patientProfileImage!)
                          : AssetImage('assets/default_profile.png'),
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome, $patientName!',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        if (patientBloodGroup.isNotEmpty)
                          Text('Blood Group: $patientBloodGroup',
                              style: TextStyle(fontSize: 14, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
                
                // Show additional patient info in a collapsible widget
                ExpansionTile(
                  title: Text('View Patient Details', 
                      style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                  collapsedIconColor: Colors.white,
                  iconColor: Colors.white,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          if (patientGender.isNotEmpty)
                            _buildDetailRow('Gender', patientGender),
                          if (patientAge.isNotEmpty)
                            _buildDetailRow('Age', patientAge),
                          if (patientContactNumber.isNotEmpty)
                            _buildDetailRow('Contact', patientContactNumber),
                          if (patientAddress.isNotEmpty)
                            _buildDetailRow('Address', patientAddress),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Search bar - Updated with filter functionality
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search doctors by name, specialty, or location...',
                prefixIcon: Icon(Icons.search, color: Colors.teal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.teal),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.teal, width: 2),
                ),
                suffixIcon: searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        // Clear search
                        _filterDoctors('');
                        FocusScope.of(context).unfocus();
                      },
                    )
                  : null,
              ),
              onChanged: _filterDoctors,
            ),
          ),
          
          // Section title
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  filteredDoctors.length != doctors.length 
                    ? 'Found ${filteredDoctors.length} doctors'
                    : 'Available Doctors',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.teal.shade800
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _loadData();
                    _checkRecentAppointments();
                    // Clear search when refreshing
                    _filterDoctors('');
                  },
                  child: Text('Refresh', style: TextStyle(color: Colors.teal)),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: isLoading 
            ? Center(child: CircularProgressIndicator(color: Colors.teal))
            : filteredDoctors.isEmpty 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      searchQuery.isEmpty 
                        ? 'No doctors available' 
                        : 'No doctors found matching "$searchQuery"',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                    ),
                    if (searchQuery.isNotEmpty)
                      TextButton(
                        onPressed: () => _filterDoctors(''),
                        child: Text('Clear Search', style: TextStyle(color: Colors.teal)),
                      )
                  ],
                ),
              )
            : ListView.builder(
              itemCount: filteredDoctors.length,
              itemBuilder: (context, index) {
                final doctor = filteredDoctors[index];
                final bool isBookingEnabled = doctor['bookingEnabled'] ?? true;

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 3,
                  shadowColor: Colors.teal.shade100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(12),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundImage: doctor['imageUrl'].startsWith('assets/')
                          ? AssetImage(doctor['imageUrl'])
                          : NetworkImage(doctor['imageUrl']) as ImageProvider,
                      backgroundColor: Colors.teal.shade50,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            doctor['name']!,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                          ),
                        ),
                        if (isBookingEnabled)
                          Icon(Icons.event_available, color: Colors.green, size: 16)
                        else
                          Icon(Icons.event_busy, color: Colors.red, size: 16),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${doctor['specialty']}'),
                        Text('${doctor['clinicName']} - ${doctor['location']}', 
                             style: TextStyle(fontSize: 12)),
                        Text('Today: ${doctor['availabilityTime']}',
                             style: TextStyle(fontSize: 12, color: Colors.blue.shade800)),
                      ],
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, color: Colors.teal),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DoctorDetailsScreen(
                            doctorName: doctor['name']!,
                            specialization: doctor['specialty']!,
                            clinicName: doctor['clinicName']!,
                            availability: doctor['availabilityTime']!,
                            contact: doctor['contactNumber']!,
                            location: doctor['location']!,
                            imageUrl: doctor['imageUrl']!,
                            patientEmail: patientEmail,
                            // Add new fields
                            tomorrowAvailability: doctor['tomorrowAvailability'] ?? 'Not specified',
                            dayAfterAvailability: doctor['dayAfterAvailability'] ?? 'Not specified',
                            bookingEnabled: doctor['bookingEnabled'] ?? true,
                            doctorEmail: doctor['email'] ?? '',
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            )
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard, color: Colors.teal),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload_file, color: Colors.teal),
            label: 'Upload Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, color: Colors.teal),
            label: 'Profile',
          ),
        ],
        selectedItemColor: Colors.teal.shade700,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UploadReportsScreen()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PatientProfileScreen(),
              ),
            );
          }
        },
      ),
    );
  }
  
  // Helper widget to display patient details
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', 
              style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value, 
                style: TextStyle(fontSize: 14, color: Colors.white),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}