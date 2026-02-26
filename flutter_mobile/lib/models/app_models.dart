class Cattle {
  Cattle({
    required this.id,
    required this.name,
    required this.breed,
    required this.age,
    required this.muzzleId,
    required this.healthScore,
    required this.status,
    required this.location,
    required this.lastScan,
    required this.digitalTwinActive,
    required this.alerts,
  });

  final String id;
  final String name;
  final String breed;
  final int age;
  final String muzzleId;
  final int healthScore;
  final String status;
  final String location;
  final String lastScan;
  final bool digitalTwinActive;
  final int alerts;

  Cattle copyWith({
    String? id,
    String? name,
    String? breed,
    int? age,
    String? muzzleId,
    int? healthScore,
    String? status,
    String? location,
    String? lastScan,
    bool? digitalTwinActive,
    int? alerts,
  }) {
    return Cattle(
      id: id ?? this.id,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      age: age ?? this.age,
      muzzleId: muzzleId ?? this.muzzleId,
      healthScore: healthScore ?? this.healthScore,
      status: status ?? this.status,
      location: location ?? this.location,
      lastScan: lastScan ?? this.lastScan,
      digitalTwinActive: digitalTwinActive ?? this.digitalTwinActive,
      alerts: alerts ?? this.alerts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "breed": breed,
      "age": age,
      "muzzleId": muzzleId,
      "healthScore": healthScore,
      "status": status,
      "location": location,
      "lastScan": lastScan,
      "digitalTwinActive": digitalTwinActive,
      "alerts": alerts,
    };
  }

  factory Cattle.fromJson(Map<String, dynamic> json) {
    return Cattle(
      id: (json["id"] ?? "").toString(),
      name: (json["name"] ?? "").toString(),
      breed: (json["breed"] ?? "").toString(),
      age: (json["age"] as num?)?.toInt() ?? 0,
      muzzleId: (json["muzzleId"] ?? "").toString(),
      healthScore: (json["healthScore"] as num?)?.toInt() ?? 0,
      status: (json["status"] ?? "healthy").toString(),
      location: (json["location"] ?? "").toString(),
      lastScan: (json["lastScan"] ?? "").toString(),
      digitalTwinActive: json["digitalTwinActive"] as bool? ?? false,
      alerts: (json["alerts"] as num?)?.toInt() ?? 0,
    );
  }
}

class FarmAlert {
  FarmAlert({
    required this.id,
    required this.cattleId,
    required this.cattleName,
    required this.cattleBreed,
    required this.type,
    required this.title,
    required this.description,
    required this.time,
    required this.read,
    required this.actionRequired,
  });

  final String id;
  final String cattleId;
  final String cattleName;
  final String cattleBreed;
  final String type;
  final String title;
  final String description;
  final String time;
  final bool read;
  final bool actionRequired;

  FarmAlert copyWith({
    String? id,
    String? cattleId,
    String? cattleName,
    String? cattleBreed,
    String? type,
    String? title,
    String? description,
    String? time,
    bool? read,
    bool? actionRequired,
  }) {
    return FarmAlert(
      id: id ?? this.id,
      cattleId: cattleId ?? this.cattleId,
      cattleName: cattleName ?? this.cattleName,
      cattleBreed: cattleBreed ?? this.cattleBreed,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      time: time ?? this.time,
      read: read ?? this.read,
      actionRequired: actionRequired ?? this.actionRequired,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "cattleId": cattleId,
      "cattleName": cattleName,
      "cattleBreed": cattleBreed,
      "type": type,
      "title": title,
      "description": description,
      "time": time,
      "read": read,
      "actionRequired": actionRequired,
    };
  }

  factory FarmAlert.fromJson(Map<String, dynamic> json) {
    return FarmAlert(
      id: (json["id"] ?? "").toString(),
      cattleId: (json["cattleId"] ?? "").toString(),
      cattleName: (json["cattleName"] ?? "").toString(),
      cattleBreed: (json["cattleBreed"] ?? "").toString(),
      type: (json["type"] ?? "warning").toString(),
      title: (json["title"] ?? "").toString(),
      description: (json["description"] ?? "").toString(),
      time: (json["time"] ?? "").toString(),
      read: json["read"] as bool? ?? false,
      actionRequired: json["actionRequired"] as bool? ?? false,
    );
  }
}

class UserProfile {
  UserProfile({
    required this.name,
    required this.role,
    required this.phone,
    required this.membership,
    required this.totalCattle,
    required this.totalScans,
    required this.totalAlerts,
  });

  final String name;
  final String role;
  final String phone;
  final String membership;
  final int totalCattle;
  final int totalScans;
  final int totalAlerts;

  UserProfile copyWith({
    String? name,
    String? role,
    String? phone,
    String? membership,
    int? totalCattle,
    int? totalScans,
    int? totalAlerts,
  }) {
    return UserProfile(
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      membership: membership ?? this.membership,
      totalCattle: totalCattle ?? this.totalCattle,
      totalScans: totalScans ?? this.totalScans,
      totalAlerts: totalAlerts ?? this.totalAlerts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "role": role,
      "phone": phone,
      "membership": membership,
      "totalCattle": totalCattle,
      "totalScans": totalScans,
      "totalAlerts": totalAlerts,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: (json["name"] ?? "").toString(),
      role: (json["role"] ?? "").toString(),
      phone: (json["phone"] ?? "").toString(),
      membership: (json["membership"] ?? "").toString(),
      totalCattle: (json["totalCattle"] as num?)?.toInt() ?? 0,
      totalScans: (json["totalScans"] as num?)?.toInt() ?? 0,
      totalAlerts: (json["totalAlerts"] as num?)?.toInt() ?? 0,
    );
  }
}
