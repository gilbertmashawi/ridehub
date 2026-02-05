// lib/services/country_detection_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

class CountryDetectionService {
  // Try to detect country from device locale
  static Future<IsoCode?> detectCountryFromLocale() async {
    try {
      final locale = await getDeviceLocale();
      if (locale != null) {
        final countryCode = locale.split('_').last.toUpperCase();

        // Try to find matching ISO code
        for (final iso in IsoCode.values) {
          if (iso.name.toUpperCase() == countryCode) {
            return iso;
          }
        }
      }
    } catch (e) {
      debugPrint('Locale detection error: $e');
    }

    return null;
  }

  static Future<String?> getDeviceLocale() async {
    try {
      final String? locale = await MethodChannel(
        'flutter/locale',
      ).invokeMethod<String>('getLocale');
      return locale;
    } catch (e) {
      debugPrint('Error getting locale: $e');
      return null;
    }
  }

  // Get list of supported countries
  static List<Map<String, dynamic>> getSupportedCountries() {
    return [
      {
        'iso': IsoCode.ZW,
        'name': 'Zimbabwe',
        'code': '+263',
        'flag': '🇿🇼',
        'example': '77 123 4567',
      },
      {
        'iso': IsoCode.ZA,
        'name': 'South Africa',
        'code': '+27',
        'flag': '🇿🇦',
        'example': '82 123 4567',
      },
      {
        'iso': IsoCode.KE,
        'name': 'Kenya',
        'code': '+254',
        'flag': '🇰🇪',
        'example': '712 345678',
      },
      {
        'iso': IsoCode.NG,
        'name': 'Nigeria',
        'code': '+234',
        'flag': '🇳🇬',
        'example': '812 345 6789',
      },
      {
        'iso': IsoCode.TZ,
        'name': 'Tanzania',
        'code': '+255',
        'flag': '🇹🇿',
        'example': '71 234 5678',
      },
      {
        'iso': IsoCode.UG,
        'name': 'Uganda',
        'code': '+256',
        'flag': '🇺🇬',
        'example': '712 345678',
      },
      {
        'iso': IsoCode.IN,
        'name': 'India',
        'code': '+91',
        'flag': '🇮🇳',
        'example': '98765 43210',
      },
      {
        'iso': IsoCode.GB,
        'name': 'United Kingdom',
        'code': '+44',
        'flag': '🇬🇧',
        'example': '7700 900123',
      },
      {
        'iso': IsoCode.US,
        'name': 'United States',
        'code': '+1',
        'flag': '🇺🇸',
        'example': '(202) 555-0199',
      },
    ];
  }

  // Format phone number based on country
  static String formatForCountry(String phoneNumber, IsoCode country) {
    try {
      final parsed = PhoneNumber.parse(
        phoneNumber,
        destinationCountry: country,
      );
      return parsed.formatNsn();
    } catch (e) {
      return phoneNumber;
    }
  }

  // Get validation rules for country
  static Map<String, dynamic> getValidationRules(IsoCode country) {
    switch (country) {
      case IsoCode.ZW:
        return {
          'minLength': 9,
          'maxLength': 9,
          'prefixes': ['71', '73', '77', '78'],
          'example': '771234567',
        };
      case IsoCode.ZA:
        return {
          'minLength': 9,
          'maxLength': 9,
          'prefixes': [
            '71',
            '72',
            '73',
            '74',
            '76',
            '78',
            '79',
            '81',
            '82',
            '83',
          ],
          'example': '821234567',
        };
      case IsoCode.KE:
        return {
          'minLength': 9,
          'maxLength': 9,
          'prefixes': [
            '70',
            '71',
            '72',
            '73',
            '74',
            '75',
            '76',
            '77',
            '78',
            '79',
          ],
          'example': '712345678',
        };
      default:
        return {'minLength': 7, 'maxLength': 15, 'prefixes': [], 'example': ''};
    }
  }
}
