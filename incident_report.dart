import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({Key? key}) : super(key: key);

  @override
  _IncidentReportScreenState createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _placeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _causeController = TextEditingController();
  File? _image;
  final picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<String> _uploadImage() async {
    if (_image == null) return '';
    try {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final storageRef = FirebaseStorage.instance.ref().child('incident_images').child(fileName);
      await storageRef.putFile(_image!);
      final imageUrl = await storageRef.getDownloadURL();
      return imageUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
      return '';
    }
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      final imageUrl = await _uploadImage();

      final timestamp = Timestamp.fromDate(DateTime.now());
      final incidentData = {
        'place': _placeController.text,
        'description': _descriptionController.text,
        'cause': _causeController.text,
        'timestamp': timestamp,
        'reportedBy': 'UserUID', // Replace with actual User UID from FirebaseAuth
        'imageUrl': imageUrl,
      };

      try {
        await FirebaseFirestore.instance.collection('incident_reports').add(incidentData);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incident reported successfully!')));
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error reporting incident: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Incident'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Pick Image Button
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _image == null
                      ? const Center(child: Icon(Icons.camera_alt, size: 50))
                      : Image.file(_image!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 20),

              // Place Field
              TextFormField(
                controller: _placeController,
                decoration: const InputDecoration(labelText: 'Place'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the place';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // Cause Field
              TextFormField(
                controller: _causeController,
                decoration: const InputDecoration(labelText: 'Cause'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the cause';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Submit Button
              ElevatedButton(
                onPressed: _submitReport,
                child: const Text('Submit Report'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
