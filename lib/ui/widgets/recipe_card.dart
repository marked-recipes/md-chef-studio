import 'package:flutter/material.dart';
import '../../models/recipe.dart';
import '../../theme/app_theme.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final bool isSelected;
  final VoidCallback onTap;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = isDark ? AppTheme.primaryAmber : AppTheme.primaryTerracotta;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isSelected
          ? (isDark ? const Color(0xFF2E3D59) : const Color(0xFFEFF6FF))
          : (isDark ? const Color(0xFF1E293B) : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? primaryColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category badge & Servings
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(38),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      recipe.category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (recipe.servings != null && recipe.servings.toString().isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.people_outline, size: 14, color: isDark ? Colors.white60 : Colors.black54),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.servings}',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                recipe.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),

              // Time pills & Difficulty
              Row(
                children: [
                  if (recipe.prepTime != null || recipe.cookTime != null) ...[
                    Icon(Icons.timer_outlined, size: 14, color: isDark ? Colors.white54 : Colors.black45),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _formatTotalTime(recipe),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (recipe.difficulty != null && recipe.difficulty!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _difficultyColor(recipe.difficulty!).withAlpha(38),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        recipe.difficulty!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _difficultyColor(recipe.difficulty!),
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    '${recipe.ingredients.where((i) => !i.isHeader).length} ing',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
                  ),
                ],
              ),

              // Tags
              if (recipe.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: recipe.tags.take(3).map((tag) {
                    return Text(
                      '#$tag',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black54,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTotalTime(Recipe r) {
    final prep = int.tryParse(r.prepTime?.toString() ?? '') ?? 0;
    final cook = int.tryParse(r.cookTime?.toString() ?? '') ?? 0;
    final total = prep + cook;
    if (total > 0) return '${total}m';
    if (cook > 0) return '${cook}m cook';
    if (prep > 0) return '${prep}m prep';
    final fallback = (r.cookTime ?? r.prepTime ?? '').toString().trim();
    if (fallback.isEmpty) return '';
    return fallback.endsWith('m') || fallback.endsWith('min') || fallback.endsWith('mins')
        ? fallback
        : '${fallback}m';
  }

  Color _difficultyColor(String difficulty) {
    final lower = difficulty.toLowerCase();
    if (lower.contains('easy')) return AppTheme.accentSage;
    if (lower.contains('medium')) return AppTheme.primaryAmber;
    return AppTheme.primaryTerracotta;
  }
}
