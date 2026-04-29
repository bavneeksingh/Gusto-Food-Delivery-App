import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gusto/core/providers/preferences_provider.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFFE724C);
    final prefs = context.watch<PreferencesProvider>();

    final List<Map<String, String>> languages = [
      {'name': 'English', 'native': 'English', 'flag': '🇺🇸'},
      {'name': 'Hindi', 'native': 'हिन्दी', 'flag': '🇮🇳'},
      {'name': 'Spanish', 'native': 'Español', 'flag': '🇪🇸'},
      {'name': 'French', 'native': 'Français', 'flag': '🇫🇷'},
      {'name': 'Arabic', 'native': 'العربية', 'flag': '🇦🇪'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Language Selection",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              "Choose your preferred language for the app experience.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final lang = languages[index];
                final isSelected = prefs.appLanguage == lang['name'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? primaryColor : Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Text(
                        lang['flag']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        lang['name']!,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        lang['native']!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: primaryColor)
                          : null,
                      onTap: () => prefs.setLanguage(lang['name']!),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: _buildSaveButton(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    const Color primaryColor = Color(0xFFFE724C);
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryColor, Color(0xFFFF9A76)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: const Text(
          "Continue",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
