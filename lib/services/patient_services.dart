import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/patient_model.dart';

class PatientService {
  final CollectionReference _patientsCollection = 
      FirebaseFirestore.instance.collection('Patient');
      
  // Create a new patient
  Future<void> createPatient(Patient patient) async {
    try {
      DocumentReference docRef = await _patientsCollection.add(patient.toJson());
      await _patientsCollection.doc(docRef.id).update({'id': docRef.id});
    } catch (e) {
      print('Error creating patient: $e');
      throw e;
    }
  }
  
  // Get patient by ID
  Future<Patient?> getPatientById(String id) async {
    try {
      DocumentSnapshot doc = await _patientsCollection.doc(id).get();
      if (doc.exists) {
        return Patient.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting patient: $e');
      throw e;
    }
  }
  
  // Get patient by email
  Future<Patient?> getPatientByEmail(String email) async {
    try {
      QuerySnapshot snapshot = await _patientsCollection
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
          
      if (snapshot.docs.isNotEmpty) {
        return Patient.fromJson(
            snapshot.docs.first.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting patient by email: $e');
      throw e;
    }
  }
  
  // Update patient
  Future<void> updatePatient(Patient patient) async {
    try {
      await _patientsCollection.doc(patient.id).update(patient.toJson());
    } catch (e) {
      print('Error updating patient: $e');
      throw e;
    }
  }
  
  // Delete patient
  Future<void> deletePatient(String id) async {
    try {
      await _patientsCollection.doc(id).delete();
    } catch (e) {
      print('Error deleting patient: $e');
      throw e;
    }
  }
}
