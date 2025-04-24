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
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        setState(() {
          doctorId = user.uid;
        });
        
        // Load doctor data first
        await _loadDoctorData();
        
        // Then fetch appointments
        if (doctorData.isNotEmpty) {
          await _fetchAppointments();
          await _loadPatientHistory();
        } else {
          print("Doctor data is empty, can't fetch appointments");
        }
      } else {
        print("No current user found");
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error in _getCurrentDoctorId: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadDoctorData() async {
    try {
      print("Loading doctor data for ID: $doctorId");
      
      // Get doctor data from the 'doctors' collection
      DocumentSnapshot doctorDoc = await _firestore.collection('doctors').doc(doctorId).get();

      if (doctorDoc.exists) {
        setState(() {
          doctorData = doctorDoc.data() as Map<String, dynamic>;
        });
        print("Successfully loaded doctor data: ${doctorData['email']}");
        
        // If doctor email is not available in doctorData, get from auth
        if (doctorData['email'] == null && _auth.currentUser?.email != null) {
          doctorData['email'] = _auth.currentUser!.email;
          print("Using email from auth: ${doctorData['email']}");
        }
      } else {
        print("Doctor data not found in doctors collection. Trying Doctor collection...");
        
        // Try the 'Doctor' collection as a fallback
        if (_auth.currentUser?.email != null) {
          String email = _auth.currentUser!.email!;
          DocumentSnapshot doctorDoc2 = await _firestore.collection('Doctor').doc(email).get();
          
          if (doctorDoc2.exists) {
            setState(() {
              doctorData = doctorDoc2.data() as Map<String, dynamic>;
              doctorData['email'] = email; // Ensure email is included
            });
            print("Successfully loaded doctor data from Doctor collection");
          } else {
            print("Doctor not found in Doctor collection either");
            
            // Last resort: Create minimal doctor data from auth user
            setState(() {
              doctorData = {
                'email': _auth.currentUser!.email,
                'name': _auth.currentUser!.displayName ?? 'Doctor',
                'fullName': _auth.currentUser!.displayName ?? 'Doctor',
              };
            });
            print("Created minimal doctor data from auth user");
          }
        }
      }
    } catch (e) {
      print("Error loading doctor data: $e");
      print(StackTrace.current);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  
  Future<void> _fetchAppointments() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Reset the appointments
      setState(() {
        appointments = {
          "Today": [],
          "Tomorrow": [],
          "Day After Tomorrow": [],
        };
      });

      // Get doctor information for matching
      String doctorEmail = (doctorData['email'] ?? _auth.currentUser?.email ?? '').toString().toLowerCase().trim();
      String doctorName = (doctorData['fullName'] ?? doctorData['name'] ?? '').toString().trim();

      print("Fetching appointments for doctor: Email=$doctorEmail, Name=$doctorName, ID=$doctorId");

      // Prepare dates for filtering
      DateTime now = DateTime.now();
      String todayDate = DateFormat('yyyy-MM-dd').format(now);
      String tomorrowDate = DateFormat('yyyy-MM-dd').format(now.add(Duration(days: 1)));
      String dayAfterTomorrowDate = DateFormat('yyyy-MM-dd').format(now.add(Duration(days: 2)));

      print("Looking for dates: Today=$todayDate, Tomorrow=$tomorrowDate, DayAfter=$dayAfterTomorrowDate");

      // Build a comprehensive list of collections to query
      List<Future<QuerySnapshot>> queries = [];

      // 1. Check Appointment collection
      queries.add(_firestore.collection('Appointment').get());

      // 2. Check Bookings/Appointment collection
      queries.add(_firestore.collection('Bookings')
          .doc('Appointment')
          .collection('Appointment')
          .get());

      // 3. Check Doctor's BookedSlots collection if doctorEmail exists
      if (doctorEmail.isNotEmpty) {
        queries.add(_firestore.collection('Doctor')
            .doc(doctorEmail)
            .collection('BookedSlots')
            .get());
      }

      // 4. Check doctors collection with doctorId if available
      if (doctorId.isNotEmpty) {
        queries.add(_firestore.collection('doctors')
            .doc(doctorId)
            .collection('appointments')
            .get());
      }

      // 5. Check global appointments collection
      queries.add(_firestore.collection('appointments').get());

      // Execute all queries in parallel
      List<QuerySnapshot> queryResults = await Future.wait(queries);

      // Process each query result
      List<Map<String, dynamic>> allAppointments = [];

      for (var querySnapshot in queryResults) {
        // Print collection path for debugging
        print("Processing collection with ${querySnapshot.docs.length} documents");

        // Filter for this doctor and extract appointment data
        for (var doc in querySnapshot.docs) {
          try {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

            // Print raw document data for debugging
            print("Examining document: ${doc.id}");
            print("Document data: $data");

            // Try to match this appointment to the current doctor
            bool isForThisDoctor = _isAppointmentForDoctor(data, doctorEmail, doctorName, doctorId);

            if (isForThisDoctor) {
              print("Found matching appointment: ${doc.id}");

              // Create standardized appointment data
              Map<String, dynamic> appointmentData = await _createAppointmentData(doc.id, data);

              // Check if this appointment belongs to any of our date categories
              String appointmentDate = appointmentData["date"];

              // Determine which category this belongs to
              String category = "";
              if (appointmentDate == todayDate) {
                category = "Today";
              } else if (appointmentDate == tomorrowDate) {
                category = "Tomorrow";
              } else if (appointmentDate == dayAfterTomorrowDate) {
                category = "Day After Tomorrow";
              } else {
                // Try with more flexible date parsing
                DateTime? parsedDate = _tryParseDate(appointmentDate);
                if (parsedDate != null) {
                  String formattedParsedDate = DateFormat('yyyy-MM-dd').format(parsedDate);
                  if (formattedParsedDate == todayDate) {
                    category = "Today";
                  } else if (formattedParsedDate == tomorrowDate) {
                    category = "Tomorrow";
                  } else if (formattedParsedDate == dayAfterTomorrowDate) {
                    category = "Day After Tomorrow";
                  }
                }
              }

              if (category.isNotEmpty) {
                allAppointments.add({...appointmentData, "category": category});
                print("Added appointment to $category category: ${appointmentData["patientEmail"]}");
              } else {
                print("Appointment date doesn't match any category: $appointmentDate");
              }
            } else {
              print("Appointment not for this doctor");
            }
          } catch (e) {
            print("Error processing appointment doc: $e");
            print(StackTrace.current);
          }
        }
      }

      // Now organize all found appointments into their respective categories
      for (var appointment in allAppointments) {
        String category = appointment["category"];
        appointment.remove("category"); // Remove the temporary category field

        setState(() {
          appointments[category]!.add(appointment);
        });
      }

      print("Final appointment counts - Today: ${appointments['Today']!.length}, Tomorrow: ${appointments['Tomorrow']!.length}, Day After: ${appointments['Day After Tomorrow']!.length}");
    } catch (e) {
      print("Error fetching appointments: $e");
      print(StackTrace.current);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Helper: Check if an appointment belongs to the current doctor
  bool _isAppointmentForDoctor(Map<String, dynamic> data, String doctorEmail, String doctorName, String doctorId) {
    // Check all possible doctor identifier fields with case insensitivity
    String apptDoctorEmail = (data['doctorEmail'] ?? data['DoctorEmail'] ?? '').toString().toLowerCase().trim();
    String apptDoctorName = (data['doctorName'] ?? data['DoctorName'] ?? '').toString().trim();
    String apptDoctorId = (data['doctorId'] ?? data['DoctorId'] ?? '').toString().trim();

    // Additional fields from your example data
    if (apptDoctorEmail.isEmpty && data.containsKey('doctorEmail')) {
      apptDoctorEmail = data['doctorEmail'].toString().toLowerCase().trim();
    }

    if (apptDoctorName.isEmpty && data.containsKey('doctorName')) {
      apptDoctorName = data['doctorName'].toString().trim();
    }

    // Also check potential nested objects or differently named fields
    if (data['doctor'] is Map) {
      Map<String, dynamic> doctorInfo = data['doctor'] as Map<String, dynamic>;
      if (doctorInfo['email'] != null) {
        apptDoctorEmail = doctorInfo['email'].toString().toLowerCase().trim();
      }
      if (doctorInfo['name'] != null) {
        apptDoctorName = doctorInfo['name'].toString().trim();
      }
      if (doctorInfo['id'] != null) {
        apptDoctorId = doctorInfo['id'].toString().trim();
      }
    }

    print("Comparing: App doctor email: '$apptDoctorEmail' with '$doctorEmail'");
    print("Comparing: App doctor name: '$apptDoctorName' with '$doctorName'");
    print("Comparing: App doctor ID: '$apptDoctorId' with '$doctorId'");

    // More aggressively normalize doctor name/email for matching
    // Check for partial matches in either direction for doctor name
    bool nameMatches = false;
    if (doctorName.isNotEmpty && apptDoctorName.isNotEmpty) {
      nameMatches = doctorName.toLowerCase().contains(apptDoctorName.toLowerCase()) || 
                    apptDoctorName.toLowerCase().contains(doctorName.toLowerCase());
    }

    bool emailMatches = apptDoctorEmail == doctorEmail;
    bool idMatches = apptDoctorId == doctorId;

    // Check for case-insensitive matches
    if (!emailMatches && doctorEmail.isNotEmpty && apptDoctorEmail.isNotEmpty) {
      emailMatches = doctorEmail.toLowerCase() == apptDoctorEmail.toLowerCase();
    }

    // In case someone used a display name as email
    if (!emailMatches && !nameMatches && doctorEmail.isNotEmpty && apptDoctorName.isNotEmpty) {
      emailMatches = doctorEmail.toLowerCase().contains(apptDoctorName.toLowerCase()) ||
                    apptDoctorName.toLowerCase().contains(doctorEmail.toLowerCase());
    }

    print("Match results - Email: $emailMatches, Name: $nameMatches, ID: $idMatches");

    return emailMatches || nameMatches || idMatches;
  }
  
  // Helper: Try to parse date in multiple formats
  DateTime? _tryParseDate(String dateStr) {
    List<String> formats = [
      'yyyy-MM-dd',
      'dd-MM-yyyy',
      'MM/dd/yyyy',
      'dd/MM/yyyy',
      'yyyy/MM/dd',
      'd MMMM yyyy',
      'MMMM d, yyyy',
    ];

    for (String format in formats) {
      try {
        return DateFormat(format).parse(dateStr);
      } catch (e) {
        // Try next format
      }
    }

    // If none of our formats work, let Dart try to figure it out
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      print("Failed to parse date: $dateStr");
      return null;
    }
  }
  
  // Helper: Create standardized appointment data
  Future<Map<String, dynamic>> _createAppointmentData(String docId, Map<String, dynamic> data) async {
    // Get patient email from all possible field names
    String patientEmail = (data['patientEmail'] ?? 
                          data['PatientEmail'] ?? 
                          data['patient_email'] ?? 
                          data['email'] ?? '').toString();
  
    // Extract appointment time
    String timeSlot = (data['TimeSlot'] ?? 
                      data['timeSlot'] ?? 
                      data['time'] ?? 
                      data['appointmentTime'] ?? "Unknown Time").toString();
  
    // Extract appointment date
    String date = (data['date'] ?? 
                  data['Date'] ?? 
                  data['appointmentDate'] ?? "").toString();
  
    // Extract doctor contact specifically
    String doctorContact = (data['doctorContact'] ?? 
                           data['DoctorContact'] ?? 
                           data['doctor_contact'] ?? 
                           "Unknown").toString();
  
    // Extract status
    bool isCompleted = (data['Status'] == "Completed" || 
                        data['status'] == "Completed" ||
                        data['Status'] == "completed" ||
                        data['status'] == "completed");
  
    // Extract clinic name
    String clinicName = (data['ClinicsName'] ?? 
                        data['clinicsName'] ?? 
                        data['clinicName'] ?? 
                        data['ClinicName'] ?? "").toString();
  
    // Get additional appointment details
    String reason = (data['reason'] ?? 
                    data['Reason'] ?? 
                    data['purpose'] ?? 
                    data['visitReason'] ?? 
                    "General Checkup").toString();
  
    String location = (data['location'] ?? 
                      data['Location'] ?? 
                      data['place'] ?? "").toString();
  
    String specialization = (data['specialization'] ?? 
                            data['Specialization'] ?? 
                            data['specialty'] ?? "").toString();
  
    String bookedOn = (data['bookedOn'] ?? 
                      data['BookedOn'] ?? 
                      data['bookingDate'] ?? "").toString();
  
    print("Extracted appointment details - Email: $patientEmail, Time: $timeSlot, Date: $date, Clinic: $clinicName");
  
    // Create appointment data object with all available fields
    Map<String, dynamic> appointmentData = {
      "id": docId,
      "name": "Unknown Patient", // Will update if patient data is found
      "time": timeSlot,
      "date": date,
      "contact": "Unknown",
      "doctorContact": doctorContact, // Added doctor contact specifically
      "done": isCompleted,
      "clinicName": clinicName,
      "patientEmail": patientEmail,
      "reason": reason,
      "location": location,
      "specialization": specialization,
      "bookedOn": bookedOn,
      // Add all other relevant fields from the original data
      "rawData": data, // Include raw data for reference if needed
    };
  
    // Try to get patient information through multiple methods
    if (patientEmail.isNotEmpty) {
      await _fetchPatientDetails(patientEmail, appointmentData);
    } else {
      // If there's no email, try to extract patient name directly from appointment
      String patientName = (data['patientName'] ?? 
                         data['PatientName'] ?? 
                         data['patient_name'] ?? 
                         "Unknown Patient").toString();
  
      String patientContact = (data['patientContact'] ?? 
                           data['PatientContact'] ?? 
                           data['patient_contact'] ?? 
                           data['contactNo'] ?? 
                           data['contact'] ??
                           "Unknown").toString();
  
      appointmentData["name"] = patientName;
      appointmentData["contact"] = patientContact;
  
      // If we have a phone number but no email, try finding patient by phone number
      if (patientContact != "Unknown" && patientContact.isNotEmpty) {
        await _fetchPatientDetailsByContact(patientContact, appointmentData);
      }
    }
  
    return appointmentData;
  }

  Future<void> _loadPatientHistory() async {
    try {
      // Update to use doctorId directly
      QuerySnapshot historySnapshot = await _firestore
          .collection('Records')
          .where('DoctorId', isEqualTo: doctorId)
          .get();

      List<Map<String, dynamic>> history = [];

      for (var doc in historySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Create a base record with all fields from the Records document
        Map<String, dynamic> historyRecord = {
          "name": data['patientName'] ?? "Unknown",
          "contact": data['patientContact'] ?? "N/A",
          "illness": data['diagnosis'] ?? "General Checkup",
          "date": data['date'] ?? "",
          "time": data['appointmentTime'] ?? "",
          "clinicName": data['clinicName'] ?? "",
          "location": data['location'] ?? "",
          "completedDate": data['completedDate'] ?? "",
          "notes": data['notes'] ?? "",
          "prescription": data['prescription'] ?? "",
        };

        // Get patient email (handle different formats if needed)
        String patientEmail = "";
        if (data['email'] != null) {
          patientEmail = data['email'].toString().replaceAll('/Patient/profile', '');
          historyRecord["patientEmail"] = patientEmail;
        }

        // Try to get additional patient details if not already in Records
        if (patientEmail.isNotEmpty && (historyRecord["name"] == "Unknown" || historyRecord["contact"] == "N/A")) {
          try {
            QuerySnapshot querySnapshot = await _firestore
              .collection('Patient')
              .where('email', isEqualTo: patientEmail)
              .limit(1)
              .get();

            if (querySnapshot.docs.isNotEmpty) {
              Map<String, dynamic> patientData = querySnapshot.docs.first.data() as Map<String, dynamic>;

              // Only update if data is missing
              if (historyRecord["name"] == "Unknown" && patientData['name'] != null) {
                historyRecord["name"] = patientData['name'];
              }

              if (historyRecord["contact"] == "N/A" && patientData['contactNumber No.'] != null) {
                historyRecord["contact"] = patientData['contactNumber No.'].toString();
              } else if (historyRecord["contact"] == "N/A" && patientData['phone'] != null) {
                historyRecord["contact"] = patientData['phone'].toString();
              }
            }
          } catch (e) {
            print("Error fetching additional patient data: $e");
          }
        }

        history.add(historyRecord);
      }

      setState(() {
        patientHistory = history;
      });
    } catch (e) {
      print("Error loading patient history: $e");
      print(StackTrace.current);
    }
  }
  // Helper method to fetch patient details by email
  Future<void> _fetchPatientDetails(String patientEmail, Map<String, dynamic> appointmentData) async {
    try {
      bool patientFound = false;

      // Try multiple paths to find patient data
      List<Future<QuerySnapshot>> patientQueries = [
        _firestore.collection('Patient')
            .where('email', isEqualTo: patientEmail)
            .limit(1)
            .get(),

        _firestore.collection('patients')
            .where('email', isEqualTo: patientEmail)
            .limit(1)
            .get(),

        // Also try with case insensitive email
        _firestore.collection('Patient')
            .where('email', isEqualTo: patientEmail.toLowerCase())
            .limit(1)
            .get(),

        _firestore.collection('patients')
            .where('email', isEqualTo: patientEmail.toLowerCase())
            .limit(1)
            .get(),

        // Try users collection
        _firestore.collection('users')
            .where('email', isEqualTo: patientEmail)
            .limit(1)
            .get(),
      ];

      for (var patientQueryFuture in patientQueries) {
        try {
          QuerySnapshot patientSnapshot = await patientQueryFuture;

          if (patientSnapshot.docs.isNotEmpty) {
            DocumentSnapshot patientDoc = patientSnapshot.docs.first;
            Map<String, dynamic> patientData = patientDoc.data() as Map<String, dynamic>;

            _extractAndPopulatePatientData(patientData, appointmentData);
            patientFound = true;
            print("Found patient info: ${appointmentData["name"]}");
            break;  // Exit loop once we find patient data
          }
        } catch (e) {
          print("Error in one patient query method: $e");
          // Continue to next method
        }
      }

      // If we still don't have patient info, try direct lookup with the patient's email
      if (!patientFound) {
        try {
          DocumentSnapshot directPatientDoc = await _firestore.collection('Patient').doc(patientEmail).get();
          if (directPatientDoc.exists) {
            Map<String, dynamic> patientData = directPatientDoc.data() as Map<String, dynamic>;
            _extractAndPopulatePatientData(patientData, appointmentData);
            print("Found patient via direct doc lookup: ${appointmentData["name"]}");
          }
        } catch (e) {
          print("Error in direct patient doc lookup: $e");
        }
      }
    } catch (e) {
      print("Error fetching patient data by email: $e");
      print(StackTrace.current);
    }
  }

  // Helper method to fetch patient details by contact number
  Future<void> _fetchPatientDetailsByContact(String contactNumber, Map<String, dynamic> appointmentData) async {
    try {
      // Try multiple paths to find patient data by contact
      List<Future<QuerySnapshot>> patientQueries = [
        _firestore.collection('Patient')
            .where('contactNumber No.', isEqualTo: contactNumber)
            .limit(1)
            .get(),

        _firestore.collection('Patient')
            .where('phoneNumber', isEqualTo: contactNumber)
            .limit(1)
            .get(),

        _firestore.collection('Patient')
            .where('phone', isEqualTo: contactNumber)
            .limit(1)
            .get(),

        _firestore.collection('Patient')
            .where('contact', isEqualTo: contactNumber)
            .limit(1)
            .get(),

        _firestore.collection('patients')
            .where('phoneNumber', isEqualTo: contactNumber)
            .limit(1)
            .get(),

        _firestore.collection('patients')
            .where('phone', isEqualTo: contactNumber)
            .limit(1)
            .get(),
      ];

      for (var patientQueryFuture in patientQueries) {
        try {
          QuerySnapshot patientSnapshot = await patientQueryFuture;

          if (patientSnapshot.docs.isNotEmpty) {
            Map<String, dynamic> patientData = patientSnapshot.docs.first.data() as Map<String, dynamic>;
            _extractAndPopulatePatientData(patientData, appointmentData);
            print("Found patient via contact number: ${appointmentData["name"]}");
            break;  // Exit loop once we find patient data
          }
        } catch (e) {
          print("Error in patient contact query method: $e");
          // Continue to next method
        }
      }
    } catch (e) {
      print("Error fetching patient data by contact: $e");
    }
  }

  // Helper to extract all patient data fields and put them in the appointment data
  void _extractAndPopulatePatientData(Map<String, dynamic> patientData, Map<String, dynamic> appointmentData) {
    // Basic patient info
    String patientName = (patientData['name'] ?? 
                        patientData['fullName'] ?? 
                        patientData['Name'] ?? 
                        appointmentData["name"]).toString();
                        
    String patientContact = (patientData['contactNumber No.'] ?? 
                          patientData['phone'] ?? 
                          patientData['phoneNumber'] ?? 
                          patientData['contact'] ?? 
                          patientData['contactNo'] ?? 
                          appointmentData["contact"]).toString();
    
    // Update basic info
    appointmentData["name"] = patientName;
    appointmentData["contact"] = patientContact;
    
    // Extract and add additional patient information
    appointmentData["patientData"] = {};
    
    // Age/birthdate information
    if (patientData['age'] != null) {
      appointmentData["patientData"]["age"] = patientData['age'];
    }
    
    if (patientData['dateOfBirth'] != null || patientData['dob'] != null) {
      appointmentData["patientData"]["dob"] = patientData['dateOfBirth'] ?? patientData['dob'];
    }
    
    // Gender information
    if (patientData['gender'] != null) {
      appointmentData["patientData"]["gender"] = patientData['gender'];
    }
    
    // Address information
    String address = (patientData['address'] ?? 
                    patientData['Address'] ?? '').toString();
                    
    if (address.isNotEmpty) {
      appointmentData["patientData"]["address"] = address;
    }
    
    // Any available medical information
    if (patientData['bloodGroup'] != null) {
      appointmentData["patientData"]["bloodGroup"] = patientData['bloodGroup'];
    }
    
    if (patientData['allergies'] != null) {
      appointmentData["patientData"]["allergies"] = patientData['allergies'];
    }
    
    if (patientData['medicalHistory'] != null) {
      appointmentData["patientData"]["medicalHistory"] = patientData['medicalHistory'];
    }
    
    // Secondary contact information
    if (patientData['emergencyContact'] != null) {
      appointmentData["patientData"]["emergencyContact"] = patientData['emergencyContact'];
    }
    
    if (patientData['email'] != null && appointmentData["patientEmail"] == '') {
      appointmentData["patientEmail"] = patientData['email'];
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
        // Get appointment ID
        String appointmentId = appointments[day]![index]["id"];
        print("Marking appointment $appointmentId as done");
  
        // Update Status field in Appointment collection
        try {
          await _firestore
              .collection('Appointment')
              .doc(appointmentId)
              .update({
                'Status': "Done"
              });
          print("Updated Status to Done in Appointment collection");
        } catch (e) {
          print("Error updating in Appointment collection: $e");
  
          // Try updating in Bookings/Appointment collection
          try {
            await _firestore
                .collection('Bookings')
                .doc('Appointment')
                .collection('Appointment')
                .doc(appointmentId)
                .update({
                  'Status': "Done"
                });
            print("Updated Status to Done in Bookings/Appointment collection");
          } catch (e2) {
            print("Error updating in Bookings/Appointment collection: $e2");
  
            // If both fail, we need to find where this appointment actually is
            print("Couldn't update appointment status. Please check the collection structure.");
          }
        }
  
        // Get patient details
        var patient = appointments[day]![index];
  
        // Create record in Records collection with more details
        await _firestore.collection('Records').add({
          'email': patient["patientEmail"],
          'FileName': '/xyz/file',
          'DoctorId': doctorId,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'diagnosis': patient["reason"] ?? 'General Checkup',
          'patientName': patient["name"],
          'patientContact': patient["contact"],
          'appointmentTime': patient["time"],
          'clinicName': patient["clinicName"] ?? '',
          'location': patient["location"] ?? '',
          'completedDate': DateFormat('MMM dd, yyyy').format(DateTime.now()),
          'status': "Done" // Add status field with "Done"
        });
        print("Added record to Records collection");
  
        setState(() {
          // Remove from appointments
          var completedAppointment = appointments[day]!.removeAt(index);
  
          // Add to history with extended information
          patientHistory.add({
            "name": completedAppointment["name"],
            "contact": completedAppointment["contact"],
            "illness": completedAppointment["reason"] ?? "General Checkup",
            "date": completedAppointment["date"],
            "time": completedAppointment["time"],
            "clinicName": completedAppointment["clinicName"] ?? "",
            "location": completedAppointment["location"] ?? "",
            "patientEmail": completedAppointment["patientEmail"] ?? "",
            "doctorContact": completedAppointment["doctorContact"] ?? "",
            "completedDate": DateFormat('MMM dd, yyyy').format(DateTime.now()),
            "status": "Done" // Add status field with "Done"
          });
        });
        print("Updated local state");
  
      } catch (e) {
        print("Error updating appointment status: $e");
        print(StackTrace.current); // Print stack trace for debugging
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
              refreshAppointments: _fetchAppointments,
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
  final Function refreshAppointments;
  
  HomeScreen({
    required this.appointments, 
    required this.toggleDone, 
    required this.doctorName,
    required this.refreshAppointments
  });

  void _showAppointmentDetails(BuildContext context, Map<String, dynamic> appointment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.7,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Appointment Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Divider(),
              _detailRow('Patient Name', appointment["name"]),
              _detailRow('Patient Contact', appointment["contact"]),
              _detailRow('Doctor Contact', appointment["doctorContact"] != "Unknown" ? appointment["doctorContact"] : "N/A"),
              _detailRow('Date', appointment["date"]),
              _detailRow('Time', appointment["time"]),
              _detailRow('Clinic', appointment["clinicName"] ?? "N/A"),
              _detailRow('Location', appointment["location"] ?? "N/A"),
              _detailRow('Specialization', appointment["specialization"] ?? "N/A"),
              _detailRow('Reason', appointment["reason"] ?? "General Checkup"),
              _detailRow('Booked On', appointment["bookedOn"] ?? "N/A"),

              // Show patient data if available
              if (appointment["patientData"] != null && appointment["patientData"] is Map) ...[
                SizedBox(height: 20),
                Text('Patient Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Divider(),
                if (appointment["patientData"]["age"] != null)
                  _detailRow('Age', appointment["patientData"]["age"].toString()),
                if (appointment["patientData"]["dob"] != null)
                  _detailRow('Date of Birth', appointment["patientData"]["dob"].toString()),
                if (appointment["patientData"]["gender"] != null)
                  _detailRow('Gender', appointment["patientData"]["gender"].toString()),
                if (appointment["patientData"]["bloodGroup"] != null)
                  _detailRow('Blood Group', appointment["patientData"]["bloodGroup"].toString()),
                if (appointment["patientData"]["allergies"] != null)
                  _detailRow('Allergies', appointment["patientData"]["allergies"].toString()),
              ],

              SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    int totalAppointments = appointments["Today"]!.length + 
                          appointments["Tomorrow"]!.length + 
                          appointments["Day After Tomorrow"]!.length;
                          
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('MedSlots', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => refreshAppointments(),
            tooltip: 'Refresh Appointments',
          )
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: RefreshIndicator(
          onRefresh: () async {
            await refreshAppointments();
          },
          child: totalAppointments == 0 ? 
            // Show a more helpful message when no appointments are found
            ListView(
              children: [
                Text('Welcome, $doctorName', 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                SizedBox(height: 16),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 48, color: Colors.teal),
                        SizedBox(height: 16),
                        Text(
                          "No Appointments Found",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "You have no scheduled appointments for the next three days. Pull down to refresh or tap the refresh button.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: Icon(Icons.refresh),
                          label: Text("Refresh"),
                          onPressed: () => refreshAppointments(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
            :
            // Normal display when appointments are found
            ListView(
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
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: ListTile(
                                  onTap: () => _showAppointmentDetails(context, appointment),
                                  title: Text(
                                    appointment["name"]!,
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 16, color: Colors.teal),
                                          SizedBox(width: 4),
                                          Text('Time: ${appointment["time"]}'),
                                        ],
                                      ),
                                      SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.phone, size: 16, color: Colors.teal),
                                          SizedBox(width: 4),
                                          Text('Contact: ${appointment["contact"]}'),
                                        ],
                                      ),
                                      if (appointment["clinicName"] != null && 
                                          appointment["clinicName"].toString().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2.0),
                                          child: Row(
                                            children: [
                                              Icon(Icons.local_hospital, size: 16, color: Colors.teal),
                                              SizedBox(width: 4),
                                              Expanded(child: Text('Clinic: ${appointment["clinicName"]}')),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: day == "Today" ? 
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          appointment["done"] ? "Done" : "Pending",
                                          style: TextStyle(
                                            color: appointment["done"] ? Colors.green : Colors.orange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Checkbox(
                                          value: appointment["done"],
                                          onChanged: (value) => toggleDone(day, index, value),
                                          activeColor: Colors.teal,
                                        ),
                                      ],
                                    ) : 
                                    // For non-today appointments, just show a label
                                    Chip(
                                      label: Text("Upcoming"),
                                      backgroundColor: Colors.blue[100],
                                      labelStyle: TextStyle(color: Colors.blue[800]),
                                    ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      SizedBox(height: 16),
                    ],
                  );
                }).toList(),
              ],
            ),
        ),
      ),
    );
  }
}

class PatientHistoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> patientHistory;
  PatientHistoryScreen({required this.patientHistory});

  @override
  _PatientHistoryScreenState createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen> {
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredHistory = [];
  
  @override
  void initState() {
    super.initState();
    _filteredHistory = widget.patientHistory;
  }
  
  void _filterHistory(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredHistory = widget.patientHistory;
      } else {
        _filteredHistory = widget.patientHistory.where((patient) {
          return patient["name"].toString().toLowerCase().contains(_searchQuery) ||
                 patient["contact"].toString().toLowerCase().contains(_searchQuery) ||
                 patient["illness"].toString().toLowerCase().contains(_searchQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Patient History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: _filterHistory,
              decoration: InputDecoration(
                hintText: 'Search patients...',
                prefixIcon: Icon(Icons.search, color: Colors.teal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.teal),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.teal, width: 2),
                ),
              ),
            ),
          ),
          
          // History count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  'Total Records: ${_filteredHistory.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: Colors.teal[700]
                  ),
                ),
              ],
            ),
          ),
          
          // History list
          Expanded(
            child: _filteredHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? "No patient history available"
                              : "No results found for '$_searchQuery'",
                          style: TextStyle(
                            fontSize: 16, 
                            color: Colors.grey[700]
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredHistory.length,
                    itemBuilder: (context, index) {
                      final patient = _filteredHistory[index];
                      return _buildPatientHistoryCard(patient);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPatientHistoryCard(Map<String, dynamic> patient) {
    // Format date - if available
    String formattedDate = "N/A";
    if (patient.containsKey("date") && patient["date"] != null) {
      try {
        // Try to parse and format the date
        DateTime appointmentDate = DateTime.parse(patient["date"].toString());
        formattedDate = DateFormat('MMM dd, yyyy').format(appointmentDate);
      } catch (e) {
        // If parsing fails, use the original string
        formattedDate = patient["date"].toString();
      }
    } else if (patient.containsKey("completedDate") && patient["completedDate"] != null) {
      formattedDate = patient["completedDate"].toString();
    }
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.teal,
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(
          patient["name"] ?? "Unknown Patient",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.teal),
                SizedBox(width: 4),
                Text('Date: $formattedDate'),
              ],
            ),
            SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.medical_services, size: 14, color: Colors.teal),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Diagnosis: ${patient["illness"] ?? "General Checkup"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Completed',
            style: TextStyle(
              color: Colors.green[800],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        children: [
          // Expanded details section
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              children: [
                _detailRow('Patient Name', patient["name"] ?? "Unknown"),
                _detailRow('Contact Number', patient["contact"] ?? "N/A"),
                _detailRow('Diagnosis/Illness', patient["illness"] ?? "General Checkup"),
                _detailRow('Date', formattedDate),
                
                // Show additional details if available
                if (patient.containsKey("time"))
                  _detailRow('Time', patient["time"] ?? "N/A"),
                if (patient.containsKey("patientEmail"))
                  _detailRow('Email', patient["patientEmail"] ?? "N/A"),
                if (patient.containsKey("reason"))
                  _detailRow('Reason', patient["reason"] ?? "N/A"),
                if (patient.containsKey("clinicName"))
                  _detailRow('Clinic', patient["clinicName"] ?? "N/A"),
                if (patient.containsKey("location"))
                  _detailRow('Location', patient["location"] ?? "N/A"),
                if (patient.containsKey("doctorContact"))
                  _detailRow('Doctor Contact', patient["doctorContact"] ?? "N/A"),
                  
                // Show prescription or notes if available
                if (patient.containsKey("prescription") || patient.containsKey("notes"))
                  Divider(height: 24),
                  
                if (patient.containsKey("prescription"))
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Prescription:", style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(patient["prescription"] ?? ""),
                      ),
                    ],
                  ),
                  
                if (patient.containsKey("notes"))
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 12),
                      Text("Notes:", style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(patient["notes"] ?? ""),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
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
  bool isUploadingImage = false;
  
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

  // Improved image picking and upload
  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _getImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _getImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        
        // Check image size
        final fileSize = await imageFile.length();
        if (fileSize > 5 * 1024 * 1024) { // 5MB limit
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image is too large. Please select an image under 5MB.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        setState(() {
          _profileImage = imageFile;
          isUploadingImage = true;
        });
        
        await _uploadProfileImage(imageFile);
      }
    } catch (e) {
      print("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    if (widget.doctorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot upload image: Doctor ID is missing'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isUploadingImage = false;
      });
      return;
    }
    
    try {
      // Show upload progress indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(color: Colors.teal),
                SizedBox(width: 20),
                Text("Uploading image..."),
              ],
            ),
          );
        },
      );
      
      // Create image filename with timestamp to avoid cache issues
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = 'doctor_profiles/${widget.doctorId}_$timestamp.jpg';
      
      // Create upload task
      UploadTask uploadTask = _storage.ref(fileName).putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      });
      
      // Wait for upload to complete
      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadURL = await taskSnapshot.ref.getDownloadURL();
      
      // Close progress dialog
      Navigator.pop(context);
      
      // Update profile pic URL in Firestore
      await _firestore.collection('doctors').doc(widget.doctorId).update({
        'profile_picture': downloadURL,
      });
      
      setState(() {
        profileImageUrl = downloadURL;
        isUploadingImage = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile image updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      // Close progress dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      print("Error uploading image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      
      setState(() {
        isUploadingImage = false;
      });
    }
  }

  Future<void> _viewFullImage() async {
    if (profileImageUrl == null || profileImageUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No profile image available'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.all(15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text('Profile Image'),
                backgroundColor: Colors.teal,
                centerTitle: true,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.network(
                    profileImageUrl!,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / 
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.teal,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error, color: Colors.red, size: 50),
                            SizedBox(height: 10),
                            Text('Failed to load image'),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: isUploadingImage ? null : _viewFullImage,
                          onLongPress: isUploadingImage ? null : _pickImage,
                          child: Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.teal.shade300,
                                width: 3,
                              ),
                            ),
                            child: ClipOval(
                              child: isUploadingImage
                                ? Center(child: CircularProgressIndicator(color: Colors.teal))
                                : _getProfileImageWidget(),
                            ),
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
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 2),
                                  blurRadius: 6.0,
                                ),
                              ],
                            ),
                            child: GestureDetector(
                              onTap: isUploadingImage ? null : _pickImage,
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Tap to view, hold to change",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
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
        ElevatedButton.icon(
          icon: Icon(Icons.photo),
          label: Text("Update Profile Photo"),
          onPressed: isUploadingImage ? null : _pickImage,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 45),
            disabledBackgroundColor: Colors.grey,
          ),
        ),
        SizedBox(height: 15),
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
  
  // Improved profile image widget with error handling and loading
  Widget _getProfileImageWidget() {
    if (_profileImage != null) {
      return Image.file(
        _profileImage!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorImagePlaceholder();
        },
      );
    } else if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      return Image.network(
        profileImageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / 
                     loadingProgress.expectedTotalBytes!
                  : null,
              color: Colors.teal,
              strokeWidth: 2,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorImagePlaceholder();
        },
      );
    } else {
      return Container(
        color: Colors.grey.shade200,
        child: Icon(
          Icons.person,
          size: 50,
          color: Colors.grey.shade600,
        ),
      );
    }
  }
  
  Widget _buildErrorImagePlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            color: Colors.red,
            size: 30,
          ),
          SizedBox(height: 4),
          Text(
            "Error",
            style: TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}