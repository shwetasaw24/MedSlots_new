import 'package:flutter/material.dart';
import 'package:flutter_medslots/screens/patient/upload_report.dart';
import 'package:flutter_medslots/services/firestorestore_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'patient_profile_screen.dart';
import '..//patient/doctor_clinic_details.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

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
  String patientName = "Patient";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      // Fetch patient profile if email is available
      if (widget.patientEmail != null) {
        Map<String, dynamic>? patientData = 
            await _firebaseServices.getPatientProfile(widget.patientEmail!);
        if (patientData != null && patientData.containsKey('name')) {
          setState(() {
            patientName = patientData['name'];
          });
        }
      }
      
      // Fetch doctors from Firestore
      QuerySnapshot doctorsSnapshot = 
          await FirebaseFirestore.instance.collection('doctors').get();
      
      List<Map<String, dynamic>> doctorsList = [];
      
      for (var doc in doctorsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // Fetch associated clinic data if available
        String clinicName = "Not specified";
        String clinicLocation = "Not specified";
        
        if (data.containsKey('clinicId') && data['clinicId'] != null) {
          try {
            DocumentSnapshot clinicDoc = await FirebaseFirestore.instance
                .collection('Clinics')
                .doc(data['clinicId'])
                .get();
                
            if (clinicDoc.exists) {
              Map<String, dynamic> clinicData = clinicDoc.data() as Map<String, dynamic>;
              clinicName = clinicData['name'] ?? "Not specified";
              clinicLocation = clinicData['location'] ?? "Not specified";
            }
          } catch (e) {
            print('Error fetching clinic: $e');
          }
        }
        
        doctorsList.add({
          'id': doc.id,
          'name': data['fullName'] ?? data['name'] ?? 'Unknown Doctor',
          'specialty': data['specialty'] ?? 'General',
          'clinicName': clinicName,
          'availabilityTime': data['availabilityTime'] ?? 'Not specified',
          'contactNumber': data['contactNumber'] ?? 'Not available',
          'location': clinicLocation,
          'imageUrl': data['profileImage'] ?? 'assets/default_doctor.png',
          'email': data['email'] ?? ''
        });
      }
      
      setState(() {
        doctors = doctorsList;
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
              'imageUrl': 'assets/doctor1.png'
            },
            {
              'name': 'Dr. Rajesh Sharma',
              'specialty': 'General Physician',
              'clinicName': 'Care & Cure Center',
              'availabilityTime': 'Mon-Sat, 9AM - 6PM',
              'contactNumber': '+91 9123456789',
              'location': 'Delhi, India',
              'imageUrl': 'assets/doctor2.png'
            },
            {
              'name': 'Dr. Nita Kapoor', 
              'specialty': 'Orthopedic',
              'clinicName': 'Wellness Hub',
              'availabilityTime': 'Tue-Sun, 8AM - 3PM',
              'contactNumber': '+91 9988776655',
              'location': 'Bangalore, India',
              'imageUrl': 'assets/doctor3.png'
            },
          ];
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        isLoading = false;
      });
      
      // Show error toast
      Fluttertoast.showToast(
        msg: "Failed to load data. Please try again.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MedSlots', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              String? latestBooking = prefs.getString("latest_booking");
              Fluttertoast.showToast(
                msg: latestBooking ?? "No recent bookings",
                toastLength: Toast.LENGTH_LONG,
                gravity: ToastGravity.TOP,
                backgroundColor: Colors.blue,
                textColor: Colors.white,
              );
            },
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
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: widget.patientProfileImage != null
                      ? AssetImage(widget.patientProfileImage!)
                      : AssetImage('assets/default_profile.png'),
                ),
                SizedBox(width: 10),
                Text('Welcome, $patientName!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
          
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search doctors...',
                prefixIcon: Icon(Icons.search, color: Colors.teal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.teal),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.teal, width: 2),
                ),
              ),
              onChanged: (value) {
                // Filter doctors based on search (not implemented yet)
              },
            ),
          ),
          
          // Section title
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available Doctors',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.teal.shade800
                  ),
                ),
                TextButton(
                  onPressed: _loadData,
                  child: Text('Refresh', style: TextStyle(color: Colors.teal)),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: isLoading 
            ? Center(child: CircularProgressIndicator(color: Colors.teal))
            : doctors.isEmpty 
              ? Center(child: Text('No doctors available'))
              : ListView.builder(
                  itemCount: doctors.length,
                  itemBuilder: (context, index) {
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
                          backgroundImage: doctors[index]['imageUrl'].startsWith('assets/')
                              ? AssetImage(doctors[index]['imageUrl'])
                              : NetworkImage(doctors[index]['imageUrl']) as ImageProvider,
                          backgroundColor: Colors.teal.shade50,
                        ),
                        title: Text(
                          doctors[index]['name']!,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${doctors[index]['specialty']}'),
                            Text('${doctors[index]['clinicName']} - ${doctors[index]['location']}', 
                                 style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, color: Colors.teal),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DoctorDetailsScreen(
                                doctorName: doctors[index]['name']!,
                                // doctorEmail: doctors[index]['email'],
                                specialization: doctors[index]['specialty']!,
                                clinicName: doctors[index]['clinicName']!,
                                availability: doctors[index]['availabilityTime']!,
                                contact: doctors[index]['contactNumber']!,
                                location: doctors[index]['location']!,
                                imageUrl: doctors[index]['imageUrl']!,
                                patientEmail: widget.patientEmail,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
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
                builder: (context) => PatientProfileScreen(
                  // email: widget.patientEmail ?? "",
                ),
              ),
            );
          }
        },
      ),
    );
  }
}