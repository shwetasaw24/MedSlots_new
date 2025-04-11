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
  Map<String, Map<String, bool>> slotAvailability = {
    'Today': {},
    'Tomorrow': {},
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
      
      // Generate all potential 15-minute slots
      Map<String, List<String>> dayAvailability = await _getDoctorAvailability();
      
      // Get already booked appointments for both days
      Map<String, List<String>> bookedSlots = await _getBookedTimeSlots(todayFormatted, tomorrowFormatted);
      
      // Remove booked slots from available slots
      for (var date in ['Today', 'Tomorrow']) {
        for (var slot in dayAvailability[date] ?? []) {
          slotAvailability[date]![slot] = !(bookedSlots[date]?.contains(slot) ?? false);
        }
      }
      
      // Set available time slots for the initially selected date
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

  // Get doctor's availability hours and generate 15-min slots
  Future<Map<String, List<String>>> _getDoctorAvailability() async {
    Map<String, List<String>> result = {
      'Today': [],
      'Tomorrow': [],
    };
    
    try {
      // Get availability data from Firestore for the doctor
      Map<String, dynamic>? availabilityData = await _firebaseServices.getDoctorAvailability(widget.doctorName);
      
      if (availabilityData != null) {
        DateTime today = DateTime.now();
        String dayOfWeek = DateFormat('EEEE').format(today).toLowerCase();
        String tomorrowDayOfWeek = DateFormat('EEEE').format(today.add(Duration(days: 1))).toLowerCase();
        
        // Process today's availability
        String todayAvailability = availabilityData['currentAvailability'] ?? '';
        if (todayAvailability.isNotEmpty) {
          result['Today'] = _generateTimeSlots(todayAvailability);
        }
        
        // Process tomorrow's availability
        String tomorrowAvailability = availabilityData['tomorrowsAvailability'] ?? '';
        if (tomorrowAvailability.isNotEmpty) {
          result['Tomorrow'] = _generateTimeSlots(tomorrowAvailability);
        }
      }
    } catch (e) {
      print("Error fetching doctor availability: $e");
    }
    
    return result;
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
      }
    }
    
    return slots;
  }
  
  // Get already booked time slots
  Future<Map<String, List<String>>> _getBookedTimeSlots(String todayDate, String tomorrowDate) async {
    Map<String, List<String>> bookedSlots = {
      'Today': [],
      'Tomorrow': [],
    };
    
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
      
      for (var booking in todayBookings) {
        bookedSlots['Today']!.add(booking['TimeSlot']);
      }
      
      for (var booking in tomorrowBookings) {
        bookedSlots['Tomorrow']!.add(booking['TimeSlot']);
      }
    } catch (e) {
      print("Error fetching booked appointments: $e");
    }
    
    return bookedSlots;
  }
  
  // Update available time slots based on selected date
  void _updateAvailableTimeSlots() {
    setState(() {
      availableTimeSlots = [];
      
      // Get slots for selected date option that are available (not booked)
      slotAvailability[selectedDateOption]?.forEach((slot, isAvailable) {
        if (isAvailable) {
          availableTimeSlots.add(slot);
        }
      });
      
      // Clear selected slot if it's no longer available
      if (selectedTimeSlot != null && !availableTimeSlots.contains(selectedTimeSlot)) {
        selectedTimeSlot = null;
      }
      
      // Sort time slots chronologically
      availableTimeSlots.sort((a, b) {
        DateTime timeA = DateFormat('h:mm a').parse(a.split(' - ')[0]);
        DateTime timeB = DateFormat('h:mm a').parse(b.split(' - ')[0]);
        return timeA.compareTo(timeB);
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
                  
                  // Available time slots grid
                  availableTimeSlots.isEmpty
                    ? Center(
                        child: Text(
                          "No available time slots for ${selectedDateOption.toLowerCase()}",
                          style: TextStyle(fontSize: 16, color: Colors.red),
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
                    ? CircularProgressIndicator(color: Colors.teal)
                    : ElevatedButton(
                        onPressed: selectedTimeSlot == null
                            ? null
                            : _saveBookingDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                          disabledBackgroundColor: Colors.grey,
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