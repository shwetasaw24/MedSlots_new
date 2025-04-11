class Doctor {
  String? id;
  String? name;
  String? email;
  String? clinicsName;
  String? contactNumber;
  String? specialization;
  String? location;
  String? currentAvailability;
  String? tomorrowsAvailability;
  String? dayAfterTomorrowsAvailability;

  Doctor({
    this.id,
    this.name,
    this.email,
    this.clinicsName,
    this.contactNumber,
    this.specialization,
    this.location,
    this.currentAvailability,
    this.tomorrowsAvailability,
    this.dayAfterTomorrowsAvailability,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      clinicsName: json['clinicsName'],
      contactNumber: json['contactNumber'],
      specialization: json['specialization'],
      location: json['location'],
      currentAvailability: json['currentAvailability'],
      tomorrowsAvailability: json['tomorrowsAvailability'],
      dayAfterTomorrowsAvailability: json['dayAfterTomorrowsAvailability'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'clinicsName': clinicsName,
      'contactNumber': contactNumber,
      'specialization': specialization,
      'location': location,
      'currentAvailability': currentAvailability,
      'tomorrowsAvailability': tomorrowsAvailability,
      'dayAfterTomorrowsAvailability': dayAfterTomorrowsAvailability,
    };
  }
}
