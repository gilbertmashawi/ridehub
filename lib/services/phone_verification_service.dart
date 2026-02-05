// lib/services/phone_verification_service.dart
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:permission_handler/permission_handler.dart';

class PhoneVerificationService {
  // Parse phone number with validation
  static PhoneNumber parsePhoneNumber(String phoneNumber, {IsoCode? country}) {
    try {
      return PhoneNumber.parse(
        phoneNumber,
        callerCountry: country ?? IsoCode.ZW,
      );
    } catch (e) {
      throw FormatException('Invalid phone number: $e');
    }
  }

  // Validate phone number
  static bool validatePhoneNumber(String phoneNumber, {IsoCode? country}) {
    try {
      final parsed = parsePhoneNumber(phoneNumber, country: country);
      return parsed.isValid(type: PhoneNumberType.mobile) ||
          parsed.isValid(type: PhoneNumberType.fixedLine);
    } catch (e) {
      return false;
    }
  }

  // Format phone number nicely
  static String formatPhoneNumber(String phoneNumber, {IsoCode? country}) {
    try {
      final parsed = parsePhoneNumber(phoneNumber, country: country);
      return parsed.international;
    } catch (e) {
      return phoneNumber; // Return original if can't format
    }
  }

  // Get country code from phone number
  static String getCountryCode(String phoneNumber) {
    try {
      final parsed = parsePhoneNumber(phoneNumber);
      return '+${parsed.countryCode}';
    } catch (e) {
      return '+263'; // Default to Zimbabwe
    }
  }

  // Extract local number (without country code)
  static String extractLocalNumber(String phoneNumber) {
    try {
      final parsed = parsePhoneNumber(phoneNumber);
      return parsed.nsn;
    } catch (e) {
      // Fallback: remove +263 or 0
      String local = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      if (local.startsWith('263')) local = local.substring(3);
      if (local.startsWith('0')) local = local.substring(1);
      return local;
    }
  }

  // Check if phone number matches Zimbabwean format
  static bool isZimbabweanNumber(String phoneNumber) {
    try {
      final parsed = parsePhoneNumber(phoneNumber);
      return parsed.countryCode == 263;
    } catch (e) {
      // Check if starts with Zimbabwe patterns
      final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      return cleaned.startsWith('263') ||
          cleaned.startsWith('+263') ||
          cleaned.startsWith('07') ||
          cleaned.startsWith('08');
    }
  }

  // Get flag emoji for country
  static String getFlagEmoji(IsoCode isoCode) {
    switch (isoCode) {
      case IsoCode.ZW:
        return '🇿🇼';
      case IsoCode.US:
        return '🇺🇸';
      case IsoCode.GB:
        return '🇬🇧';
      case IsoCode.IN:
        return '🇮🇳';
      case IsoCode.NG:
        return '🇳🇬';
      case IsoCode.KE:
        return '🇰🇪';
      case IsoCode.TZ:
        return '🇹🇿';
      case IsoCode.UG:
        return '🇺🇬';
      case IsoCode.ZA:
        return '🇿🇦';
      default:
        return '🏳️';
    }
  }

  // Get country name from ISO code
  static String getCountryName(IsoCode isoCode) {
    return isoCode.name.toUpperCase();
  }

  // Detect potential phone numbers in text
  static List<String> findPhoneNumbersInText(String text) {
    try {
      final found = PhoneNumber.findPotentialPhoneNumbers(text);
      return found.map((pn) => pn.international).toList();
    } catch (e) {
      return [];
    }
  }

  // Check if number is mobile
  static bool isMobileNumber(String phoneNumber) {
    try {
      final parsed = parsePhoneNumber(phoneNumber);
      return parsed.isValid(type: PhoneNumberType.mobile);
    } catch (e) {
      return false;
    }
  }

  // Suggest country based on number prefix
  static IsoCode? suggestCountryFromNumber(String phoneNumber) {
    try {
      final parsed = parsePhoneNumber(phoneNumber);
      return parsed.isoCode;
    } catch (e) {
      // Try to guess from prefix
      final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      if (cleaned.startsWith('+1')) return IsoCode.US;
      if (cleaned.startsWith('+44')) return IsoCode.GB;
      if (cleaned.startsWith('+91')) return IsoCode.IN;
      if (cleaned.startsWith('+234')) return IsoCode.NG;
      if (cleaned.startsWith('+254')) return IsoCode.KE;
      if (cleaned.startsWith('+255')) return IsoCode.TZ;
      if (cleaned.startsWith('+256')) return IsoCode.UG;
      if (cleaned.startsWith('+27')) return IsoCode.ZA;
      if (cleaned.startsWith('+263') ||
          cleaned.startsWith('263') ||
          cleaned.startsWith('07') ||
          cleaned.startsWith('08')) {
        return IsoCode.ZW;
      }

      return null;
    }
  }
}
