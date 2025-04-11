import 'package:cloud_firestore/cloud_firestore.dart';
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
  
  // Appointment methods
  Future<void> bookAppointment(String userId, Map<String, dynamic> appointmentData) async {
    try {
      // Save to Firestore
      await _firestore
          .collection('Patient')
          .doc(userId)
          .collection('Bookings')
          .doc('Appointment')
          .set(appointmentData);
      
      // Also save to SharedPreferences for quick access
      final prefs = await SharedPreferences.getInstance();
      String clinicName = appointmentData['ClinicsName'] ?? '';
      String doctorName = appointmentData['doctorName'] ?? '';
      String timeSlot = appointmentData['TimeSlot'] ?? '';
      await prefs.setString("latest_booking", 
          "Appointment booked for $timeSlot at $clinicName with Dr. $doctorName");
    } catch (e) {
      print('Error booking appointment: $e');
      throw e;
    }
  }
  
  Future<Map<String, dynamic>?> getAppointmentDetails(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('Patient')
          .doc(userId)
          .collection('Bookings')
          .doc('Appointment')
          .get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting appointment: $e');
      throw e;
    }
  }
  
  // Upload records methods
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

  // Add these methods to your FirebaseServices class

Future<Map<String, dynamic>?> getDoctorAvailability(String doctorName) async {
  try {
    // Get doctor profile document
    final docSnapshot = await FirebaseFirestore.instance
        .collection('Doctor')
        .doc('Profile')
        .collection('Profile')
        .where('Doctors Name', isEqualTo: doctorName)
        .get();
    
    if (docSnapshot.docs.isNotEmpty) {
      return docSnapshot.docs.first.data();
    }
    return null;
  } catch (e) {
    print("Error fetching doctor availability: $e");
    return null;
  }
}

Future<List<Map<String, dynamic>>> getBookedAppointments(String doctorName, String date) async {
  try {
    // Get appointments for the doctor on the specific date
    final querySnapshot = await FirebaseFirestore.instance
        .collection('Bookings')
        .doc('Appointment')
        .collection('Appointment')
        .where('doctorName', isEqualTo: doctorName)
        .where('date', isEqualTo: date)
        .get();
    
    return querySnapshot.docs.map((doc) => doc.data()).toList();
  } catch (e) {
    print("Error fetching booked appointments: $e");
    return [];
  }
}
}