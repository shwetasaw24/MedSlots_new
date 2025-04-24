import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AppointmentHistoryScreen extends StatefulWidget {
  final String patientEmail;
  final bool recentOnly;

  AppointmentHistoryScreen({
    required this.patientEmail,
    this.recentOnly = false,
  });

  @override
  _AppointmentHistoryScreenState createState() => _AppointmentHistoryScreenState();
}

class _AppointmentHistoryScreenState extends State<AppointmentHistoryScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> appointments = [];
  
  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  // Convert time string to DateTime for proper sorting
  DateTime _parseTimeSlot(String timeSlot) {
    try {
      // Extract start time from format like "3:45 PM - 4:00 PM"
      final parts = timeSlot.split(' - ');
      if (parts.isEmpty) return DateTime(2000); // Default for error cases
      
      final startTime = parts[0];
      // Create a dummy date with the time for comparison
      return DateFormat('h:mm a').parse(startTime);
    } catch (e) {
      print('Error parsing time slot: $e - Using raw string for comparison');
      // Return a placeholder DateTime for sorting
      return DateTime(2000);
    }
  }

  // Get day of week from a DateTime
  String _getDayOfWeek(DateTime date) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  Future<void> _fetchAppointments() async {
    try {
      setState(() {
        isLoading = true;
      });

      print('Fetching appointments for ${widget.patientEmail}');

      // Base query to get appointments for this patient
      QuerySnapshot appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientEmail', isEqualTo: widget.patientEmail)
          .get();
      
      print('Found ${appointmentsSnapshot.docs.length} appointments');
      
      List<Map<String, dynamic>> fetchedAppointments = [];
      
      for (var doc in appointmentsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String appointmentId = doc.id;
        
        print('Processing appointment: ${doc.id}');
        print('Appointment data: $data');
        
        // Parse appointment date
        DateTime parsedAppointmentDate = DateTime.now();
        String appointmentDate = "Unknown";
        String dayOfWeek = "Unknown";
        
        if (data['date'] != null) {
          try {
            if (data['date'] is Timestamp) {
              parsedAppointmentDate = (data['date'] as Timestamp).toDate();
            } else if (data['date'] is String) {
              parsedAppointmentDate = DateFormat('yyyy-MM-dd').parse(data['date']);
            }
            appointmentDate = DateFormat('MMM dd, yyyy').format(parsedAppointmentDate);
            dayOfWeek = _getDayOfWeek(parsedAppointmentDate);
          } catch (e) {
            print('Error parsing date: $e');
            appointmentDate = data['date'].toString();
          }
        }
        
        // Parse booking date
        String bookingDate = "Unknown";
        if (data['bookedOn'] != null) {
          try {
            if (data['bookedOn'] is Timestamp) {
              DateTime dateTime = (data['bookedOn'] as Timestamp).toDate();
              bookingDate = DateFormat('MMM dd, yyyy').format(dateTime);
            } else if (data['bookedOn'] is String) {
              // Try to parse the string date
              bookingDate = data['bookedOn'];
            }
          } catch (e) {
            print('Error parsing booking date: $e');
            bookingDate = data['bookedOn'].toString();
          }
        }
        
        // Get appointment time
        String appointmentTime = "Unknown";
        DateTime parsedTimeSlot = DateTime(2000);
        if (data['TimeSlot'] != null) {
          appointmentTime = data['TimeSlot'].toString();
          try {
            parsedTimeSlot = _parseTimeSlot(appointmentTime);
          } catch (e) {
            print('Error parsing time slot: $e');
          }
        }
        
        // Add to our list
        fetchedAppointments.add({
          'id': appointmentId,
          'doctorName': data['doctorName'] ?? 'Unknown Doctor',
          'doctorEmail': data['doctorEmail'] ?? '',
          'clinicName': data['ClinicsName'] ?? 'Unknown Clinic',
          'appointmentDate': appointmentDate,
          'parsedAppointmentDate': parsedAppointmentDate,
          'dayOfWeek': dayOfWeek,
          'appointmentTime': appointmentTime,
          'parsedTimeSlot': parsedTimeSlot,
          'bookingDate': bookingDate,
          'status': data['Status'] ?? 'Scheduled',
          'notes': data['notes'] ?? '',
          'patientName': data['patientName'] ?? '',
          'specialization': data['specialization'] ?? '',
          'reasonForVisit': data['reasonForVisit'] ?? 'Consultation',
          'location': data['location'] ?? '',
          'rawData': data, // Keep the raw data for any additional info needed
        });
      }
      
      // Debug - Print appointments found
      print('Processed ${fetchedAppointments.length} appointments');
      
      // Sort appointments by date first, then by time slot
      fetchedAppointments.sort((a, b) {
        // First compare dates
        int dateComparison = a['parsedAppointmentDate'].compareTo(b['parsedAppointmentDate']);
        if (dateComparison != 0) return dateComparison;
        
        // If dates are equal, compare time slots
        return a['parsedTimeSlot'].compareTo(b['parsedTimeSlot']);
      });
      
      setState(() {
        appointments = fetchedAppointments;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching appointments: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.recentOnly ? 'Recent Appointments' : 'Appointment History',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.teal,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchAppointments,
            tooltip: 'Refresh appointments',
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.teal))
          : appointments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        widget.recentOnly
                            ? 'No recent appointments found'
                            : 'No appointment history found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _fetchAppointments,
                        icon: Icon(Icons.refresh),
                        label: Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : _buildAppointmentsList(),
    );
  }

  Widget _buildAppointmentsList() {
    // Group appointments by date
    Map<String, List<Map<String, dynamic>>> groupedAppointments = {};
    
    for (var appointment in appointments) {
      String dateKey = appointment['appointmentDate'];
      if (!groupedAppointments.containsKey(dateKey)) {
        groupedAppointments[dateKey] = [];
      }
      groupedAppointments[dateKey]!.add(appointment);
    }
    
    // Create a list of date keys sorted by date
    List<String> sortedDates = groupedAppointments.keys.toList()
      ..sort((a, b) {
        try {
          DateTime dateA = DateFormat('MMM dd, yyyy').parse(a);
          DateTime dateB = DateFormat('MMM dd, yyyy').parse(b);
          return dateA.compareTo(dateB);
        } catch (e) {
          return a.compareTo(b); // Fallback to string comparison
        }
      });
    
    return ListView.builder(
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        String dateKey = sortedDates[index];
        List<Map<String, dynamic>> dateAppointments = groupedAppointments[dateKey]!;
        String dayOfWeek = dateAppointments.first['dayOfWeek'];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.teal.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.teal),
                  SizedBox(width: 8),
                  Text(
                    '$dayOfWeek, $dateKey',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            
            // Appointments for this date
            ...dateAppointments.map((appointment) {
              // Determine appointment status color
              Color statusColor;
              switch(appointment['status'].toString().toLowerCase()) {
                case 'completed':
                  statusColor = Colors.green;
                  break;
                case 'cancelled':
                  statusColor = Colors.red;
                  break;
                case 'rescheduled':
                  statusColor = Colors.orange;
                  break;
                case 'pending':
                  statusColor = Colors.blue;
                  break;
                default:
                  statusColor = Colors.blue;
              }
              
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.teal.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    _showAppointmentDetails(context, appointment);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                appointment['doctorName'],
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(
                                appointment['status'],
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (appointment['specialization'].isNotEmpty)
                          Text(
                            appointment['specialization'],
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                        SizedBox(height: 8),
                        Text(
                          appointment['clinicName'],
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                        ),
                        if (appointment['location'].isNotEmpty)
                          Text(
                            appointment['location'],
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.teal),
                            SizedBox(width: 4),
                            Text(
                              appointment['appointmentTime'],
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.teal.shade900,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        if (appointment['reasonForVisit'].isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.medical_services_outlined, size: 16, color: Colors.grey),
                              SizedBox(width: 4),
                              Text(
                                appointment['reasonForVisit'],
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Booked on: ${appointment['bookingDate']}',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  // Method to show detailed appointment information in a dialog
  void _showAppointmentDetails(BuildContext context, Map<String, dynamic> appointment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with appointment status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Appointment Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.teal.shade700,
                      ),
                    ),
                    _buildStatusBadge(appointment['status']),
                  ],
                ),
                SizedBox(height: 20),
                
                // Doctor and clinic information
                _buildDetailItem('Doctor', appointment['doctorName'], Icons.person),
                if (appointment['specialization'].isNotEmpty)
                  _buildDetailItem('Specialization', appointment['specialization'], Icons.medical_services),
                _buildDetailItem('Clinic', appointment['clinicName'], Icons.local_hospital),
                if (appointment['location'].isNotEmpty)
                  _buildDetailItem('Location', appointment['location'], Icons.location_on),
                
                // Appointment timing
                _buildDetailItem(
                  'Date', 
                  '${appointment['dayOfWeek']}, ${appointment['appointmentDate']}',
                  Icons.event,
                ),
                _buildDetailItem('Time', appointment['appointmentTime'], Icons.access_time),
                
                // Reason and other details
                if (appointment['reasonForVisit'].isNotEmpty)
                  _buildDetailItem('Reason', appointment['reasonForVisit'], Icons.medical_services),
                if (appointment['notes'].isNotEmpty)
                  _buildDetailItem('Notes', appointment['notes'], Icons.note),
                  
                _buildDetailItem('Booking Date', appointment['bookingDate'], Icons.calendar_today),
                
                // Add any special instructions if available
                if (appointment['rawData'] != null && 
                    appointment['rawData']['specialInstructions'] != null)
                  _buildDetailItem(
                    'Special Instructions', 
                    appointment['rawData']['specialInstructions'], 
                    Icons.info_outline
                  ),
                
                SizedBox(height: 24),
                
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Close',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    if (appointment['status'].toString().toLowerCase() == 'pending')
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          // Handle rescheduling or other actions
                          Navigator.pop(context);
                          // You can navigate to reschedule screen here
                        },
                        child: Text('Manage Appointment'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to build detail items
  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.teal),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build status badge
  Widget _buildStatusBadge(String status) {
    Color statusColor;
    switch(status.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      case 'rescheduled':
        statusColor = Colors.orange;
        break;
      case 'pending':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.blue;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}