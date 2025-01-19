import 'package:flutter/material.dart';
import 'package:mind_speak_app/service/DoctorRepository.dart';

class ViewDoctors extends StatefulWidget {
  const ViewDoctors({super.key});

  @override
  State<ViewDoctors> createState() => _ViewDoctorsState();
}

class _ViewDoctorsState extends State<ViewDoctors> {
  final DoctorRepository _doctorRepository = DoctorRepository();
  List<Map<String, dynamic>> _allTherapist = [];
  List<Map<String, dynamic>> _foundTherapist = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchApprovedTherapist();
  }

  Future<void> fetchApprovedTherapist() async {
    try {
      List<Map<String, dynamic>> therapists =
          await _doctorRepository.fetchApprovedTherapists();
      setState(() {
        _allTherapist = therapists;
        _foundTherapist = therapists;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching therapists: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error fetching therapists: $e'),
        backgroundColor: Colors.red,
      ));
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _runFilter(String searchNames) {
    List<Map<String, dynamic>> results = [];
    if (searchNames.isEmpty) {
      results = _allTherapist;
    } else {
      results = _allTherapist
          .where((user) =>
              user["name"].toLowerCase().contains(searchNames.toLowerCase()))
          .toList();
    }

    setState(() {
      _foundTherapist = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (value) => _runFilter(value),
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      suffixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _foundTherapist.isNotEmpty
                      ? ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _foundTherapist.length,
                          itemBuilder: (context, index) => Card(
                            key: ValueKey(_foundTherapist[index]["id"]),
                            color: Colors.blue,
                            elevation: 4,
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            child: ListTile(
                              leading: Text(
                                (index + 1).toString(),
                                style: const TextStyle(
                                    fontSize: 24, color: Colors.white),
                              ),
                              title: Text(
                                _foundTherapist[index]['name'],
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Email: ${_foundTherapist[index]['email']}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  Text(
                                    'National ID: ${_foundTherapist[index]['nationalid']}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : const Center(
                          child: Text(
                            'No approved doctors found.',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                ],
              ),
            ),
          );
  }
}
