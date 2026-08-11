import 'package:cloud_firestore/cloud_firestore.dart';

class MyRecipe {
  final String? id;
  final String title;
  final String description;
  final List<String> ingredients;
  final List<String> instructions;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int fiber;
  final double rating;
  final int ratingCount;
  final int likes;
  final int cookTime; // minutes
  final List<String> tags; // e.g. ["High Protein", "Low Calorie", "Quick"]
  final List<String> specialNutrients; // e.g. ["Vitamin C", "Iron", "Omega-3"]
  final bool isPublished;
  final String createdBy;
  final String publisherName;
  final String publisherAvatarUrl;
  final String? imageUrl;
  final String? youtubeLink;
  final String? instagramLink;

  MyRecipe({
    this.id,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.likes = 0,
    this.cookTime = 0,
    this.tags = const [],
    this.specialNutrients = const [],
    this.isPublished = false,
    required this.createdBy,
    this.publisherName = '',
    this.publisherAvatarUrl = '',
    this.imageUrl,
    this.youtubeLink,
    this.instagramLink,
  });

  factory MyRecipe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MyRecipe(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      ingredients: List<String>.from(data['ingredients'] ?? []),
      instructions: List<String>.from(data['instructions'] ?? []),
      calories: data['calories'] ?? 0,
      protein: data['protein'] ?? 0,
      carbs: data['carbs'] ?? 0,
      fat: data['fat'] ?? 0,
      fiber: data['fiber'] ?? 0,
      rating: (data['rating'] ?? 0).toDouble(),
      ratingCount: data['ratingCount'] ?? 0,
      likes: data['likes'] ?? 0,
      cookTime: data['cookTime'] ?? 0,
      tags: List<String>.from(data['tags'] ?? []),
      specialNutrients: List<String>.from(data['specialNutrients'] ?? []),
      isPublished: data['isPublished'] ?? false,
      createdBy: data['createdBy'] ?? '',
      publisherName: data['publisherName'] ?? '',
      publisherAvatarUrl: data['publisherAvatarUrl'] ?? '',
      imageUrl: data['imageUrl'],
      youtubeLink: data['youtubeLink'],
      instagramLink: data['instagramLink'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'ingredients': ingredients,
      'instructions': instructions,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'rating': rating,
      'ratingCount': ratingCount,
      'likes': likes,
      'cookTime': cookTime,
      'tags': tags,
      'specialNutrients': specialNutrients,
      'isPublished': isPublished,
      'createdBy': createdBy,
      'publisherName': publisherName,
      'publisherAvatarUrl': publisherAvatarUrl,
      'imageUrl': imageUrl,
      'youtubeLink': youtubeLink,
      'instagramLink': instagramLink,
    };
  }

  /// Computed filter tags based on nutrition values.
  List<String> get computedTags {
    final t = <String>[];
    if (protein >= 30) t.add('High Protein');
    if (calories <= 400) t.add('Low Calorie');
    if (cookTime > 0 && cookTime <= 20) t.add('Quick');
    return t;
  }

  /// Whether the recipe matches a given filter tag.
  bool matchesTag(String tag) {
    if (tags.contains(tag)) return true;
    return computedTags.contains(tag);
  }
}
