import 'dart:developer';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import '../services/auth_service.dart';
import '../screens/chatbot_screen.dart';


class SafetyScreen extends StatefulWidget {
  const SafetyScreen({Key? key}) : super(key: key);

  @override
  _SafetyScreenState createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String _safetyTip = '';
  String _warning =
      'Checking for warnings...'; // Default message while checking warnings
  final Location _location = Location();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _checkLocationPermission();
    await _loadUserData();
    await _fetchSafetyTip();
    await _fetchWarning();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userData = await authService.getUserProfile(user.uid);

      if (mounted) {
        setState(() {
          _userData = userData;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSafetyTip() async {
    final tipsSnapshot =
        await FirebaseFirestore.instance
            .collection('Guardian App Safety TIPS')
            .get();
    if (tipsSnapshot.docs.isNotEmpty) {
      setState(() {
        final tips = tipsSnapshot.docs.first.data()['tips'];
        _safetyTip = tips[Random().nextInt(tips.length)] ?? '';
      });
    } else {
      // Fallback message if no tip is found
      setState(() {
        _safetyTip = 'Stay Alert, Stay Safe!';
      });
    }
  }

  Future<void> _fetchWarning() async {
    try {
      final locationData = await _location.getLocation();
      print('inside fetch warning');

      // Define proximity threshold (degrees)
      const double proximityThreshold = 0.01;

      final double currentLat = locationData.latitude!;
      final double currentLong = locationData.longitude!;

      // Query Firestore: only get nearby latitudes
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('LocationWarnings')
              .where('latitude', isGreaterThan: currentLat - proximityThreshold)
              .where('latitude', isLessThan: currentLat + proximityThreshold)
              .get();

      // Check longitude in code
      bool warningFound = false;
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final double docLong = data['longitude'];
        if ((currentLong - docLong).abs() < proximityThreshold) {
          setState(() {
            _warning = data['warning'] ?? 'Warning found';
          });
          warningFound = true;
          break;
        }
      }

      if (!warningFound) {
        setState(() {
          _warning = 'No warnings in your area.';
        });
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _sendSOS() async {
    print('inside send sos');
    if (_userData == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User data not loaded.')));
      return;
    }
    try {
      final locationData = await _location.getLocation();
      final locationLink =
          'https://maps.google.com/?q=${locationData.latitude},${locationData.longitude}';
      final message = 'EMERGENCY: I need help! My location is: $locationLink';
      final emergencyContact1 = _userData!['emergencyContact1'];
      final emergencyContact2 = _userData!['emergencyContact2'];

      if (emergencyContact1 != null) {
        final Uri sms1 = Uri.parse(
          'sms:$emergencyContact1&body=${Uri.encodeComponent(message)}',
        );
        if (await canLaunchUrl(sms1)) {
          await launchUrl(sms1);
        } else {
          await launchUrl(sms1, mode: LaunchMode.externalApplication);
        }
      }

      if (emergencyContact2 != null) {
        final Uri sms2 = Uri.parse(
          'sms:$emergencyContact2&body=${Uri.encodeComponent(message)}',
        );
        print(sms2);
        if (await canLaunchUrl(sms2)) {
          await launchUrl(sms2);
        } else {
          await launchUrl(sms2, mode: LaunchMode.externalApplication);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS message sent!'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending SOS: $e')));
    }
  }

  Future<void> _callMyPeople() async {
    final contact = _userData?['emergencyContact1'];
    if (contact != null) {
      final Uri uri = Uri.parse('tel:$contact');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _callPolice() async {
    final Uri uri = Uri.parse('tel:100');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callAmbulance() async {
    final Uri uri = Uri.parse('tel:108');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _navigateToIncidentReport() {
    Navigator.pushNamed(context, '/incident_report');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Guardian', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/profile_setup'),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(title: const Text('SOS Alert'), onTap: _sendSOS),
            ListTile(title: const Text('Call My People'), onTap: _callMyPeople),
            ListTile(title: const Text('Call Police'), onTap: _callPolice),
            ListTile(
              title: const Text('Call Ambulance'),
              onTap: _callAmbulance,
            ),
            ListTile(
              title: const Text('Report Incident'),
              onTap: _navigateToIncidentReport,
            ),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_safetyTip.isNotEmpty)
                            Text(
                              'Safety Tip: $_safetyTip',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          const SizedBox(height: 20),
                          if (_warning.isNotEmpty)
                            Text(
                              'Warning: $_warning',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.red,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton(
                      onPressed: () {
                      Navigator.push(
                         context,
                         MaterialPageRoute(builder: (context) => ChatbotScreen()),

                         );

                      },
                      backgroundColor: Colors.blue,
                      child: const Icon(Icons.chat_bubble),
                    ),
                  ),
                ],
              ),
    );
  }
}
