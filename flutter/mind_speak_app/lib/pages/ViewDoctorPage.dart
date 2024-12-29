import 'package:flutter/material.dart';
import '../Components/CustomBottomNavigationBar.dart';

class ViewDoctorsPage extends StatelessWidget {
  const ViewDoctorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.blue,
        title: const Text(
          "View Doctors",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: const ViewDoctors(),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 1),
    );
  }
}

class ViewDoctors extends StatefulWidget {
  const ViewDoctors({Key? key}) : super(key: key);

  @override
  State<ViewDoctors> createState() => _ViewDoctorsState();
}

class _ViewDoctorsState extends State<ViewDoctors> {
  List<Map<String, dynamic>> _allDoctors = [
    {"id": 1, "name": "Ahmed", "Email": "ahmed@gmail.com"},
    {"id": 2, "name": "Fares", "Email": "fares@gmail.com"},
    {"id": 3, "name": "Osos", "Email": "osos@gmail.com"},
    {"id": 4, "name": "Mohamed", "Email": "mohamed@gmail.com"}
  ];

  List<Map<String, dynamic>> _foundUsers = [];
  @override
  void initState() {
    _foundUsers = _allDoctors;
    super.initState();
  }

  void _runFilter(String searchNames) {
    List<Map<String, dynamic>> results = [];
    if (searchNames.isEmpty) {
      results = _allDoctors;
    } else {
      results = _allDoctors
          .where((user) =>
              user["name"].toLowerCase().contains(searchNames.toLowerCase()))
          .toList();
    }

    setState(() {
      _foundUsers = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        children: [
          const SizedBox(
            height: 20,
          ),
          TextField(
            onChanged: (value) => _runFilter(value),
            decoration: const InputDecoration(
              labelText: 'Search',
              suffixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _foundUsers.length,
              itemBuilder: (context, index) => Card(
                key: ValueKey(_foundUsers[index]["id"].toString()),
                color: Colors.blue,
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: ListTile(
                  leading: Text(
                    _foundUsers[index]["id"].toString(),
                    style: const TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  title: Text(
                    _foundUsers[index]['name'],
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    _foundUsers[index]['Email'],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
