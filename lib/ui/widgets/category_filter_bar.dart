import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/recipe_provider.dart';
import '../../theme/app_theme.dart';

class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.primaryAmber : AppTheme.primaryTerracotta;
    final provider = context.watch<RecipeProvider>();

    final categories = provider.categories;
    final currentCategory = provider.selectedCategory;

    // Ensure selected value matches one of the categories (case-insensitive fallback)
    String selectedValue = 'All';
    for (final cat in categories) {
      if (cat.toLowerCase() == currentCategory.toLowerCase()) {
        selectedValue = cat;
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          TextField(
            onChanged: provider.setSearchQuery,
            decoration: InputDecoration(
              hintText: 'Search recipes, ingredients, tags...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: provider.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => provider.setSearchQuery(''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),

          // Cuisine Dropdown Bar
          Row(
            children: [
              Text(
                'Cuisine:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selectedValue != 'All'
                          ? primaryColor.withAlpha(153)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedValue,
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selectedValue != 'All' ? FontWeight.w600 : FontWeight.normal,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      onChanged: (newCat) {
                        if (newCat != null) {
                          provider.selectCategory(newCat);
                        }
                      },
                      items: categories.map((cat) {
                        final count = provider.getCountForCategory(cat);
                        final label = cat == 'All' ? 'All Cuisines ($count)' : '$cat ($count)';
                        return DropdownMenuItem<String>(
                          value: cat,
                          child: Text(label),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              if (selectedValue != 'All') ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Reset to All Cuisines',
                  icon: const Icon(Icons.cancel, size: 18),
                  color: Colors.grey,
                  onPressed: () => provider.selectCategory('All'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
