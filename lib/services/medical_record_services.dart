import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/record_model.dart';

class MedicalRecordService {
  final CollectionReference _recordsCollection = 
      FirebaseFirestore.instance.collection('Records');
      
  // Create a new medical record
  Future<void> createMedicalRecord(MedicalRecord record) async {
    try {
      DocumentReference docRef = await _recordsCollection.add(record.toJson());
      await _recordsCollection.doc(docRef.id).update({'id': docRef.id});
    } catch (e) {
      print('Error creating medical record: $e');
      throw e;
    }
  }
  
  // Get medical records by patient email
  Future<List<MedicalRecord>> getMedicalRecordsByPatientEmail(String email) async {
    try {
      QuerySnapshot snapshot = await _recordsCollection
          .where('email', isEqualTo: email)
          .get();
          
      return snapshot.docs
          .map((doc) => MedicalRecord.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting medical records by patient email: $e');
      throw e;
    }
  }
  
  // Delete medical record
  Future<void> deleteMedicalRecord(String id) async {
    try {
      await _recordsCollection.doc(id).delete();
    } catch (e) {
      print('Error deleting medical record: $e');
      throw e;
    }
  }
}
