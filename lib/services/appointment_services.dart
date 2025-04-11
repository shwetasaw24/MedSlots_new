import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';

class AppointmentService {
  final CollectionReference _appointmentsCollection = 
      FirebaseFirestore.instance.collection('Appointment');
      
  // Create a new appointment
  Future<void> createAppointment(Appointment appointment) async {
    try {
      DocumentReference docRef = await _appointmentsCollection.add(appointment.toJson());
      await _appointmentsCollection.doc(docRef.id).update({'id': docRef.id});
    } catch (e) {
      print('Error creating appointment: $e');
      throw e;
    }
  }
  
  // Get appointment by ID
  Future<Appointment?> getAppointmentById(String id) async {
    try {
      DocumentSnapshot doc = await _appointmentsCollection.doc(id).get();
      if (doc.exists) {
        return Appointment.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting appointment: $e');
      throw e;
    }
  }
  
  // Get appointments by patient ID
  Future<List<Appointment>> getAppointmentsByPatientId(String patientId) async {
    try {
      QuerySnapshot snapshot = await _appointmentsCollection
          .where('patientId', isEqualTo: patientId)
          .get();
          
      return snapshot.docs
          .map((doc) => Appointment.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting appointments by patient ID: $e');
      throw e;
    }
  }
  
  // Get appointments by doctor ID
  Future<List<Appointment>> getAppointmentsByDoctorId(String doctorId) async {
    try {
      QuerySnapshot snapshot = await _appointmentsCollection
          .where('doctorId', isEqualTo: doctorId)
          .get();
          
      return snapshot.docs
          .map((doc) => Appointment.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting appointments by doctor ID: $e');
      throw e;
    }
  }
  
  // Get appointments by date
  Future<List<Appointment>> getAppointmentsByDate(DateTime date) async {
    try {
      // Create date range for the entire day
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      
      QuerySnapshot snapshot = await _appointmentsCollection
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThanOrEqualTo: endOfDay)
          .get();
          
      return snapshot.docs
          .map((doc) => Appointment.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting appointments by date: $e');
      throw e;
    }
  }
  
  // Update appointment
  Future<void> updateAppointment(Appointment appointment) async {
    try {
      await _appointmentsCollection.doc(appointment.id).update(appointment.toJson());
    } catch (e) {
      print('Error updating appointment: $e');
      throw e;
    }
  }
  
  // Update appointment status
  Future<void> updateAppointmentStatus(String appointmentId, String status) async {
    try {
      await _appointmentsCollection.doc(appointmentId).update({'status': status});
    } catch (e) {
      print('Error updating appointment status: $e');
      throw e;
    }
  }
  
  // Delete appointment
  Future<void> deleteAppointment(String id) async {
    try {
      await _appointmentsCollection.doc(id).delete();
    } catch (e) {
      print('Error deleting appointment: $e');
      throw e;
    }
  }
}