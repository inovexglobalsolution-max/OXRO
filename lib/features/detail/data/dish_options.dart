/// A single selectable add-on for a dish (e.g. "Extra Cheese +₹40").
class DishOption {
  const DishOption({
    required this.name,
    this.priceDelta = 0,
    this.defaultOn = false,
  });

  final String name;

  /// Added to the base price when selected, in whole rupees.
  final int priceDelta;

  /// Pre-selected for single-select groups (radio) when true.
  final bool defaultOn;
}

/// A group of add-ons shown on the dish detail page.
/// [multi] false = radio (pick one), true = checkbox (any).
class DishOptionGroup {
  const DishOptionGroup({
    required this.title,
    required this.options,
    this.multi = true,
    this.required = false,
    this.maxSelectable,
  });

  final String title;
  final List<DishOption> options;
  final bool multi;
  final bool required;

  /// Cap for multi-select groups; null means every option can be picked.
  final int? maxSelectable;

  /// Cheapest selectable delta (for "from +₹" hints).
  int get minDelta => options.isEmpty
      ? 0
      : options
          .map((o) => o.priceDelta)
          .reduce((a, b) => a < b ? a : b);

  /// Mock customisation groups reused across mock dishes so the PDP looks
  /// complete without a backend. Keyed by dish name in `dish_options_for`.
  static const standard = [
    DishOptionGroup(
      title: 'Choose Size',
      multi: false,
      required: true,
      options: [
        DishOption(name: 'Regular', priceDelta: 0, defaultOn: true),
        DishOption(name: 'Medium', priceDelta: 40),
        DishOption(name: 'Large', priceDelta: 80),
      ],
    ),
    DishOptionGroup(
      title: 'Add Ons',
      maxSelectable: 2,
      options: [
        DishOption(name: 'Extra Cheese', priceDelta: 40),
        DishOption(name: 'Extra Gravy', priceDelta: 30),
        DishOption(name: 'Butter Topping', priceDelta: 20),
      ],
    ),
    DishOptionGroup(
      title: 'Spice Level',
      multi: false,
      options: [
        DishOption(name: 'Mild', priceDelta: 0, defaultOn: true),
        DishOption(name: 'Medium', priceDelta: 0),
        DishOption(name: 'Spicy', priceDelta: 0),
      ],
    ),
  ];
}

/// Beverage-style customisation (no spice).
const beverageOptionGroups = [
  DishOptionGroup(
    title: 'Choose Size',
    multi: false,
    required: true,
    options: [
      DishOption(name: 'Small', priceDelta: 0, defaultOn: true),
      DishOption(name: 'Regular', priceDelta: 30),
      DishOption(name: 'Large', priceDelta: 60),
    ],
  ),
  DishOptionGroup(
    title: 'Add Ons',
    options: [
      DishOption(name: 'Extra Ice', priceDelta: 0),
      DishOption(name: 'Whipped Cream', priceDelta: 30),
    ],
  ),
];

/// Pizza-style customisation.
const pizzaOptionGroups = [
  DishOptionGroup(
    title: 'Choose Size',
    multi: false,
    required: true,
    options: [
      DishOption(name: 'Regular 7"', priceDelta: 0, defaultOn: true),
      DishOption(name: 'Medium 10"', priceDelta: 100),
      DishOption(name: 'Large 13"', priceDelta: 200),
    ],
  ),
  DishOptionGroup(
    title: 'Crust',
    multi: false,
    options: [
      DishOption(name: 'Classic Hand Tossed', priceDelta: 0, defaultOn: true),
      DishOption(name: 'Cheese Burst', priceDelta: 60),
      DishOption(name: 'Thin Crust', priceDelta: 0),
    ],
  ),
  DishOptionGroup(
    title: 'Toppings',
    options: [
      DishOption(name: 'Extra Cheese', priceDelta: 50),
      DishOption(name: 'Paneer', priceDelta: 60),
      DishOption(name: 'Jalapeno', priceDelta: 40),
      DishOption(name: 'Olives', priceDelta: 40),
    ],
  ),
];

/// Picks a sensible option set by category/dish heuristics (mock).
List<DishOptionGroup> dishOptionsFor(String dishName) {
  final n = dishName.toLowerCase();
  const drinkWords = ['tea', 'coffee', 'juice', 'shake', 'soda', 'mojito',
    'lemonade', 'lassi', 'chai', 'cappuccino', 'latte', 'espresso',
    'thandai', 'smoothie', 'cola'];
  if (drinkWords.any(n.contains)) return beverageOptionGroups;
  if (n.contains('pizza')) return pizzaOptionGroups;
  return DishOptionGroup.standard;
}
