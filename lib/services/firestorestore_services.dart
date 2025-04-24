import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseServices {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Patient profile methods
  Future<void> savePatientProfile(String userId, Map<String, dynamic> userData) async {
    try {
      await _firestore.collection('Patient').doc(userId).set(userData);
    } catch (e) {
      print('Error saving patient profile: $e');
      throw e;
    }
  }
  
  Future<Map<String, dynamic>?> getPatientProfile(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('Patient').doc(userId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting patient profile: $e');
      throw e;
    }
  }

  // Doctor lookup methods - with standardized field names
  Future<Map<String, dynamic>?> getDoctorByName(String doctorName) async {
    try {
      // Try different possible field names and collections
      List<QuerySnapshot> queries = await Future.wait([
        // Try doctors collection with fullName
        _firestore.collection('doctors').where('fullName', isEqualTo: doctorName).limit(1).get(),
        // Try doctors collection with name
        _firestore.collection('doctors').where('name', isEqualTo: doctorName).limit(1).get(),
        // Try Doctor collection with Doctors Name
        _firestore.collection('Doctor').doc('Profile').collection('Profile')
            .where('Doctors Name', isEqualTo: doctorName).limit(1).get(),
      ]);
      
      // Check each query result
      for (var query in queries) {
        if (query.docs.isNotEmpty) {
          return query.docs.first.data() as Map<String, dynamic>;
        }
      }
      
      return null;
    } catch (e) {
      print("Error fetching doctor by name: $e");
      return null;
    }
  }
  
  // Get doctor availability with standardized field access
  Future<Map<String, String>> getDoctorAvailabilityDetails(String doctorName) async {
    Map<String, String> availabilityDetails = {
      'today': 'Not specified',
      'tomorrow': 'Not specified',
      'dayAfter': 'Not specified'
    };
    
    try {
      Map<String, dynamic>? doctorData = await getDoctorByName(doctorName);
      
      if (doctorData != null) {
        // Define all possible field name variations
        final availabilityFields = {
          'today': ['currentAvailability', 'Current Availaibility', 'availability'],
          'tomorrow': ['tommorowsAvailability', 'Tommorows Availaibility'],
          'dayAfter': ['Day After Tommorows Availaibility', 'dayAfterAvailability']
        };
        
        // Check all possible field names for each availability type
        availabilityFields.forEach((key, fieldNames) {
          for (var fieldName in fieldNames) {
            if (doctorData.containsKey(fieldName) && 
                doctorData[fieldName] != null && 
                doctorData[fieldName].toString().isNotEmpty &&
                doctorData[fieldName].toString() != 'Not Set') {
              availabilityDetails[key] = doctorData[fieldName].toString();
              break; // Use first valid field found
            }
          }
        });
      }
      
      return availabilityDetails;
    } catch (e) {
      print("Error fetching doctor availability details: $e");
      return availabilityDetails;
    }
  }
  
  // Booking methods - updated for consistency
  Future<void> bookAppointment(String userId, Map<String, dynamic> appointmentData) async {
    try {
      // Generate a unique ID for this appointment
      final appointmentId = _firestore.collection('Bookings').doc().id;
      appointmentData['appointmentId'] = appointmentId;
      
      // Transaction to ensure data consistency
      await _firestore.runTransaction((transaction) async {
        // 1. Save to patient's bookings collection
        transaction.set(
          _firestore.collection('Patient').doc(userId).collection('Bookings').doc(appointmentId),
          appointmentData
        );
        
        // 2. Also save to central bookings collection for doctor access
        transaction.set(
          _firestore.collection('Bookings').doc('Appointment').collection('Appointment').doc(appointmentId),
          appointmentData
        );
        
        // 3. Update doctor's booked slots (optional, could be useful for quick checks)
        if (appointmentData.containsKey('doctorEmail') && 
            appointmentData['doctorEmail'] != null &&
            appointmentData['doctorEmail'].toString().isNotEmpty) {
          transaction.set(
            _firestore.collection('Doctor').doc(appointmentData['doctorEmail'])
                .collection('BookedSlots').doc(appointmentId),
            {
              'date': appointmentData['date'],
              'timeSlot': appointmentData['TimeSlot'],
              'patientEmail': userId,
              'bookedOn': appointmentData['bookedOn'] ?? DateTime.now().toIso8601String(),
            }
          );
        }
      });
      
      // Also save to SharedPreferences for quick access - do this outside transaction
      final prefs = await SharedPreferences.getInstance();
      String clinicName = appointmentData['ClinicsName'] ?? '';
      String doctorName = appointmentData['doctorName'] ?? '';
      String timeSlot = appointmentData['TimeSlot'] ?? '';
      String date = appointmentData['date'] ?? '';
      await prefs.setString("latest_booking", 
          "Appointment booked for $date at $timeSlot at $clinicName with Dr. $doctorName");
          
    } catch (e) {
      print('Error booking appointment: $e');
      throw Exception('Failed to book appointment: ${e.toString()}');
    }
  }
  
  // Get all appointments for a patient
  Future<List<Map<String, dynamic>>> getPatientAppointments(String userId) async {
    try {
      QuerySnapshot docs = await _firestore
          .collection('Patient')
          .doc(userId)
          .collection('Bookings')
          .get();
      
      return docs.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting patient appointments: $e');
      throw e;
    }
  }
  
  // Get specific appointment details
  Future<Map<String, dynamic>?> getAppointmentDetails(String userId, String appointmentId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('Patient')
          .doc(userId)
          .collection('Bookings')
          .doc(appointmentId)
          .get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting appointment details: $e');
      throw e;
    }
  }
  
  // Get appointments for a doctor on a specific date
  Future<List<Map<String, dynamic>>> getBookedAppointments(String doctorName, String date) async {
    try {
      // Get appointments for the doctor on the specific date
      final querySnapshot = await _firestore
          .collection('Bookings')
          .doc('Appointment')
          .collection('Appointment')
          .where('doctorName', isEqualTo: doctorName)
          .where('date', isEqualTo: date)
          .get();
      
      return querySnapshot.docs
          .map((doc) => doc.data())
          .toList();
    } catch (e) {
      print("Error fetching booked appointments: $e");
      return [];
    }
  }

  // Add this function in a service class or where you handle booking logic

  Future<bool> saveAppointment({
    required String patientEmail,
    required String patientName,
    required String doctorName,
    required String doctorEmail,
    required String doctorSpecialty,
    required String clinicName,
    required String location,
    required DateTime appointmentDate,
    String? notes,
  }) async {
    try {
      // Create appointment document in Firestore
      await FirebaseFirestore.instance.collection('appointments').add({
        'patientEmail': patientEmail,
        'patientName': patientName,
        'doctorName': doctorName,
        'doctorEmail': doctorEmail,
        'doctorSpecialty': doctorSpecialty,
        'clinicName': clinicName,
        'location': location,
        'appointmentDate': Timestamp.fromDate(appointmentDate),
        'bookingTime': Timestamp.fromDate(DateTime.now()),
        'status': 'Booked',
        'notes': notes ?? '',
        'paymentStatus': 'Pending',
      });
      
      // Update shared preferences with latest booking info
      final prefs = await SharedPreferences.getInstance();
      String latestBooking = "Appointment with $doctorName on ${DateFormat('MMM dd, yyyy - hh:mm a').format(appointmentDate)}";
      await prefs.setString("latest_booking", latestBooking);
      
      return true;
    } catch (e) {
      print('Error saving appointment: $e');
      return false;
    }
  }
  
  // Records management methods
  Future<void> saveUploadedRecord(String userId, Map<String, dynamic> recordData) async {
    try {
      await _firestore
          .collection('Patient')
          .doc(userId)
          .collection('Records')
          .doc(recordData['FileName'])
          .set(recordData);
    } catch (e) {
      print('Error saving record: $e');
      throw e;
    }
  }
  
  Future<List<Map<String, dynamic>>> getUploadedRecords(String userId) async {
    try {
      QuerySnapshot records = await _firestore
          .collection('Patient')
          .doc(userId)
          .collection('Records')
          .get();
      
      return records.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting records: $e');
      throw e;
    }
  }
  
  Future<void> deleteRecord(String userId, String fileName) async {
    try {
      await _firestore
          .collection('Patient')
          .doc(userId)
          .collection('Records')
          .doc(fileName)
          .delete();
    } catch (e) {
      print('Error deleting record: $e');
      throw e;
    }
  }

  // Cancel appointment method
  Future<void> cancelAppointment(String userId, String appointmentId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Get the appointment details first
        DocumentReference patientAppointmentRef = _firestore
            .collection('Patient')
            .doc(userId)
            .collection('Bookings')
            .doc(appointmentId);
            
        DocumentSnapshot appointmentDoc = await transaction.get(patientAppointmentRef);
        
        if (!appointmentDoc.exists) {
          throw Exception('Appointment not found');
        }
        
        Map<String, dynamic> appointmentData = appointmentDoc.data() as Map<String, dynamic>;
        
        // Update status to cancelled in both collections
        transaction.update(patientAppointmentRef, {'Status': 'Cancelled'});
        
        // Update in central appointments collection
        transaction.update(
          _firestore.collection('Bookings')
              .doc('Appointment')
              .collection('Appointment')
              .doc(appointmentId),
          {'Status': 'Cancelled'}
        );
        
        // Also update in doctor's booked slots if applicable
        if (appointmentData.containsKey('doctorEmail') && 
            appointmentData['doctorEmail'] != null &&
            appointmentData['doctorEmail'].toString().isNotEmpty) {
          transaction.update(
            _firestore.collection('Doctor')
                .doc(appointmentData['doctorEmail'])
                .collection('BookedSlots')
                .doc(appointmentId),
            {'status': 'Cancelled'}
          );
        }
      });
    } catch (e) {
      print('Error cancelling appointment: $e');
      throw Exception('Failed to cancel appointment: ${e.toString()}');
    }
  }
}