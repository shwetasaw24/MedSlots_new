import 'package:flutter/material.dart';
import '../patient_history_screen.dart';
import '../Doctor_profile.dart';

class DoctorDashboard extends StatefulWidget {
  @override
  _DoctorDashboardState createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    HomeScreen(),
    PatientHistoryScreen(),
    DoctorProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, List<Map<String, dynamic>>> appointments = {
    "Today": [
      {"name": "John Doe", "time": "10:00 AM", "contact": "123-456-7890", "done": false},
      {"name": "Emma Smith", "time": "11:30 AM", "contact": "987-654-3210", "done": false},
    ],
    "Tomorrow": [
      {"name": "Michael Brown", "time": "1:00 PM", "contact": "555-123-4567", "done": false},
      {"name": "Sophia Wilson", "time": "2:30 PM", "contact": "444-987-6543", "done": false},
    ],
    "Day After Tomorrow": [
      {"name": "James Anderson", "time": "9:30 AM", "contact": "333-567-8901", "done": false},
      {"name": "Olivia Taylor", "time": "3:00 PM", "contact": "222-234-5678", "done": false},
    ]
  };

  void _toggleDone(String day, int index, bool? value) {
    setState(() {
      appointments[day]![index]["done"] = value;
      if (value == false) {
        appointments[day]!.removeAt(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text('MedSlots', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage('assets/doctor.jpg'),
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            SizedBox(height: 10),
            Text('Dr. Diksha Gidwani', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Physiotherapist', style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: appointments.keys.map((day) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(day, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      ...appointments[day]!.asMap().entries.map((entry) {
                        int index = entry.key;
                        var appointment = entry.value;
                        return Card(
                          child: ListTile(
                            title: Text(appointment["name"]),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Time: ${appointment["time"]}'),
                                Text('Contact: ${appointment["contact"]}'),
                              ],
                            ),
                            trailing: Checkbox(
                              value: appointment["done"],
                              onChanged: (value) => _toggleDone(day, index, value),
                            ),
                          ),
                        );
                      }).toList(),
                      SizedBox(height: 10),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}