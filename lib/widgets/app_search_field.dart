import 'package:flutter/material.dart';

/// Normalizes Arabic text and Arabic-Indic digits for forgiving local search.
String normalizeSearchText(Object? value) {
  var text = (value ?? '').toString().toLowerCase().trim();
  const digitMap = {
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
  };
  text = text.replaceAllMapped(RegExp('[٠-٩]'), (m) => digitMap[m[0]]!);
  return text
      .replaceAll(RegExp('[\\u064B-\\u065F\\u0670]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\\s+'), ' ');
}

bool matchesSearchText(String query, Iterable<Object?> values) {
  final needle = normalizeSearchText(query);
  if (needle.isEmpty) return true;
  final haystack = normalizeSearchText(values.join(' '));
  return haystack.contains(needle);
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'ابحث بالاسم أو الرقم أو الموقع...',
  });

  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    textDirection: TextDirection.rtl,
    textInputAction: TextInputAction.search,
    style: const TextStyle(color: Color(0xFF173653), fontSize: 15, fontWeight: FontWeight.w600),
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF087E78)),
      suffixIcon: IconButton(
        tooltip: 'مسح البحث',
        onPressed: () {
          // Clearing through the field's native clear action is handled by its controller owner.
          onChanged('');
        },
        icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF8796A5), size: 18),
      ),
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: Color(0xFF65788A), fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD2DEE9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF12B8B0), width: 1.7),
      ),
    ),
  );
}
