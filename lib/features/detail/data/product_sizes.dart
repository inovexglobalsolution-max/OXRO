import 'package:oxro/features/home/data/home_data.dart';

/// Size support for dresses, shoes and other products.
/// Rule-based on product name/brand (mock catalogue has no size field).
enum SizeType { apparel, footwear, oneSize }

/// Apparel (dresses, shirts, kurtas, tees…): India alpha sizes.
const apparelSizes = ['S', 'M', 'L', 'XL', 'XXL'];

/// Footwear: UK sizes with foot length.
const footwearSizes = [
  'UK 6',
  'UK 7',
  'UK 8',
  'UK 9',
  'UK 10',
  'UK 11',
];

/// Apparel size guide rows: size, chest (in), waist (in).
const apparelGuide = [
  ['Size', 'Chest', 'Waist'],
  ['S', '36', '28'],
  ['M', '38', '30'],
  ['L', '40', '32'],
  ['XL', '42', '34'],
  ['XXL', '44', '36'],
];

/// Footwear guide rows: UK, foot length (cm).
const footwearGuide = [
  ['UK', 'Foot (cm)'],
  ['UK 6', '25.0'],
  ['UK 7', '25.7'],
  ['UK 8', '26.0'],
  ['UK 9', '26.7'],
  ['UK 10', '27.3'],
  ['UK 11', '28.0'],
];

const _footwearHints = [
  'shoe',
  'sneaker',
  'sandal',
  'slipper',
  'loafer',
  'boot',
  'runner',
  'air max',
  'cleat',
  'flip-flop',
];

const _apparelHints = [
  'shirt',
  't-shirt',
  'tee',
  'polo',
  'kurta',
  'dress',
  'saree',
  'sari',
  'jean',
  'trouser',
  'pant',
  'jacket',
  'hoodie',
  'sweatshirt',
  'sherwani',
  'blouse',
  'slim-fit',
  'kurti',
  'lehenga',
  'gown',
  ' tops',
  'crop top',
];

/// Footwear wins over apparel when both match (e.g. "sports shoe").
SizeType sizeTypeFor(Product p) {
  final hay = '${p.name} ${p.brand}'.toLowerCase();
  for (final h in _footwearHints) {
    if (hay.contains(h)) return SizeType.footwear;
  }
  for (final h in _apparelHints) {
    if (hay.contains(h)) return SizeType.apparel;
  }
  return SizeType.oneSize;
}

/// Selectable sizes, empty when the product needs no size.
List<String> sizesFor(Product p) {
  switch (sizeTypeFor(p)) {
    case SizeType.apparel:
      return apparelSizes;
    case SizeType.footwear:
      return footwearSizes;
    case SizeType.oneSize:
      return const [];
  }
}

/// True when PDP must force a size pick before ADD / Buy.
bool requiresSize(Product p) => sizeTypeFor(p) != SizeType.oneSize;

/// Sensible quick-add default for card ADD buttons (PDP still
/// forces an explicit pick). Middle of the range.
String? defaultSizeFor(Product p) {
  switch (sizeTypeFor(p)) {
    case SizeType.apparel:
      return 'M';
    case SizeType.footwear:
      return 'UK 9';
    case SizeType.oneSize:
      return null;
  }
}
