import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/recipe.dart';

String? recipeImageSource(Recipe recipe) {
  final source = recipe.imageUrl?.trim();
  return source == null || source.isEmpty ? null : source;
}

String recipeImageCaption(Recipe recipe) {
  final source = recipeImageSource(recipe);
  if (source == null) return 'Noch kein Rezeptbild hinterlegt';
  return source.startsWith('assets/')
      ? 'Stockfoto · Serviervorschlag'
      : 'Rezeptbild';
}

class RecipeImage extends StatelessWidget {
  const RecipeImage(
    this.source, {
    super.key,
    required this.height,
    this.width = double.infinity,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });
  final String? source;
  final double height;
  final double width;
  final BoxFit fit;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) {
    final imageSource = source?.trim();
    if (imageSource == null || imageSource.isEmpty) {
      return Semantics(
        label: 'Noch kein Rezeptbild hinterlegt',
        image: true,
        child: Container(
          height: height,
          width: width,
          color: AppColors.softGreen,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.restaurant_outlined,
                size: height < 90 ? 26 : 38,
                color: AppColors.sage,
              ),
              if (height >= 90) ...[
                const SizedBox(height: 8),
                const Flexible(
                  child: Text(
                    'Noch kein Rezeptbild',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    Widget fallback(BuildContext context, Object error, StackTrace? stack) =>
        Container(
          height: height,
          width: width,
          color: AppColors.softGreen,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, size: height < 90 ? 26 : 36),
              if (height >= 90) ...[
                const SizedBox(height: 8),
                const Flexible(
                  child: Text(
                    'Bild nicht verfügbar',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        );
    if (imageSource.startsWith('https://')) {
      return Image.network(
        imageSource,
        height: height,
        width: width,
        fit: fit,
        semanticLabel: semanticLabel,
        errorBuilder: fallback,
      );
    }
    return Image.asset(
      imageSource,
      height: height,
      width: width,
      fit: fit,
      semanticLabel: semanticLabel,
      errorBuilder: fallback,
    );
  }
}
