import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BookApiService {
  // ── GOOGLE BOOKS CONFIG ──────────────────────────────────
  static const String _googleBaseUrl =
      'https://www.googleapis.com/books/v1/volumes';
  static const String _apiKey = 'AIzaSyBSZRDl-TEhPf6CPWwkBxbiD8shxOsSlkM';

  // ── OPEN LIBRARY CONFIG ──────────────────────────────────
  static const String _openLibBaseUrl = 'https://openlibrary.org/search.json';

  // ── HTTP WITH RETRY (For Google API) ─────────────────────
  static Future<http.Response> _getWithRetry(Uri url, {int retries = 2}) async {
    for (int i = 0; i < retries; i++) {
      try {
        final response = await http
            .get(url)
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) return response;
        if (response.statusCode == 503 && i < retries - 1) {
          await Future.delayed(Duration(seconds: pow(2, i).toInt()));
          continue;
        }
        throw Exception('HTTP ${response.statusCode}');
      } catch (e) {
        if (i == retries - 1)
          throw Exception('Network error after $retries retries: $e');
        await Future.delayed(Duration(seconds: pow(2, i).toInt()));
      }
    }
    throw Exception('Failed after $retries retries');
  }

  // ── 0. GENERAL SEARCH ───────────────────────────────────
  static Future<List<dynamic>> searchGeneral(
    String query, {
    int startIndex = 0,
    int maxResults = 20,
  }) async {
    if (query.isEmpty) return [];
    try {
      // General Google Books search, similar to Google Scholar style.
      // It can match title, author, subject, ISBN, and other book metadata.
      final url = Uri.parse(
        '$_googleBaseUrl?q=${Uri.encodeComponent(query)}'
        '&startIndex=$startIndex&maxResults=$maxResults'
        '&printType=books&orderBy=relevance&key=$_apiKey',
      );
      final response = await _getWithRetry(url);
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['items'] ?? [];
    } catch (e) {
      debugPrint(
        'Google API Failed (General). Falling back to Open Library... ($e)',
      );
      return await _searchOpenLibrary(
        query,
        'q',
        maxResults,
        offset: startIndex,
      );
    }
  }

  // ── 1. SEARCH BY TITLE ───────────────────────────────────
  static Future<List<dynamic>> searchByTitle(
    String query, {
    int startIndex = 0,
    int maxResults = 20,
  }) async {
    if (query.isEmpty) return [];
    try {
      // Google Books pagination:
      // startIndex = 0  -> first 20 books
      // startIndex = 20 -> next 20 books
      // startIndex = 40 -> next 20 books
      final url = Uri.parse(
        '$_googleBaseUrl?q=intitle:${Uri.encodeComponent(query)}'
        '&startIndex=$startIndex&maxResults=$maxResults'
        '&printType=books&orderBy=relevance&key=$_apiKey',
      );
      final response = await _getWithRetry(url);
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['items'] ?? [];
    } catch (e) {
      // FALLBACK to Open Library with the same paging idea
      debugPrint(
        'Google API Failed (Title). Falling back to Open Library... ($e)',
      );
      return await _searchOpenLibrary(
        query,
        'title',
        maxResults,
        offset: startIndex,
      );
    }
  }

  // ── 2. SEARCH BY AUTHOR ──────────────────────────────────
  static Future<List<dynamic>> searchByAuthor(
    String query, {
    int startIndex = 0,
    int maxResults = 20,
  }) async {
    if (query.isEmpty) return [];
    try {
      final url = Uri.parse(
        '$_googleBaseUrl?q=inauthor:${Uri.encodeComponent(query)}'
        '&startIndex=$startIndex&maxResults=$maxResults'
        '&printType=books&orderBy=relevance&key=$_apiKey',
      );
      final response = await _getWithRetry(url);
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['items'] ?? [];
    } catch (e) {
      debugPrint(
        'Google API Failed (Author). Falling back to Open Library... ($e)',
      );
      return await _searchOpenLibrary(
        query,
        'author',
        maxResults,
        offset: startIndex,
      );
    }
  }

  // ── 3. SEARCH BY ISBN ────────────────────────────────────
  static Future<List<dynamic>> searchBookByIsbn(String isbn) async {
    try {
      final url = Uri.parse('$_googleBaseUrl?q=isbn:$isbn&key=$_apiKey');
      final response = await _getWithRetry(url);
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['items'] ?? [];
    } catch (e) {
      debugPrint('Google API Failed (ISBN). Falling back to Open Library...');
      return await _searchOpenLibrary(isbn, 'isbn', 5);
    }
  }

  // ── 4. GET RECOMMENDATIONS ───────────────────────────────
  static Future<List<dynamic>> getRecommendations(String query) async {
    try {
      final url = Uri.parse(
        '$_googleBaseUrl?q=${Uri.encodeComponent(query)}'
        '&maxResults=5&printType=books&key=$_apiKey',
      );
      final response = await _getWithRetry(url);
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['items'] ?? [];
    } catch (e) {
      debugPrint('Google API Failed (Recs). Falling back to Open Library...');
      // Extract subject from query if it exists (e.g., 'subject:fantasy' -> 'fantasy')
      String cleanQuery = query
          .replaceAll('subject:', '')
          .replaceAll('inauthor:', '')
          .replaceAll('"', '');
      return await _searchOpenLibrary(
        cleanQuery,
        'q',
        5,
      ); // Broad search for recs
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  OPEN LIBRARY FALLBACK ENGINE
  // ═════════════════════════════════════════════════════════════

  static Future<List<dynamic>> _searchOpenLibrary(
    String query,
    String parameter,
    int limit, {
    int offset = 0,
  }) async {
    try {
      final url = Uri.parse(
        '$_openLibBaseUrl?$parameter=${Uri.encodeComponent(query)}&limit=$limit&offset=$offset',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final docs = data['docs'] as List<dynamic>? ?? [];

        // Translate Open Library format into Google Books format
        return docs.map((book) => _mapOpenLibraryToGoogleFormat(book)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Open Library Fallback also failed: $e');
      return []; // Return empty list so the app doesn't crash, just shows "No Results"
    }
  }

  /// Translates Open Library JSON structure into the exact format your UI expects
  /// (which is based on Google Books 'volumeInfo' structure).
  static Map<String, dynamic> _mapOpenLibraryToGoogleFormat(dynamic olBook) {
    if (olBook is! Map<String, dynamic>) return {};

    final String title = olBook['title'] ?? 'Unknown Title';
    final List<dynamic> authors = olBook['author_name'] ?? ['Unknown Author'];
    final int pageCount = olBook['number_of_pages_median'] ?? 0;

    // Open Library gives a cover ID. We convert it to their image URL endpoint.
    Map<String, dynamic> imageLinks = {};
    if (olBook['cover_i'] != null) {
      imageLinks['thumbnail'] =
          'https://covers.openlibrary.org/b/id/${olBook['cover_i']}-L.jpg';
    }

    // Extract ISBNs if available
    List<Map<String, String>> industryIdentifiers = [];
    if (olBook['isbn'] != null && (olBook['isbn'] as List).isNotEmpty) {
      for (var isbn in (olBook['isbn'] as List).take(2)) {
        industryIdentifiers.add({'identifier': isbn.toString()});
      }
    }

    return {
      'id':
          olBook['key']?.toString().replaceAll('/', '_') ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'volumeInfo': {
        'title': title,
        'authors': authors,
        'pageCount': pageCount,
        'imageLinks': imageLinks.isNotEmpty ? imageLinks : null,
        'industryIdentifiers': industryIdentifiers,
        'categories': olBook['subject'] != null
            ? (olBook['subject'] as List).take(3).toList()
            : [],
        'description': 'Description not provided by Open Library database.',
      },
    };
  }
}
