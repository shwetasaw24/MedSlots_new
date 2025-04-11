class MedicalRecord {
  final String id;
  final String fileName;
  final String fileUrl;
  final DateTime uploadDate;
  final String fileType;
  final String patientId;

  MedicalRecord({
    required this.id,
    required this.fileName, 
    required this.fileUrl, 
    required this.uploadDate,
    required this.fileType,
    required this.patientId,
  });
}