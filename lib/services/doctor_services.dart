import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_model.dart';

class DoctorService {
  final CollectionReference _doctorsCollection = 
      FirebaseFirestore.instance.collection('Doctor');
      
  // Create a new doctor
  Future<void> createDoctor(Doctor doctor) async {
    try {
      DocumentReference docRef = await _doctorsCollection.add(doctor.toJson());
      await _doctorsCollection.doc(docRef.id).update({'id': docRef.id});
    } catch (e) {
      print('Error creating doctor: $e');
      throw e;
    }
  }
  
  // Get doctor by ID
  Future<Doctor?> getDoctorById(String id) async {
    try {
      DocumentSnapshot doc = await _doctorsCollection.doc(id).get();
      if (doc.exists) {
        return Doctor.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting doctor: $e');
      throw e;
    }
  }
  
  // Get doctors by specialization
  Future<List<Doctor>> getDoctorsBySpecialization(String specialization) async {
    try {
      QuerySnapshot snapshot = await _doctorsCollection
          .where('specialization', isEqualTo: specialization)
          .get();
          
      return snapshot.docs
          .map((doc) => Doctor.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting doctors by specialization: $e');
      throw e;
    }
  }
  
  // Get all doctors
  Future<List<Doctor>> getAllDoctors() async {
    try {
      QuerySnapshot snapshot = await _doctorsCollection.get();
          
      return snapshot.docs
          .map((doc) => Doctor.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting all doctors: $e');
      throw e;
    }
  }
  
  // Update doctor
  Future<void> updateDoctor(Doctor doctor) async {
    try {
      await _doctorsCollection.doc(doctor.id).update(doctor.toJson());
    } catch (e) {
      print('Error updating doctor: $e');
      throw e;
    }
  }
  
  // Update doctor availability
  Future<void> updateDoctorAvailability(String doctorId, String day, String availability) async {
    try {
      Map<String, dynamic> updates = {};
      
      if (day == 'current') {
        updates['currentAvailability'] = availability;
      } else if (day == 'tomorrow') {
        updates['tomorrowsAvailability'] = availability;
      } else if (day == 'dayAfterTomorrow') {
        updates['dayAfterTomorrowsAvailability'] = availability;
      }
      
      await _doctorsCollection.doc(doctorId).update(updates);
    } catch (e) {
      print('Error updating doctor availability: $e');
      throw e;
    }
  }
}
