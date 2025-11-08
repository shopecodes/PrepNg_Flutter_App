// lib/screens/subject_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectListScreen extends StatelessWidget {
  const SubjectListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PrepNg: Select Subject'),
        backgroundColor: Colors.green.shade700,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Stream: Listen to the 'subjects' collection
        stream: FirebaseFirestore.instance.collection('subjects').snapshots(),

        // Builder: Handles the different states of the data stream
        builder: (context, snapshot) {
          // 1. Show a loading indicator while waiting for data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Handle errors
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading subjects!'));
          }

          // 3. Handle no data (if the collection is empty)
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No subjects found. Please check Firestore.'),
            );
          }

          // 4. Data is ready! Get the list of subject documents
          final subjects = snapshot.data!.docs;

          return ListView.builder(
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              // The data for the current subject
              final subjectData = subjects[index]; 

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  leading: const Icon(Icons.menu_book, color: Colors.green),
                  title: Text(
                    subjectData['name'], // Get the 'name' field from Firestore
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(subjectData['description'] ?? 'No description.'),
                  onTap: () {
                    // TODO: Navigate to the question screen, passing the subject ID
                    print('Selected Subject ID: ${subjects[index].id}');
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}