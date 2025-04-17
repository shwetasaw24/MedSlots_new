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

  DoctorDetailsScreen({
    required this.doctorName,
    required this.specialization,
    required this.clinicName,
    required this.availability,
    required this.contact,
    required this.location,
    required this.imageUrl,
    this.patientEmail,
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
  };
  Map<String, List<String>> bookedTimeSlots = {
    'Today': [],
    'Tomorrow': [],
  };

  @override
  void initState() {
    super.initState();
    _loadDoctorAvailability();
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
      String todayFormatted = DateFormat('yyyy-MM-dd').format(today);
      String tomorrowFormatted = DateFormat('yyyy-MM-dd').format(tomorrow);
      
      // Get doctor's regular availability and generate time slots
      await _fetchDoctorAvailability();
      
      // Get already booked appointments for both days
      await _fetchBookedAppointments(todayFormatted, tomorrowFormatted);
      
      // Update available time slots based on initial selection
      _updateAvailableTimeSlots();
    } catch (e) {
      print("Error loading doctor availability: $e");
      Fluttertoast.showToast(
        msg: "Error loading availability. Please try again.",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Fetch doctor's availability schedule from Firestore
  Future<void> _fetchDoctorAvailability() async {
    try {
      // Try to get availability data from Firestore using doctor's name
      Map<String, dynamic>? availabilityData = await _firebaseServices.getDoctorAvailability(widget.doctorName);
      
      if (availabilityData != null && availabilityData.isNotEmpty) {
        // Process today's availability
        DateTime today = DateTime.now();
        String dayOfWeek = DateFormat('EEEE').format(today).toLowerCase();
        String todayAvailability = '';
        
        // Check current day availability
        if (availabilityData.containsKey(dayOfWeek)) {
          todayAvailability = availabilityData[dayOfWeek];
        } else if (availabilityData.containsKey('currentAvailability')) {
          todayAvailability = availabilityData['currentAvailability'];
        } else {
          // Use the availability from widget if no specific data found
          todayAvailability = widget.availability;
        }
        
        // Process tomorrow's availability
        DateTime tomorrow = today.add(Duration(days: 1));
        String tomorrowDayOfWeek = DateFormat('EEEE').format(tomorrow).toLowerCase();
        String tomorrowAvailability = '';
        
        // Check tomorrow's day availability
        if (availabilityData.containsKey(tomorrowDayOfWeek)) {
          tomorrowAvailability = availabilityData[tomorrowDayOfWeek];
        } else if (availabilityData.containsKey('tomorrowsAvailability')) {
          tomorrowAvailability = availabilityData['tomorrowsAvailability'];
        } else {
          // Use the same availability as today if no specific data found
          tomorrowAvailability = todayAvailability;
        }
        
        // Generate time slots from availability strings
        allTimeSlots['Today'] = _generateTimeSlots(todayAvailability);
        allTimeSlots['Tomorrow'] = _generateTimeSlots(tomorrowAvailability);
      } else {
        // Fallback to using the availability from the widget
        allTimeSlots['Today'] = _generateTimeSlots(widget.availability);
        allTimeSlots['Tomorrow'] = _generateTimeSlots(widget.availability);
      }
    } catch (e) {
      print("Error fetching doctor availability: $e");
      // Fallback to using the availability from the widget
      allTimeSlots['Today'] = _generateTimeSlots(widget.availability);
      allTimeSlots['Tomorrow'] = _generateTimeSlots(widget.availability);
    }
  }
  
  // Generate 15-minute time slots from availability string
  List<String> _generateTimeSlots(String availabilityString) {
    List<String> slots = [];
    
    // Parse availability string (e.g. "9:00 AM - 5:00 PM")
    List<String> parts = availabilityString.split(' - ');
    if (parts.length == 2) {
      try {
        DateTime startTime = DateFormat('h:mm a').parse(parts[0]);
        DateTime endTime = DateFormat('h:mm a').parse(parts[1]);
        
        // Generate slots in 15-minute intervals
        DateTime currentSlot = startTime;
        while (currentSlot.isBefore(endTime)) {
          DateTime slotEnd = currentSlot.add(Duration(minutes: 15));
          if (!slotEnd.isAfter(endTime)) {
            String slot = "${DateFormat('h:mm a').format(currentSlot)} - ${DateFormat('h:mm a').format(slotEnd)}";
            slots.add(slot);
          }
          currentSlot = slotEnd;
        }
      } catch (e) {
        print("Error parsing time: $e");
        // If parsing fails, try with different format pattern
        try {
          // Try a different format if the first one fails
          DateTime startTime = DateFormat('hh:mm a').parse(parts[0]);
          DateTime endTime = DateFormat('hh:mm a').parse(parts[1]);
          
          // Generate slots in 15-minute intervals
          DateTime currentSlot = startTime;
          while (currentSlot.isBefore(endTime)) {
            DateTime slotEnd = currentSlot.add(Duration(minutes: 15));
            if (!slotEnd.isAfter(endTime)) {
              String slot = "${DateFormat('h:mm a').format(currentSlot)} - ${DateFormat('h:mm a').format(slotEnd)}";
              slots.add(slot);
            }
            currentSlot = slotEnd;
          }
        } catch (innerE) {
          print("Error parsing time with alternate format: $innerE");
        }
      }
    } else {
      // Handle if availability string is not in expected format
      print("Availability string not in expected format: $availabilityString");
    }
    
    return slots;
  }
  
  // Get already booked time slots
  Future<void> _fetchBookedAppointments(String todayDate, String tomorrowDate) async {
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
      
      setState(() {
        bookedTimeSlots['Today'] = todayBookings.map((booking) => booking['TimeSlot'] as String).toList();
        bookedTimeSlots['Tomorrow'] = tomorrowBookings.map((booking) => booking['TimeSlot'] as String).toList();
      });
    } catch (e) {
      print("Error fetching booked appointments: $e");
      // Initialize with empty lists if there's an error
      bookedTimeSlots['Today'] = [];
      bookedTimeSlots['Tomorrow'] = [];
    }
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
    });
  }

  Future<void> _saveBookingDetails() async {
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
    
    setState(() {
      isBooking = true;
    });
    
    try {
      // Calculate the actual date based on selected date option
      DateTime bookingDate = DateTime.now();
      if (selectedDateOption == 'Tomorrow') {
        bookingDate = bookingDate.add(Duration(days: 1));
      }
      
      // Format date to string
      String formattedDate = DateFormat('yyyy-MM-dd').format(bookingDate);
      
      // Prepare appointment data
      Map<String, dynamic> appointmentData = {
        'ClinicsName': widget.clinicName,
        'doctorName': widget.doctorName,
        'TimeSlot': selectedTimeSlot,
        'date': formattedDate,
        'Status': 'Pending',
        'specialization': widget.specialization,
        'bookedOn': DateTime.now().toIso8601String(),
      };
      
      // Save to Firestore
      await _firebaseServices.bookAppointment(widget.patientEmail!, appointmentData);
      
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
        actions: [
          IconButton(
            icon: Icon(Icons.notifications),
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
                    "Selected Date: ${DateFormat('yyyy-MM-dd').format(selectedDateOption == 'Today' ? DateTime.now() : DateTime.now().add(Duration(days: 1)))}",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Show availability status for today and tomorrow
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
                  
                  // Available time slots grid
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
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: availableTimeSlots.length,
                        itemBuilder: (context, index) {
                          String slot = availableTimeSlots[index];
                          bool isSelected = selectedTimeSlot == slot;
                          
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedTimeSlot = slot;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.teal : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? Colors.teal.shade800 : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: Colors.teal.withOpacity(0.3),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: Offset(0, 2),
                                  )
                                ] : null,
                              ),
                              child: Center(
                                child: Text(
                                  slot,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.black,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
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