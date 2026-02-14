import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class PrelimSurveyScreen extends StatefulWidget {
  const PrelimSurveyScreen({super.key});

  @override
  State<PrelimSurveyScreen> createState() => _PrelimSurveyScreenState();
}

class _PrelimSurveyScreenState extends State<PrelimSurveyScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController genderController = TextEditingController();
  final TextEditingController sleepController = TextEditingController();
  final TextEditingController dietController = TextEditingController();
  final TextEditingController alcoholController = TextEditingController();
  final TextEditingController smokingController = TextEditingController();
  final TextEditingController eatingOutController = TextEditingController();
  final TextEditingController lifestyleController = TextEditingController();
  final TextEditingController chronicController = TextEditingController();
  final TextEditingController menstrualController = TextEditingController();
  final TextEditingController medicationController = TextEditingController();
  final TextEditingController flatFeetController = TextEditingController();
  final TextEditingController surgeriesController = TextEditingController();

  Widget _field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: "Roboto",
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60),
          filled: true,
          fillColor: Colors.white12,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Future<void> _saveUser() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a name")),
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      await supabase.from("users").insert({
        "name": nameController.text.trim(),
        "age": int.tryParse(ageController.text.trim()),
        "height_cm": double.tryParse(heightController.text.trim()),
        "weight_kg": double.tryParse(weightController.text.trim()),
        "gender": genderController.text.trim(),

        "sleep_previous_night": sleepController.text.trim(),
        "usual_diet": dietController.text.trim(),
        "alcohol_consumption": alcoholController.text.trim(),
        "smoking": smokingController.text.trim(),
        "eating_out_frequency": eatingOutController.text.trim(),
        "lifestyle": lifestyleController.text.trim(),
        "chronic_conditions": chronicController.text.trim(),
        "menstrual_cycle_phase": menstrualController.text.trim(),
        "medication_usage": medicationController.text.trim(),
        "flat_feet": flatFeetController.text.trim().toLowerCase() == "yes",
        "past_surgeries": surgeriesController.text.trim(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Saved ${nameController.text.trim()}")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving user: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Preliminary Survey"),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: ListView(
          children: [
            _field("Name", nameController),
            _field("Age", ageController),
            _field("Height", heightController),
            _field("Weight", weightController),
            _field("Gender", genderController),
            _field("Sleep previous night", sleepController),
            _field("Usual diet", dietController),
            _field("Alcohol consumption", alcoholController),
            _field("Smoking", smokingController),
            _field("Frequency of eating out", eatingOutController),
            _field("Activity type / lifestyle", lifestyleController),
            _field("Chronic conditions", chronicController),
            _field("Menstrual cycle and phase (if female)", menstrualController),
            _field("Medication usage", medicationController),
            _field("Flat feet", flatFeetController),
            _field("Past surgeries", surgeriesController),

            const SizedBox(height: 20),

            SizedBox(
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _saveUser,
                child: const Text(
                  "Save User",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
