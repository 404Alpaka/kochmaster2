import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/recipe.dart';

String recipeImageSource(Recipe recipe) =>
    recipe.imageUrl ??
    ((recipe.name.toLowerCase().contains('pasta') ||
            recipe.name.toLowerCase().contains('nudeln'))
        ? 'assets/images/pasta.jpg'
        : 'assets/images/rice.jpg');

class RecipeImage extends StatelessWidget {
  const RecipeImage(
    this.source, {
    super.key,
    required this.height,
    this.width = double.infinity,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });
  final String source;
  final double height;
  final double width;
  final BoxFit fit;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext context, Object error, StackTrace? stack) =>
        Container(
          height: height,
          width: width,
          color: AppColors.softGreen,
          alignment: Alignment.center,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, size: 36),
              SizedBox(height: 8),
              Text('Bild nicht verfügbar'),
            ],
          ),
        );
    if (source.startsWith('https://')) {
      return Image.network(
        source,
        height: height,
        width: width,
        fit: fit,
        semanticLabel: semanticLabel,
        errorBuilder: fallback,
      );
    }
    return Image.asset(
      source,
      height: height,
      width: width,
      fit: fit,
      semanticLabel: semanticLabel,
      errorBuilder: fallback,
    );
  }
}
