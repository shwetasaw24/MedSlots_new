class Appointment {
  String? id;
  String? clinicsName;
  String? status;
  String? timeSlot;
  DateTime? date;
  String? doctorName;
  String? doctorId;
  String? patientId;
  String? patientName;
  String? specialization;
  String? bookingTime;

  Appointment({
    this.id,
    this.clinicsName,
    this.status,
    this.timeSlot,
    this.date,
    this.doctorName,
    this.doctorId,
    this.patientId,
    this.patientName,
    this.specialization,
    this.bookingTime,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'],
      clinicsName: json['clinicsName'],
      status: json['status'],
      timeSlot: json['timeSlot'],
      date: json['date'] != null ? (json['date']).toDate() : null,
      doctorName: json['doctorName'],
      doctorId: json['doctorId'],
      patientId: json['patientId'],
      patientName: json['patientName'],
      specialization: json['specialization'],
      bookingTime: json['bookingTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clinicsName': clinicsName,
      'status': status,
      'timeSlot': timeSlot,
      'date': date,
      'doctorName': doctorName,
      'doctorId': doctorId,
      'patientId': patientId,
      'patientName': patientName,
      'specialization': specialization,
      'bookingTime': bookingTime,
    };
  }
}
