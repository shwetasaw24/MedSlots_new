import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: DoctorDashboard(),
  ));
}

class DoctorDashboard extends StatefulWidget {
  @override
  _DoctorDashboardState createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> patientHistory = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String doctorId = '';
  Map<String, dynamic> doctorData = {};
  bool isLoading = true;
  
  Map<String, List<Map<String, dynamic>>> appointments = {
    "Today": [],
    "Tomorrow": [],
    "Day After Tomorrow": [],
  };

  @override
  void initState() {
    super.initState();
    _getCurrentDoctorId();
  }

  Future<void> _getCurrentDoctorId() async {
    User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        doctorId = user.uid;
      });
      await _loadDoctorData();
      await _loadAppointments();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadDoctorData() async {
    try {
      // Only get doctor data from the 'doctors' collection
      DocumentSnapshot doctorDoc = await _firestore.collection('doctors').doc(doctorId).get();
      
      if (doctorDoc.exists) {
        setState(() {
          doctorData = doctorDoc.data() as Map<String, dynamic>;
        });
      } else {
        print("Doctor data not found in doctors collection");
      }
    } catch (e) {
      print("Error loading doctor data: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadAppointments() async {
    // Get today's date
    DateTime now = DateTime.now();
    String todayDate = DateFormat('yyyy-MM-dd').format(now);
    String tomorrowDate = DateFormat('yyyy-MM-dd').format(now.add(Duration(days: 1)));
    String dayAfterTomorrowDate = DateFormat('yyyy-MM-dd').format(now.add(Duration(days: 2)));

    // Load appointments from Firestore
    await _loadAppointmentsForDate("Today", todayDate);
    await _loadAppointmentsForDate("Tomorrow", tomorrowDate);
    await _loadAppointmentsForDate("Day After Tomorrow", dayAfterTomorrowDate);
    
    // Load patient history
    await _loadPatientHistory();
  }

  Future<void> _loadAppointmentsForDate(String dayKey, String date) async {
    try {
      // Update to use the doctor's UID directly from the doctors collection
      QuerySnapshot appointmentSnapshot = await _firestore
          .collection('Appointment')
          .where('date', isEqualTo: date)
          .where('DoctorId', isEqualTo: doctorId) // Use doctorId directly
          .get();

      List<Map<String, dynamic>> dayAppointments = [];
      
      for (var doc in appointmentSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // Get patient details
        DocumentSnapshot patientDoc = await _firestore
            .collection('Patient')
            .doc(data['PatientId'] != null ? data['PatientId'].toString().replaceAll('/Patient/', '') : '')
            .get();
        
        Map<String, dynamic> patientData = {};
        if (patientDoc.exists) {
          patientData = patientDoc.data() as Map<String, dynamic>;
        }

        dayAppointments.add({
          "id": doc.id,
          "name": patientData['name'] ?? "Unknown Patient",
          "time": data['TimeSlot'] ?? "Not Set",
          "contact": patientData['contactNumber No.'] != null ? patientData['contactNumber No.'].toString() : "N/A",
          "done": data['status'] == true,
        });
      }

      setState(() {
        appointments[dayKey] = dayAppointments;
      });
    } catch (e) {
      print("Error loading appointments for $dayKey: $e");
    }
  }

  Future<void> _loadPatientHistory() async {
    try {
      // Update to use doctorId directly instead of Doctor collection path
      QuerySnapshot historySnapshot = await _firestore
          .collection('Records')
          .where('DoctorId', isEqualTo: doctorId) // Use doctorId directly
          .get();

      List<Map<String, dynamic>> history = [];
      
      for (var doc in historySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // Get patient details
        String patientEmail = data['email'] != null ? 
            data['email'].toString().replaceAll('/Patient/profile', '') : '';
        
        DocumentSnapshot? patientDoc;
        QuerySnapshot querySnapshot = await _firestore
          .collection('Patient')
          .where('email', isEqualTo: patientEmail)
          .limit(1)
          .get();

        if (querySnapshot.docs.isNotEmpty) {
          patientDoc = querySnapshot.docs.first;
        }
        
        if (patientDoc != null) {
          Map<String, dynamic> patientData = patientDoc.data() as Map<String, dynamic>;
          
          history.add({
            "name": patientData['name'] ?? "Unknown",
            "contact": patientData['contactNumber No.'] != null ? 
                patientData['contactNumber No.'].toString() : "N/A",
            "illness": data['diagnosis'] ?? "General Checkup", // Added diagnosis field
          });
        }
      }

      setState(() {
        patientHistory = history;
      });
    } catch (e) {
      print("Error loading patient history: $e");
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleDone(String day, int index, bool? value) async {
    if (day == "Today") {
      try {
        // Mark appointment as done in Firestore
        String appointmentId = appointments[day]![index]["id"];
        await _firestore
            .collection('Appointment')
            .doc(appointmentId)
            .update({'status': true});

        // Add to patient history
        var patient = appointments[day]![index];
        
        // Create record in Firestore
        await _firestore.collection('Records').add({
          'email': '/Patient/profile',  // Update with actual path format
          'FileName': '/xyz/file',
          'DoctorId': doctorId, // Use doctorId directly
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'diagnosis': 'General Checkup',
          // Add other relevant fields
        });

        setState(() {
          // Remove from appointments
          var completedAppointment = appointments[day]!.removeAt(index);
          
          // Add to history
          patientHistory.add({
            "name": completedAppointment["name"], 
            "contact": completedAppointment["contact"], 
            "illness": "General Checkup"
          });
        });
      } catch (e) {
        print("Error updating appointment status: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      body: _selectedIndex == 0
          ? HomeScreen(
              appointments: appointments, 
              toggleDone: _toggleDone,
              doctorName: doctorData['fullName'] ?? doctorData['name'] ?? 'Doctor',
            )
          : _selectedIndex == 1
              ? PatientHistoryScreen(patientHistory: patientHistory)
              : DoctorProfileScreen(doctorData: doctorData, doctorId: doctorId),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> appointments;
  final Function(String, int, bool?) toggleDone;
  final String doctorName;
  
  HomeScreen({required this.appointments, required this.toggleDone, required this.doctorName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('MedSlots', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('Welcome, $doctorName', 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
            SizedBox(height: 16),
            ...appointments.keys.map((day) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  appointments[day]!.isEmpty 
                  ? Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("No appointments scheduled"),
                      ),
                    )
                  : Column(
                      children: appointments[day]!.asMap().entries.map((entry) {
                        int index = entry.key;
                        var appointment = entry.value;
                        return Card(
                          child: ListTile(
                            title: Text(appointment["name"]!),
                            subtitle: Text('Time: ${appointment["time"]}\nContact: ${appointment["contact"]}'),
                            trailing: Checkbox(
                              value: appointment["done"],
                              onChanged: (day == "Today") ? (value) => toggleDone(day, index, value) : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  SizedBox(height: 10),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class PatientHistoryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> patientHistory;
  PatientHistoryScreen({required this.patientHistory});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Patient History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: patientHistory.isEmpty
          ? Center(child: Text("No patient history available"))
          : ListView.builder(
              itemCount: patientHistory.length,
              itemBuilder: (context, index) {
                final patient = patientHistory[index];
                return Card(
                  child: ListTile(
                    title: Text(patient["name"]!),
                    subtitle: Text('Contact: ${patient["contact"]}\nIllness: ${patient["illness"]}'),
                    trailing: Icon(Icons.check_circle, color: Colors.green, size: 28),
                  ),
                );
              },
            ),
    );
  }
}

class DoctorProfileScreen extends StatefulWidget {
  final Map<String, dynamic> doctorData;
  final String doctorId;
  
  DoctorProfileScreen({required this.doctorData, required this.doctorId});
  
  @override
  _DoctorProfileScreenState createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  String currentAvailability = "9:00am - 12:00pm";
  String availabilityDay1 = "10:00am - 1:00pm";
  String availabilityDay2 = "4:00pm - 7:00pm";
  String clinicAddress = "";
  String doctorName = "";
  String doctorSpecialization = "General";
  String doctorLocation = "";
  String doctorEmail = "";
  String doctorPhone = "";
  String doctorExperience = "";
  String doctorQualification = "";
  bool isBookingEnabled = true;
  File? _profileImage;
  String? profileImageUrl;
  bool isLoading = true;
  
  // Controllers for text fields
  final TextEditingController _specializationController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _qualificationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  
  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  @override
  void initState() {
    super.initState();
    _loadDoctorProfile();
    _loadSavedData();
  }
  
  @override
  void dispose() {
    _specializationController.dispose();
    _addressController.dispose();
    _qualificationController.dispose();
    _experienceController.dispose();
    super.dispose();
  }
  
  Future<void> _loadDoctorProfile() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      // First try to get fresh data from Firestore
      if (widget.doctorId.isNotEmpty) {
        DocumentSnapshot doctorDoc = await _firestore.collection('doctors').doc(widget.doctorId).get();
        
        if (doctorDoc.exists) {
          Map<String, dynamic> doctorData = doctorDoc.data() as Map<String, dynamic>;
          
          setState(() {
            doctorName = doctorData['fullName'] ?? doctorData['name'] ?? 'Doctor';
            doctorSpecialization = doctorData['specialization'] ?? 'General';
            clinicAddress = doctorData['clinicName'] ?? 'Clinic';
            doctorLocation = doctorData['location'] ?? '';
            doctorEmail = doctorData['email'] ?? '';
            doctorPhone = doctorData['contactNo'] ?? doctorData['phone'] ?? '';
            doctorExperience = doctorData['experience'] ?? '';
            doctorQualification = doctorData['qualification'] ?? '';
            currentAvailability = doctorData['Current Availaibility'] ?? currentAvailability;
            availabilityDay1 = doctorData['Tommorows Availaibility'] ?? availabilityDay1;
            availabilityDay2 = doctorData['Day After Tommorows Availaibility'] ?? availabilityDay2;
            profileImageUrl = doctorData['profile_picture'];
            isBookingEnabled = doctorData['booking_enabled'] ?? true;
          });
        } else {
          // If document doesn't exist, use the provided data
          _setDataFromProps();
        }
      } else {
        // If no doctorId, use the provided data
        _setDataFromProps();
      }
      
      // Set initial values for controllers
      _specializationController.text = doctorSpecialization;
      _addressController.text = clinicAddress;
      _qualificationController.text = doctorQualification;
      _experienceController.text = doctorExperience;
    } catch (e) {
      print("Error loading doctor profile: $e");
      // Fallback to provided data
      _setDataFromProps();
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
  
  void _setDataFromProps() {
    setState(() {
      doctorName = widget.doctorData['fullName'] ?? widget.doctorData['name'] ?? 'Doctor';
      doctorSpecialization = widget.doctorData['specialization'] ?? 'General';
      clinicAddress = widget.doctorData['clinicName'] ?? 'Clinic';
      doctorLocation = widget.doctorData['location'] ?? '';
      doctorEmail = widget.doctorData['email'] ?? '';
      doctorPhone = widget.doctorData['contactNo'] ?? widget.doctorData['phone'] ?? '';
      doctorExperience = widget.doctorData['experience'] ?? '';
      doctorQualification = widget.doctorData['qualification'] ?? '';
      currentAvailability = widget.doctorData['Current Availaibility'] ?? currentAvailability;
      availabilityDay1 = widget.doctorData['Tommorows Availaibility'] ?? availabilityDay1;
      availabilityDay2 = widget.doctorData['Day After Tommorows Availaibility'] ?? availabilityDay2;
      profileImageUrl = widget.doctorData['profile_picture'];
      isBookingEnabled = widget.doctorData['booking_enabled'] ?? true;
    });
  }

  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currentAvailability = prefs.getString('currentAvailability') ?? currentAvailability;
      availabilityDay1 = prefs.getString('availabilityDay1') ?? availabilityDay1;
      availabilityDay2 = prefs.getString('availabilityDay2') ?? availabilityDay2;
      clinicAddress = prefs.getString('clinicAddress') ?? clinicAddress;
      doctorSpecialization = prefs.getString('doctorSpecialization') ?? doctorSpecialization;
      doctorQualification = prefs.getString('doctorQualification') ?? doctorQualification;
      doctorExperience = prefs.getString('doctorExperience') ?? doctorExperience;
      isBookingEnabled = prefs.getBool('isBookingEnabled') ?? true;
      
      // Update controllers with loaded data
      _specializationController.text = doctorSpecialization;
      _addressController.text = clinicAddress;
      _qualificationController.text = doctorQualification;
      _experienceController.text = doctorExperience;
    });
    _updateAvailabilityDaily();
  }

  Future<void> _updateAvailabilityDaily() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String lastUpdate = prefs.getString('lastUpdate') ?? "";
    String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    if (lastUpdate != todayDate) {
      setState(() {
        currentAvailability = availabilityDay1;
        availabilityDay1 = availabilityDay2;
        availabilityDay2 = "Not Set";
      });
      
      // Update in Firestore
      if (widget.doctorId.isNotEmpty) {
        try {
          await _firestore.collection('doctors').doc(widget.doctorId).update({
            'Current Availaibility': currentAvailability,
            'Tommorows Availaibility': availabilityDay1,
            'Day After Tommorows Availaibility': availabilityDay2,
          });
        } catch (e) {
          print("Error updating availability in Firestore: $e");
        }
      }
      
      // Update in SharedPreferences
      prefs.setString('currentAvailability', currentAvailability);
      prefs.setString('availabilityDay1', availabilityDay1);
      prefs.setString('availabilityDay2', availabilityDay2);
      prefs.setString('lastUpdate', todayDate);
    }
  }

  void _updateAvailability(int day) async {
    TimeOfDay? pickedStartTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedStartTime != null) {
      TimeOfDay? pickedEndTime = await showTimePicker(
        context: context,
        initialTime: pickedStartTime,
      );
      if (pickedEndTime != null) {
        setState(() {
          String formattedStartTime = pickedStartTime.format(context);
          String formattedEndTime = pickedEndTime.format(context);
          if (day == 1) {
            availabilityDay1 = "$formattedStartTime - $formattedEndTime";
          } else {
            availabilityDay2 = "$formattedStartTime - $formattedEndTime";
          }
        });
        
        // Update in Firestore
        if (widget.doctorId.isNotEmpty) {
          try {
            await _firestore.collection('doctors').doc(widget.doctorId).update({
              day == 1 ? 'Tommorows Availaibility' : 'Day After Tommorows Availaibility': 
                day == 1 ? availabilityDay1 : availabilityDay2,
            });
          } catch (e) {
            print("Error updating availability in Firestore: $e");
          }
        }
        
        // Update in SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setString(day == 1 ? 'availabilityDay1' : 'availabilityDay2', 
                       day == 1 ? availabilityDay1 : availabilityDay2);
      }
    }
  }

  void _updateAddress() {
    _addressController.text = clinicAddress;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Update Clinic Address"),
        content: TextField(
          controller: _addressController,
          decoration: InputDecoration(hintText: "Enter new address"),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              setState(() {
                clinicAddress = _addressController.text;
              });
              
              // Update in Firestore
              if (widget.doctorId.isNotEmpty) {
                try {
                  await _firestore.collection('doctors').doc(widget.doctorId).update({
                    'clinicName': clinicAddress,
                  });
                } catch (e) {
                  print("Error updating clinic address in Firestore: $e");
                }
              }
              
              // Update in SharedPreferences
              SharedPreferences prefs = await SharedPreferences.getInstance();
              prefs.setString('clinicAddress', clinicAddress);
              Navigator.pop(context);
            },
            child: Text("Save"),
          )
        ],
      ),
    );
  }

  void _updateSpecialization() {
    _specializationController.text = doctorSpecialization;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Update Specialization"),
        content: TextField(
          controller: _specializationController,
          decoration: InputDecoration(hintText: "Enter your specialization"),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              setState(() {
                doctorSpecialization = _specializationController.text;
              });
              
              // Update in Firestore
              if (widget.doctorId.isNotEmpty) {
                try {
                  await _firestore.collection('doctors').doc(widget.doctorId).update({
                    'specialization': doctorSpecialization,
                  });
                } catch (e) {
                  print("Error updating specialization in Firestore: $e");
                }
              }
              
              // Update in SharedPreferences
              SharedPreferences prefs = await SharedPreferences.getInstance();
              prefs.setString('doctorSpecialization', doctorSpecialization);
              Navigator.pop(context);
            },
            child: Text("Save"),
          )
        ],
      ),
    );
  }
  
  void _updateQualification() {
    _qualificationController.text = doctorQualification;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Update Qualification"),
        content: TextField(
          controller: _qualificationController,
          decoration: InputDecoration(hintText: "Enter your qualification"),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              setState(() {
                doctorQualification = _qualificationController.text;
              });
              
              // Update in Firestore
              if (widget.doctorId.isNotEmpty) {
                try {
                  await _firestore.collection('doctors').doc(widget.doctorId).update({
                    'qualification': doctorQualification,
                  });
                } catch (e) {
                  print("Error updating qualification in Firestore: $e");
                }
              }
              
              // Update in SharedPreferences
              SharedPreferences prefs = await SharedPreferences.getInstance();
              prefs.setString('doctorQualification', doctorQualification);
              Navigator.pop(context);
            },
            child: Text("Save"),
          )
        ],
      ),
    );
  }
  
  void _updateExperience() {
    _experienceController.text = doctorExperience;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Update Experience"),
        content: TextField(
          controller: _experienceController,
          decoration: InputDecoration(hintText: "Enter your years of experience"),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              setState(() {
                doctorExperience = _experienceController.text;
              });
              
              // Update in Firestore
              if (widget.doctorId.isNotEmpty) {
                try {
                  await _firestore.collection('doctors').doc(widget.doctorId).update({
                    'experience': doctorExperience,
                  });
                } catch (e) {
                  print("Error updating experience in Firestore: $e");
                }
              }
              
              // Update in SharedPreferences
              SharedPreferences prefs = await SharedPreferences.getInstance();
              prefs.setString('doctorExperience', doctorExperience);
              Navigator.pop(context);
            },
            child: Text("Save"),
          )
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
      
      // Upload to Firebase Storage
      if (widget.doctorId.isNotEmpty) {
        try {
          setState(() {
            isLoading = true;
          });
          
          String fileName = 'doctor_profiles/${widget.doctorId}.jpg';
          await _storage.ref(fileName).putFile(_profileImage!);
          String downloadURL = await _storage.ref(fileName).getDownloadURL();
          
          // Update profile pic URL in Firestore
          try {
            await _firestore.collection('doctors').doc(widget.doctorId).update({
              'profile_picture': downloadURL,
            });
            
            setState(() {
              profileImageUrl = downloadURL;
            });
          } catch (e) {
            print("Error updating profile picture in Firestore: $e");
          }
        } catch (e) {
          print("Error uploading image: $e");
        } finally {
          setState(() {
            isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor Profile'),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: isLoading 
      ? Center(child: CircularProgressIndicator(color: Colors.teal))
      : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: _getProfileImage(),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              
              // Profile Info Section
              _buildProfileSection(),
              
              SizedBox(height: 20),
              
              // Availability Section
              _buildAvailabilitySection(),
              
              SizedBox(height: 20),
              
              // Booking Settings
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SwitchListTile(
                    title: Text("Enable Appointments"),
                    subtitle: Text("Allow patients to book appointments with you"),
                    value: isBookingEnabled,
                    activeColor: Colors.teal,
                    onChanged: (bool value) async {
                      setState(() {
                        isBookingEnabled = value;
                      });
                      
                      // Update in Firestore
                      if (widget.doctorId.isNotEmpty) {
                        try {
                          await _firestore.collection('doctors').doc(widget.doctorId).update({
                            'booking_enabled': isBookingEnabled,
                          });
                        } catch (e) {
                          print("Error updating booking status in Firestore: $e");
                        }
                      }
                      
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      prefs.setBool('isBookingEnabled', isBookingEnabled);
                    },
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              // Update Buttons Section
              _buildUpdateButtonsSection(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProfileSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Professional Information",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            Divider(color: Colors.teal),
            SizedBox(height: 10),
            _buildProfileItem("Name", "Dr. $doctorName"),
            _buildProfileItem("Specialization", doctorSpecialization, onTap: _updateSpecialization),
            _buildProfileItem("Qualification", doctorQualification, onTap: _updateQualification),
            _buildProfileItem("Experience", doctorExperience.isNotEmpty ? "$doctorExperience years" : "Not specified", onTap: _updateExperience),
            _buildProfileItem("Email", doctorEmail),
            _buildProfileItem("Phone", doctorPhone),
            _buildProfileItem("Clinic", clinicAddress, onTap: _updateAddress),
            if (doctorLocation.isNotEmpty)
              _buildProfileItem("Location", doctorLocation),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfileItem(String label, String value, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16),
            ),
          ),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: Icon(Icons.edit, color: Colors.teal, size: 18),
            ),
        ],
      ),
    );
  }
  
  Widget _buildAvailabilitySection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Availability Schedule",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            Divider(color: Colors.teal),
            SizedBox(height: 10),
            _buildAvailabilityItem("Today", currentAvailability),
            _buildAvailabilityItem("Tomorrow", availabilityDay1, canEdit: true, onTap: () => _updateAvailability(1)),
            _buildAvailabilityItem("Day After Tomorrow", availabilityDay2, canEdit: true, onTap: () => _updateAvailability(2)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAvailabilityItem(String day, String time, {bool canEdit = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Row(
            children: [
              Text(
                time,
                style: TextStyle(fontSize: 16),
              ),
              if (canEdit && onTap != null)
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.teal, size: 18),
                  onPressed: onTap,
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildUpdateButtonsSection() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _updateSpecialization,
          child: Text("Update Specialization"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 40),
          ),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: _updateQualification,
          child: Text("Update Qualification"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 40),
          ),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: _updateExperience,
          child: Text("Update Experience"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 40),
          ),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: _updateAddress,
          child: Text("Update Clinic Address"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 40),
          ),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: () => _updateAvailability(1),
          child: Text("Update Tomorrow's Availability"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 40),
          ),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: () => _updateAvailability(2),
          child: Text("Update Day After Tomorrow's Availability"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 40),
          ),
        ),
      ],
    );
  }
  
  ImageProvider _getProfileImage() {
    if (_profileImage != null) {
      return FileImage(_profileImage!);
    } else if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      return NetworkImage(profileImageUrl!);
    } else {
      return AssetImage('assets/doctor.jpg');
    }
  }
}