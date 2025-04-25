import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_medslots/services/firestorestore_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class DoctorDetailsScreen extends StatefulWidget {
  final String doctorName;
  final String specialization;
  final String clinicName;
  final String availability;
  final String contact;
  final String location;
  final String imageUrl;
  final String? patientEmail;
  final String tomorrowAvailability;
  final String dayAfterAvailability;
  final bool bookingEnabled;
  final String doctorEmail;

  DoctorDetailsScreen({
    required this.doctorName,
    required this.specialization,
    required this.clinicName,
    required this.availability,
    required this.contact,
    required this.location,
    required this.imageUrl,
    this.patientEmail,
    this.tomorrowAvailability = 'Not specified',
    this.dayAfterAvailability = 'Not specified',
    this.bookingEnabled = true,
    this.doctorEmail = '',
  });

  @override
  _DoctorDetailsScreenState createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  final FirebaseServices _firebaseServices = FirebaseServices();
  bool isBooking = false;
  bool isLoading = true;
  String? selectedTimeSlot;
  
  // Date selection options
  final List<String> dateOptions = ['Today', 'Tomorrow'];
  String selectedDateOption = 'Today';
  DateTime selectedDate = DateTime.now();
  
  // Available time slots based on date
  List<String> availableTimeSlots = [];
  Map<String, List<String>> allTimeSlots = {
    'Today': [],
    'Tomorrow': [],
    'Day After': [], // Added Day After to initialize properly
  };
  Map<String, List<String>> bookedTimeSlots = {
    'Today': [],
    'Tomorrow': [],
    'Day After': [], // Added Day After to initialize properly
  };

  // For storing patient contact number
  TextEditingController patientContactController = TextEditingController();
  
  // Fix: Initialize patientContact properly
  String patientContact = '';

  @override
  void initState() {
    super.initState();
    _loadDoctorAvailability();
    _loadPatientContact(); // Added to load patient contact if available
  }
  
  // New method to load patient contact info
  Future<void> _loadPatientContact() async {
    try {
      // Try to get the user's contact from Firestore based on email
      if (widget.patientEmail != null && widget.patientEmail!.isNotEmpty) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.patientEmail)
            .get();
        
        if (userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>?;
          if (userData != null && userData.containsKey('phone')) {
            setState(() {
              patientContact = userData['phone'] ?? '';
              patientContactController.text = patientContact;
            });
            print("Loaded patient contact: $patientContact");
          }
        }
      }
    } catch (e) {
      print("Error loading patient contact: $e");
    }
  }
  
  // Load doctor's availability for today and tomorrow
  Future<void> _loadDoctorAvailability() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      // Get today and tomorrow's dates formatted
      DateTime today = DateTime.now();
      DateTime tomorrow = today.add(Duration(days: 1));
      DateTime dayAfterTomorrow = today.add(Duration(days: 2));
      
      String todayFormatted = DateFormat('yyyy-MM-dd').format(today);
      String tomorrowFormatted = DateFormat('yyyy-MM-dd').format(tomorrow);
      String dayAfterFormatted = DateFormat('yyyy-MM-dd').format(dayAfterTomorrow);
      
      // Check if booking is enabled
      if (!widget.bookingEnabled) {
        setState(() {
          isLoading = false;
        });
        
        Fluttertoast.showToast(
          msg: "This doctor is not accepting bookings at the moment.",
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }
      
      // Explicitly try to fetch doctor data directly from Firestore as a fallback
      try {
        print("Fetching doctor data for: ${widget.doctorName}");
        QuerySnapshot doctorQuery = await FirebaseFirestore.instance
            .collection('doctors')
            .where('fullName', isEqualTo: widget.doctorName)
            .limit(1)
            .get();
        
        if (doctorQuery.docs.isNotEmpty) {
          Map<String, dynamic> doctorData = doctorQuery.docs.first.data() as Map<String, dynamic>;
          print("Directly fetched doctor data: ${doctorData.toString()}");
          
          // Extract availability data
          String todayAvail = _getAvailabilityFromData(doctorData, 'currentAvailability', widget.availability);
          String tomorrowAvail = _getAvailabilityFromData(doctorData, 'tommorowsAvailability', widget.tomorrowAvailability);
          String dayAfterAvail = _getAvailabilityFromData(doctorData, 'Day After Tommorows Availaibility', widget.dayAfterAvailability);
          
          print("Today's availability: $todayAvail");
          print("Tomorrow's availability: $tomorrowAvail");
          print("Day after's availability: $dayAfterAvail");
          
          allTimeSlots['Today'] = _generateTimeSlots(todayAvail);
          allTimeSlots['Tomorrow'] = _generateTimeSlots(tomorrowAvail);
          
          // Add day after option if available
          if (dayAfterAvail != 'Not specified' && dayAfterAvail != 'Not Set') {
            if (!dateOptions.contains('Day After')) {
              dateOptions.add('Day After');
            }
            allTimeSlots['Day After'] = _generateTimeSlots(dayAfterAvail);
          }
        } else {
          print("Doctor not found in database, using widget parameters");
          // Fall back to widget parameters if doctor not found
          allTimeSlots['Today'] = _generateTimeSlots(widget.availability);
          allTimeSlots['Tomorrow'] = _generateTimeSlots(widget.tomorrowAvailability);
          allTimeSlots['Day After'] = _generateTimeSlots(widget.dayAfterAvailability);
          
          // Add day after option if available
          if (widget.dayAfterAvailability != 'Not specified' && widget.dayAfterAvailability != 'Not Set') {
            if (!dateOptions.contains('Day After')) {
              dateOptions.add('Day After');
            }
          }
        }
      } catch (e) {
        print("Error during direct doctor fetch: $e");
        // Fall back to widget parameters if there's an error
        allTimeSlots['Today'] = _generateTimeSlots(widget.availability);
        allTimeSlots['Tomorrow'] = _generateTimeSlots(widget.tomorrowAvailability);
        allTimeSlots['Day After'] = _generateTimeSlots(widget.dayAfterAvailability);
        
        // Add day after option if available
        if (widget.dayAfterAvailability != 'Not specified' && widget.dayAfterAvailability != 'Not Set') {
          if (!dateOptions.contains('Day After')) {
            dateOptions.add('Day After');
          }
        }
      }
      
      // Get already booked appointments for the dates
      await _fetchBookedAppointments(todayFormatted, tomorrowFormatted, dayAfterFormatted);
      
      // Update available time slots based on initial selection
      _updateAvailableTimeSlots();
      
    } catch (e) {
      print("Error loading doctor availability: $e");
      Fluttertoast.showToast(
        msg: "Error loading availability. Please try again.",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      
      // Still provide some default time slots to avoid empty UI
      allTimeSlots['Today'] = _generateTimeSlots("10:00 AM - 5:00 PM");
      allTimeSlots['Tomorrow'] = _generateTimeSlots("10:00 AM - 5:00 PM");
      _updateAvailableTimeSlots();
      
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
  
  // Helper method to extract availability from doctor data
  String _getAvailabilityFromData(Map<String, dynamic> data, String key, String fallback) {
    if (data.containsKey(key) && data[key] != null && data[key].toString().isNotEmpty) {
      return data[key].toString();
    }
    return fallback;
  }
  
  // Fetch booked appointments from Firestore
  Future<void> _fetchBookedAppointments(String todayDate, String tomorrowDate, String dayAfterDate) async {
    try {
      print("Fetching booked appointments for doctor: ${widget.doctorName}");
      
      // Initialize the booked slots map for day after tomorrow
      bookedTimeSlots['Today'] = [];
      bookedTimeSlots['Tomorrow'] = [];
      bookedTimeSlots['Day After'] = [];
      
      // Get bookings for today
      QuerySnapshot todaySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorName', isEqualTo: widget.doctorName)
          .where('date', isEqualTo: todayDate)
          .get();
      
      // Get bookings for tomorrow
      QuerySnapshot tomorrowSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorName', isEqualTo: widget.doctorName)
          .where('date', isEqualTo: tomorrowDate)
          .get();
      
      // Get bookings for day after tomorrow
      QuerySnapshot dayAfterSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorName', isEqualTo: widget.doctorName)
          .where('date', isEqualTo: dayAfterDate)
          .get();
      
      List<String> todaySlots = todaySnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['TimeSlot'] as String)
          .toList();
      
      List<String> tomorrowSlots = tomorrowSnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['TimeSlot'] as String)
          .toList();
      
      List<String> dayAfterSlots = dayAfterSnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['TimeSlot'] as String)
          .toList();
      
      print("Today's booked slots: $todaySlots");
      print("Tomorrow's booked slots: $tomorrowSlots");
      print("Day after's booked slots: $dayAfterSlots");
      
      setState(() {
        bookedTimeSlots['Today'] = todaySlots;
        bookedTimeSlots['Tomorrow'] = tomorrowSlots;
        bookedTimeSlots['Day After'] = dayAfterSlots;
      });
    } catch (e) {
      print("Error fetching booked appointments directly from Firestore: $e");
      
      // Try fallback to FirebaseServices method
      try {
        // Get bookings for today
        List<Map<String, dynamic>> todayBookings = await _firebaseServices.getBookedAppointments(
          widget.doctorName,
          todayDate
        );
        
        // Get bookings for tomorrow
        List<Map<String, dynamic>> tomorrowBookings = await _firebaseServices.getBookedAppointments(
          widget.doctorName, 
          tomorrowDate
        );
        
        // Get bookings for day after tomorrow
        List<Map<String, dynamic>> dayAfterBookings = await _firebaseServices.getBookedAppointments(
          widget.doctorName,
          dayAfterDate
        );
        
        setState(() {
          bookedTimeSlots['Today'] = todayBookings.map((booking) => booking['TimeSlot'] as String).toList();
          bookedTimeSlots['Tomorrow'] = tomorrowBookings.map((booking) => booking['TimeSlot'] as String).toList();
          bookedTimeSlots['Day After'] = dayAfterBookings.map((booking) => booking['TimeSlot'] as String).toList();
        });
      } catch (fallbackError) {
        print("Error in fallback method for fetching booked appointments: $fallbackError");
        // Initialize with empty lists if there's an error
        bookedTimeSlots['Today'] = [];
        bookedTimeSlots['Tomorrow'] = [];
        bookedTimeSlots['Day After'] = [];
      }
    }
  }
  
  // Generate 15-minute time slots from availability string
  List<String> _generateTimeSlots(String availabilityString) {
    List<String> slots = [];
    
    // Print for debugging
    print("Generating time slots from: '$availabilityString'");
    
    if (availabilityString == 'Not specified' || availabilityString == 'Not Set') {
      return slots; // Return empty list if no availability specified
    }
    
    // Try to extract time range from availability string
    try {
      // Common format checks
      List<String> parts;
      
      // Try different patterns
      if (availabilityString.contains(' - ')) {
        parts = availabilityString.split(' - ');
      } else if (availabilityString.contains('-')) {
        parts = availabilityString.split('-');
      } else if (availabilityString.contains('to')) {
        parts = availabilityString.split('to');
      } else {
        // Can't parse, return empty list
        print("Can't parse availability string format: $availabilityString");
        return slots;
      }
      
      if (parts.length >= 2) {
        String startTimeStr = parts[0].trim();
        String endTimeStr = parts[1].trim();
        
        print("Start time string: $startTimeStr, End time string: $endTimeStr");
        
        // Try to parse start and end times with different formats
        DateTime? startTime;
        DateTime? endTime;
        
        // Try various date formats
        List<String> timeFormats = ['h:mm a', 'hh:mm a', 'h:mma', 'hh:mma', 'HH:mm'];
        
        for (String format in timeFormats) {
          try {
            startTime = DateFormat(format).parse(startTimeStr);
            print("Parsed start time with format $format: $startTime");
            break;
          } catch (e) {
            // Try next format
          }
        }
        
        for (String format in timeFormats) {
          try {
            endTime = DateFormat(format).parse(endTimeStr);
            print("Parsed end time with format $format: $endTime");
            break;
          } catch (e) {
            // Try next format
          }
        }
        
        // If parsing succeeded, generate slots
        if (startTime != null && endTime != null) {
          DateTime currentSlot = startTime;
          while (currentSlot.isBefore(endTime)) {
            DateTime slotEnd = currentSlot.add(Duration(minutes: 15));
            if (!slotEnd.isAfter(endTime)) {
              String slot = "${DateFormat('h:mm a').format(currentSlot)} - ${DateFormat('h:mm a').format(slotEnd)}";
              slots.add(slot);
            }
            currentSlot = slotEnd;
          }
        } else {
          print("Failed to parse times from: $startTimeStr and $endTimeStr");
        }
      }
    } catch (e) {
      print("Error generating time slots: $e");
    }
    
    // If still empty, provide some default time slots
    if (slots.isEmpty && availabilityString != 'Not specified' && availabilityString != 'Not Set') {
      print("Using default time slots as parsing failed");
      DateTime now = DateTime.now();
      DateTime baseTime = DateTime(now.year, now.month, now.day, 10, 0); // 10:00 AM
      DateTime endTime = DateTime(now.year, now.month, now.day, 17, 0);  // 5:00 PM
      
      DateTime currentSlot = baseTime;
      while (currentSlot.isBefore(endTime)) {
        DateTime slotEnd = currentSlot.add(Duration(minutes: 15));
        String slot = "${DateFormat('h:mm a').format(currentSlot)} - ${DateFormat('h:mm a').format(slotEnd)}";
        slots.add(slot);
        currentSlot = slotEnd;
      }
    }
    
    print("Generated ${slots.length} time slots");
    return slots;
  }
  
  // Update available time slots based on selected date
  void _updateAvailableTimeSlots() {
    setState(() {
      // Get all time slots for the selected date
      List<String> allSlots = allTimeSlots[selectedDateOption] ?? [];
      
      // Get booked slots for the selected date
      List<String> bookedSlots = bookedTimeSlots[selectedDateOption] ?? [];
      
      // Filter out booked slots
      availableTimeSlots = allSlots.where((slot) => !bookedSlots.contains(slot)).toList();
      
      // Clear selected slot if it's no longer available
      if (selectedTimeSlot != null && !availableTimeSlots.contains(selectedTimeSlot)) {
        selectedTimeSlot = null;
      }
      
      // Sort time slots chronologically
      availableTimeSlots.sort((a, b) {
        try {
          DateTime timeA = DateFormat('h:mm a').parse(a.split(' - ')[0]);
          DateTime timeB = DateFormat('h:mm a').parse(b.split(' - ')[0]);
          return timeA.compareTo(timeB);
        } catch (e) {
          return 0;
        }
      });
      
      print("Updated available time slots: $availableTimeSlots");
    });
  }

  Future<void> _saveBookingDetails() async {
    // Check if user is logged in
    if (widget.patientEmail == null || widget.patientEmail!.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please login to book an appointment",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    // Check if time slot is selected
    if (selectedTimeSlot == null) {
      Fluttertoast.showToast(
        msg: "Please select a time slot",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }
    
    // Fix: Get the contact number from the text controller
    patientContact = patientContactController.text.trim();
    
    // Check if patient contact is provided
    if (patientContact.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please enter your contact number",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      isBooking = true;
    });

    try {
      // Calculate the actual date based on selected date option
      DateTime bookingDate = DateTime.now();
      if (selectedDateOption == 'Tomorrow') {
        bookingDate = bookingDate.add(Duration(days: 1));
      } else if (selectedDateOption == 'Day After') {
        bookingDate = bookingDate.add(Duration(days: 2));
      }

      // Format date to string
      String formattedDate = DateFormat('yyyy-MM-dd').format(bookingDate);
      
      print("Booking appointment for doctor: ${widget.doctorName}");
      print("Patient email: ${widget.patientEmail}");
      print("Patient contact: $patientContact");
      print("Date: $formattedDate");
      print("Time slot: $selectedTimeSlot");

      // Prepare appointment data
      Map<String, dynamic> appointmentData = {
        'ClinicsName': widget.clinicName,
        'doctorName': widget.doctorName,
        'doctorEmail': widget.doctorEmail,
        'doctorContact': widget.contact,  // Doctor's contact information
        'patientContact': patientContact, // Patient's contact information
        'TimeSlot': selectedTimeSlot,
        'date': formattedDate,
        'Status': 'Booked',
        'specialization': widget.specialization,
        'bookedOn': DateTime.now().toIso8601String(),
        'location': widget.location,
        'patientEmail': widget.patientEmail,
      };

      print("Appointment data prepared: $appointmentData");

      // First, try to directly save to Firestore
      try {
        // Add the appointment to the 'appointments' collection
        DocumentReference appointmentRef = await FirebaseFirestore.instance
            .collection('appointments')
            .add(appointmentData);
            
        print("Appointment created with ID: ${appointmentRef.id}");
        
        // Also add to user's appointments subcollection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.patientEmail)
            .collection('myAppointments')
            .add(appointmentData);
            
        print("Appointment added to user's myAppointments collection");
        
        // Fix: Update the user's profile with the contact number if not already set
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.patientEmail)
            .set({
              'phone': patientContact
            }, SetOptions(merge: true));
            
        print("Updated user's contact information");
        
      } catch (directFirestoreError) {
        print("Error directly saving to Firestore: $directFirestoreError");
        
        // Fallback to the FirebaseServices method
        print("Trying fallback booking method...");
        await _firebaseServices.bookAppointment(widget.patientEmail!, appointmentData);
        
        // Try to update user's contact separately
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.patientEmail)
            .set({
              'phone': patientContact
            }, SetOptions(merge: true));
            
        print("Appointment booked via FirebaseServices");
      }

      // Add the booked slot to our local list to prevent double booking
      setState(() {
        bookedTimeSlots[selectedDateOption]!.add(selectedTimeSlot!);
        _updateAvailableTimeSlots();
      });

      // Save latest booking to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("latest_booking", "Appointment with Dr. ${widget.doctorName} on $formattedDate at $selectedTimeSlot");

      Fluttertoast.showToast(
        msg: "Appointment booked successfully for $selectedTimeSlot!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      // Navigate back after booking
      Navigator.pop(context);
    } catch (e) {
      print("Error booking appointment: $e");
      Fluttertoast.showToast(
        msg: "Failed to book appointment. Please try again.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        isBooking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Doctor Details"),
        backgroundColor: Colors.teal,
        
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: isLoading 
          ? Center(child: CircularProgressIndicator(color: Colors.teal))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: widget.imageUrl.startsWith('assets/') 
                      ? AssetImage(widget.imageUrl) as ImageProvider
                      : NetworkImage(widget.imageUrl),
                  ),
                  SizedBox(height: 20),
                  Text(widget.doctorName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(widget.specialization, style: TextStyle(fontSize: 18, color: Colors.grey[700])),
                  SizedBox(height: 10),
                  Text("${widget.clinicName}\nAvailability: ${widget.availability}\nContact: ${widget.contact}\nLocation: ${widget.location}",
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                  SizedBox(height: 20),
                  
                  // Date selection segmented button
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: dateOptions.map((dateOption) {
                              bool isSelected = selectedDateOption == dateOption;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedDateOption = dateOption;
                                      selectedTimeSlot = null;
                                      _updateAvailableTimeSlots();
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.teal : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      dateOption,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Show the selected date
                  Text(
                    "Selected Date: ${DateFormat('yyyy-MM-dd').format(
                      selectedDateOption == 'Today' 
                        ? DateTime.now() 
                        : selectedDateOption == 'Tomorrow'
                          ? DateTime.now().add(Duration(days: 1))
                          : DateTime.now().add(Duration(days: 2))
                    )}",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Contact number input field
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade300),
                    ),
                    child: TextField(
                      controller: patientContactController,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Enter your contact number",
                        prefixIcon: Icon(Icons.phone, color: Colors.teal),
                      ),
                      keyboardType: TextInputType.phone,
                      onChanged: (value) {
                        // Fix: Update patientContact directly when text changes
                        patientContact = value;
                      },
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Show availability status
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Available Time Slots",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                        ),
                        Text(
                          "${availableTimeSlots.length} slots available",
                          style: TextStyle(fontSize: 14, color: Colors.teal),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Time slot dropdown instead of grid
                  availableTimeSlots.isEmpty
                    ? Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.event_busy, color: Colors.red, size: 40),
                            SizedBox(height: 10),
                            Text(
                              "No available time slots for ${selectedDateOption.toLowerCase()}",
                              style: TextStyle(fontSize: 16, color: Colors.red.shade800),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedTimeSlot,
                            hint: Text("Select a time slot"),
                            icon: Icon(Icons.access_time, color: Colors.teal),
                            style: TextStyle(color: Colors.black, fontSize: 16),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedTimeSlot = newValue;
                              });
                            },
                            items: availableTimeSlots.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  
                  SizedBox(height: 30),
                  
                  isBooking 
                    ? Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: Colors.teal),
                            SizedBox(height: 10),
                            Text("Booking your appointment...", style: TextStyle(color: Colors.teal)),
                          ],
                        )
                      )
                    : ElevatedButton(
                        onPressed: selectedTimeSlot == null
                            ? null
                            : _saveBookingDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                          disabledBackgroundColor: Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 3,
                        ),
                        child: Text("Book Appointment", style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                ],
              ),
            ),
      ),
    );
  }
}                          