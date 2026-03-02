// lib/screens/scope_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:prep_ng/screens/settings_screen.dart';
import '../services/user_service.dart';
import 'subject_list_screen.dart'; 
import 'progress/progress_history_screen.dart';

class ScopeSelectionScreen extends StatefulWidget {
  const ScopeSelectionScreen({super.key});

  @override
  State<ScopeSelectionScreen> createState() => _ScopeSelectionScreenState();
}

class _ScopeSelectionScreenState extends State<ScopeSelectionScreen> {
  int _currentIndex = 0;
  bool _isOffline = false;
  String _userName = ''; // Store user's first name
  final _userService = UserService();

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();
    _preFetchScopes();
    _loadUserName(); // Load user's name
    
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      if (mounted) {
        setState(() {
          _isOffline = result.contains(ConnectivityResult.none);
        });
      }
    });
  }

  // Load user's name and extract first name
  Future<void> _loadUserName() async {
    try {
      final userProfile = await _userService.getUserProfile();
      if (userProfile != null && userProfile.displayName != null) {
        // Extract first name (everything before the first space)
        final fullName = userProfile.displayName!;
        final firstName = fullName.split(' ').first;
        
        if (mounted) {
          setState(() {
            _userName = firstName;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user name: $e');
    }
  }

  Future<void> _checkInitialConnection() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOffline = result.contains(ConnectivityResult.none);
      });
    }
  }

  Future<void> _preFetchScopes() async {
    try {
      await FirebaseFirestore.instance
          .collection('scope')
          .get(const GetOptions(source: Source.serverAndCache));
    } catch (e) {
      debugPrint('Cache warm-up failed: $e');
    }
  }

  void _onTabTapped(int index) {
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const ProgressHistoryScreen()),
      );
    } else {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _userName.isEmpty ? 'Select Exam' : 'Hi, $_userName!  Select Exam',
          style: GoogleFonts.lora(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        backgroundColor: const Color.fromARGB(255, 54, 127, 57),
        centerTitle: false,
        elevation: 0,
        actions: [
          if (_isOffline)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Tooltip(
                message: 'Offline Mode: Using cached data',
                child: Icon(Icons.cloud_off_rounded, color: Colors.orangeAccent),
              ),
            ),
          // --- SETTINGS BUTTON ---
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _loadUserName()); // Reload name after returning from settings
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.6,
              child: Image.asset(
                'assets/images/bookillustration1.png',
                height: 280,
                fit: BoxFit.contain,
              ),
            ),
          ),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('scope').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.green));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading exams!', style: GoogleFonts.poppins()));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No exam types found.', style: GoogleFonts.poppins()));
              }

              final scopes = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 20),
                itemCount: scopes.length,
                itemBuilder: (context, index) {
                  final scope = scopes[index];
                  final scopeId = scope.id; 
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .9),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade50,
                        child: Icon(Icons.school_rounded, color: Colors.green.shade700),
                      ),
                      title: Text(
                        scope['name'],
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SubjectListScreen(
                              scopeId: scopeId,
                              scopeName: scope['name'],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
     bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
              elevation: 0, // Elevation is handled by the Container shadow
              backgroundColor: Colors.transparent,
              selectedItemColor: Colors.green.shade700,
              unselectedItemColor: Colors.grey.shade400,
              showSelectedLabels: true,
              showUnselectedLabels: false,
              selectedLabelStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, 
                fontSize: 12
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded), 
                  label: 'Home'
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history_rounded), 
                  label: 'History'
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}