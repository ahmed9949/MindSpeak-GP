import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // List of names
  final List<String> names = [
    'osama',
    'fares',
    'hosaam',
    'hossam ahmed',
    'ahmed osama',
    'ahmed hossam',
    'mohammed hossam',
  ];

   List<String> NameAfterFilter = [];

  // Search controller
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initially show all names
    NameAfterFilter = names;
  }

   void _filterNames(String query) {
    setState(() {
      if (query.isEmpty) {
        NameAfterFilter = names;  
      } else {
        NameAfterFilter = names
            .where((name) =>
                name.toLowerCase().contains(query.toLowerCase()))  
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Text Field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onChanged: (query) {
                _filterNames(query); 
                // Filter names as user types
              },
            ),

            const SizedBox(height: 20),

            // Display Filtered Names
            Expanded(
              child: ListView.builder(
                itemCount: NameAfterFilter.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      NameAfterFilter[index], // Display filtered name
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

  
    );
  }
}