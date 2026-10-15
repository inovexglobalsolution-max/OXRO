import 'package:flutter/material.dart';

/// Myntra-style 3-level taxonomy: Category → Tabs → Groups → Leafs.
/// User-defined catalogue (all 8 spec categories, ~80 groups, ~250 leafs).
/// Mock tree (backend replaces later). Keyed by HomeCategory.label.

class CatLeaf {
  const CatLeaf(this.name);
  final String name;
}

class CatGroup {
  const CatGroup({
    required this.name,
    required this.icon,
    required this.leafs,
  });

  final String name;
  final IconData icon;
  final List<CatLeaf> leafs;
}

class CatTab {
  const CatTab({
    required this.name,
    required this.icon,
    required this.groups,
  });

  final String name;
  final IconData icon;
  final List<CatGroup> groups;
}

List<CatLeaf> _l(List<String> names) =>
    names.map((n) => CatLeaf(n)).toList();

const categoryTree = <String, List<CatTab>>{
  // ---------------- 1. ELECTRONICS ----------------
  'Electronics': [
    CatTab(
      name: 'Mobiles',
      icon: Icons.smartphone_outlined,
      groups: [
        CatGroup(
          name: 'Mobiles & Smartphones',
          icon: Icons.smartphone_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Computers',
      icon: Icons.laptop_outlined,
      groups: [
        CatGroup(
          name: 'Laptops & Computers',
          icon: Icons.laptop_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Tablets',
          icon: Icons.tablet_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Computer Accessories',
          icon: Icons.keyboard_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Audio & Wearables',
      icon: Icons.headphones_outlined,
      groups: [
        CatGroup(
          name: 'Headphones & Speakers',
          icon: Icons.headphones_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Smartwatches',
          icon: Icons.watch_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'TV & Camera',
      icon: Icons.tv_outlined,
      groups: [
        CatGroup(
          name: 'TVs & Accessories',
          icon: Icons.tv_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Cameras',
          icon: Icons.photo_camera_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Power & Appliances',
      icon: Icons.bolt_outlined,
      groups: [
        CatGroup(
          name: 'Chargers, Cables & Power Banks',
          icon: Icons.bolt_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Home Appliances',
          icon: Icons.kitchen_outlined,
          leafs: [],
        ),
      ],
    ),
  ],
  // ---------------- 2. FASHION & CLOTHING ----------------
  'Fashion & Clothing': [
    CatTab(
      name: 'Men',
      icon: Icons.face_outlined,
      groups: [
        CatGroup(
          name: "Men's Clothing",
          icon: Icons.checkroom_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Ethnic Wear',
          icon: Icons.celebration_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Western Wear',
          icon: Icons.dry_cleaning_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Footwear',
          icon: Icons.directions_run_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Women',
      icon: Icons.face_3_outlined,
      groups: [
        CatGroup(
          name: "Women's Clothing",
          icon: Icons.checkroom_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Ethnic Wear',
          icon: Icons.celebration_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Western Wear',
          icon: Icons.dry_cleaning_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Footwear',
          icon: Icons.woman_2_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Jewellery',
          icon: Icons.stars_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Kids',
      icon: Icons.child_care_outlined,
      groups: [
        CatGroup(
          name: "Kids' Clothing",
          icon: Icons.child_care_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Footwear',
          icon: Icons.directions_run_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Footwear & More',
      icon: Icons.ice_skating_outlined,
      groups: [
        CatGroup(
          name: 'Footwear',
          icon: Icons.ice_skating_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Bags & Backpacks',
          icon: Icons.shopping_bag_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Watches',
          icon: Icons.watch_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Sunglasses & Accessories',
          icon: Icons.wb_sunny_outlined,
          leafs: [],
        ),
      ],
    ),
  ],
  // ---------------- 3. HOME & KITCHEN ----------------
  'Home & Kitchen': [
    CatTab(
      name: 'Kitchen',
      icon: Icons.soup_kitchen_outlined,
      groups: [
        CatGroup(
          name: 'Kitchen Appliances',
          icon: Icons.kitchen_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Cookware & Kitchen Tools',
          icon: Icons.soup_kitchen_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Dinnerware',
          icon: Icons.restaurant_menu_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Home',
      icon: Icons.chair_outlined,
      groups: [
        CatGroup(
          name: 'Storage & Organizers',
          icon: Icons.inventory_2_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Home Decor',
          icon: Icons.brush_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Furniture',
          icon: Icons.chair_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Lighting',
          icon: Icons.light_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Bed & Bath',
      icon: Icons.bed_outlined,
      groups: [
        CatGroup(
          name: 'Bedding & Pillows',
          icon: Icons.bed_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Bathroom Accessories',
          icon: Icons.water_drop_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Cleaning Supplies',
          icon: Icons.cleaning_services_outlined,
          leafs: [],
        ),
      ],
    ),
  ],
  // ---------------- 4. BEAUTY & PERSONAL CARE ----------------
  'Beauty & Personal Care': [
    CatTab(
      name: 'Skincare',
      icon: Icons.spa_outlined,
      groups: [
        CatGroup(
          name: 'Skincare',
          icon: Icons.spa_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Bath & Body Care',
          icon: Icons.water_drop_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Personal Hygiene',
          icon: Icons.health_and_safety_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Makeup',
      icon: Icons.brush_outlined,
      groups: [
        CatGroup(
          name: 'Makeup & Cosmetics',
          icon: Icons.brush_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Beauty Tools',
          icon: Icons.handyman_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Perfumes & Fragrances',
          icon: Icons.air_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Haircare',
      icon: Icons.content_cut_outlined,
      groups: [
        CatGroup(
          name: 'Haircare',
          icon: Icons.content_cut_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Grooming',
      icon: Icons.face_outlined,
      groups: [
        CatGroup(
          name: "Men's Grooming",
          icon: Icons.face_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Oral Care',
          icon: Icons.emoji_emotions_outlined,
          leafs: [],
        ),
      ],
    ),
  ],
  // ---------------- 5. SPORTS & FITNESS ----------------
  'Sports & Fitness': [
    CatTab(
      name: 'Fitness',
      icon: Icons.fitness_center_outlined,
      groups: [
        CatGroup(
          name: 'Gym & Fitness Equipment',
          icon: Icons.fitness_center_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Yoga Accessories',
          icon: Icons.self_improvement_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Fitness Accessories',
          icon: Icons.timer_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Shoes & Wear',
      icon: Icons.directions_run_outlined,
      groups: [
        CatGroup(
          name: 'Sports Shoes',
          icon: Icons.directions_run_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Sportswear',
          icon: Icons.checkroom_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Games',
      icon: Icons.sports_cricket_outlined,
      groups: [
        CatGroup(
          name: 'Cricket Equipment',
          icon: Icons.sports_cricket_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Football',
          icon: Icons.sports_soccer_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Badminton & Tennis',
          icon: Icons.sports_tennis_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Outdoor',
      icon: Icons.forest_outlined,
      groups: [
        CatGroup(
          name: 'Cycling Accessories',
          icon: Icons.directions_bike_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Outdoor & Camping',
          icon: Icons.forest_outlined,
          leafs: [],
        ),
      ],
    ),
  ],
  // ---------------- 6. BOOKS, STATIONERY & OFFICE ----------------
  'Books, Stationery & Office': [
    CatTab(
      name: 'Books',
      icon: Icons.menu_book_outlined,
      groups: [
        CatGroup(
          name: 'Educational Books',
          icon: Icons.school_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Competitive Exam Books',
          icon: Icons.assignment_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Fiction & Non-Fiction',
          icon: Icons.menu_book_outlined,
          leafs: [],
        ),
        CatGroup(
          name: "Children's Books",
          icon: Icons.child_care_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Stationery',
      icon: Icons.edit_outlined,
      groups: [
        CatGroup(
          name: 'Notebooks & Registers',
          icon: Icons.note_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Pens & Pencils',
          icon: Icons.edit_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'School Supplies',
          icon: Icons.backpack_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Art & Craft Supplies',
          icon: Icons.palette_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Office',
      icon: Icons.work_outlined,
      groups: [
        CatGroup(
          name: 'Office Stationery',
          icon: Icons.folder_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Office Accessories',
          icon: Icons.desk_outlined,
          leafs: [],
        ),
      ],
    ),
  ],
  // ---------------- 7. AUTOMOTIVE & ACCESSORIES ----------------
  'Automotive & Accessories': [
    CatTab(
      name: 'Car',
      icon: Icons.directions_car_outlined,
      groups: [
        CatGroup(
          name: 'Car Accessories',
          icon: Icons.directions_car_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Car Electronics',
          icon: Icons.memory_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Car Cleaning Products',
          icon: Icons.cleaning_services_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Bike',
      icon: Icons.two_wheeler_outlined,
      groups: [
        CatGroup(
          name: 'Bike & Scooter Accessories',
          icon: Icons.two_wheeler_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Helmets & Riding Gear',
          icon: Icons.sports_motorsports_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Parts',
      icon: Icons.build_outlined,
      groups: [
        CatGroup(
          name: 'Vehicle Spare Parts',
          icon: Icons.build_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Tyres & Batteries',
          icon: Icons.album_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Engine Oils & Lubricants',
          icon: Icons.local_gas_station_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Essentials',
      icon: Icons.shield_outlined,
      groups: [
        CatGroup(
          name: 'Vehicle Tools',
          icon: Icons.handyman_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Car & Bike Covers',
          icon: Icons.shield_outlined,
          leafs: [],
        ),
      ],
    ),
  ],
  // ---------------- 8. TOYS, KIDS & PET SUPPLIES ----------------
  'Toys, Kids & Pet Supplies': [
    CatTab(
      name: 'Baby',
      icon: Icons.baby_changing_station_outlined,
      groups: [
        CatGroup(
          name: 'Baby Care',
          icon: Icons.baby_changing_station_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Baby Feeding & Accessories',
          icon: Icons.local_drink_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Baby Gear',
          icon: Icons.child_friendly_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Toys',
      icon: Icons.toys_outlined,
      groups: [
        CatGroup(
          name: 'Educational Toys',
          icon: Icons.school_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Dolls & Soft Toys',
          icon: Icons.toys_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Building Blocks & Puzzles',
          icon: Icons.extension_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Remote-Controlled Toys',
          icon: Icons.sports_esports_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Board Games',
          icon: Icons.dashboard_outlined,
          leafs: [],
        ),
      ],
    ),
    CatTab(
      name: 'Pets',
      icon: Icons.pets_outlined,
      groups: [
        CatGroup(
          name: 'Dog Supplies',
          icon: Icons.pets_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Cat Supplies',
          icon: Icons.pets_outlined,
          leafs: [],
        ),
        CatGroup(
          name: 'Pet Food & Accessories',
          icon: Icons.restaurant_outlined,
          leafs: [],
        ),
      ],
    ),
  ],
};

/// Leaf names per (category → tab → group).
const _leafNames = <String, List<String>>{
  // ---- 1. ELECTRONICS ----
  'Electronics|Mobiles|Mobiles & Smartphones': [
    '5G Phones',
    'Flagship Phones',
    'Budget Phones',
    'Refurbished Phones',
  ],
  'Electronics|Computers|Laptops & Computers': [
    'Gaming Laptops',
    'Thin & Light Laptops',
    'Desktops',
    'Monitors',
  ],
  'Electronics|Computers|Tablets': [
    'Android Tablets',
    'iPads',
    'Stylus & Keyboards',
  ],
  'Electronics|Computers|Computer Accessories': [
    'Keyboards',
    'Mouse',
    'Webcams',
    'Printers',
  ],
  'Electronics|Audio & Wearables|Headphones & Speakers': [
    'TWS Earbuds',
    'Neckbands',
    'Bluetooth Speakers',
    'Soundbars',
  ],
  'Electronics|Audio & Wearables|Smartwatches': [
    'AMOLED Watches',
    'Budget Watches',
    'Fitness Bands',
  ],
  'Electronics|TV & Camera|TVs & Accessories': [
    '32" Smart TVs',
    '43-55" 4K TVs',
    'TV Mounts & Stands',
  ],
  'Electronics|TV & Camera|Cameras': [
    'Mirrorless Cameras',
    'Action Cameras',
    'Drones',
  ],
  'Electronics|Power & Appliances|Chargers, Cables & Power Banks': [
    'Fast Chargers',
    'Type-C Cables',
    'Power Banks',
  ],
  'Electronics|Power & Appliances|Home Appliances': [
    'Air Fryers',
    'Mixer Grinders',
    'Vacuum Cleaners',
    'Ceiling Fans',
  ],
  // ---- 2. FASHION ----
  "Fashion & Clothing|Men|Men's Clothing": [
    'Shirts',
    'T-Shirts',
    'Jeans',
  ],
  'Fashion & Clothing|Men|Ethnic Wear': [
    'Kurtas',
    'Sherwanis',
    'Dhotis',
  ],
  'Fashion & Clothing|Men|Western Wear': [
    'Blazers',
    'Denim Jackets',
  ],
  'Fashion & Clothing|Men|Footwear': [
    'Sneakers',
    'Formal Shoes',
    'Flip-Flops',
  ],
  "Fashion & Clothing|Women|Women's Clothing": [
    'Kurtis',
    'Sarees',
    'Leggings',
  ],
  'Fashion & Clothing|Women|Ethnic Wear': [
    'Sarees',
    'Lehengas',
    'Salwar Suits',
  ],
  'Fashion & Clothing|Women|Western Wear': [
    'Dresses',
    'Tops',
    'Gowns',
  ],
  'Fashion & Clothing|Women|Footwear': [
    'Heels',
    'Flats',
    'Wedges',
  ],
  'Fashion & Clothing|Women|Jewellery': [
    'Earrings',
    'Necklaces',
    'Bangles',
  ],
  "Fashion & Clothing|Kids|Kids' Clothing": [
    'Boys T-Shirts',
    'Girls Frocks',
    'Ethnic Sets',
  ],
  'Fashion & Clothing|Kids|Footwear': [
    'School Shoes',
    'Sports Shoes',
  ],
  'Fashion & Clothing|Footwear & More|Footwear': [
    'Sneakers',
    'Loafers',
    'Running Shoes',
  ],
  'Fashion & Clothing|Footwear & More|Bags & Backpacks': [
    'Handbags',
    'Backpacks',
    'Wallets',
  ],
  'Fashion & Clothing|Footwear & More|Watches': [
    'Men Analog',
    'Women Analog',
    'Couple Sets',
  ],
  'Fashion & Clothing|Footwear & More|Sunglasses & Accessories': [
    'Aviators',
    'Wayfarers',
    'Belts',
  ],
  // ---- 3. HOME ----
  'Home & Kitchen|Kitchen|Kitchen Appliances': [
    'Mixer Grinders',
    'Air Fryers',
    'Electric Kettles',
  ],
  'Home & Kitchen|Kitchen|Cookware & Kitchen Tools': [
    'Non-Stick Sets',
    'Pressure Cookers',
    'Knife Sets',
  ],
  'Home & Kitchen|Kitchen|Dinnerware': [
    'Dinner Sets',
    'Serving Bowls',
    'Water Bottles',
  ],
  'Home & Kitchen|Home|Storage & Organizers': [
    'Containers',
    'Kitchen Racks',
    'Wardrobe Organizers',
  ],
  'Home & Kitchen|Home|Home Decor': [
    'Wall Paintings',
    'Photo Frames',
    'Showpieces',
  ],
  'Home & Kitchen|Home|Furniture': [
    'Sofas',
    'Beds',
    'Coffee Tables',
  ],
  'Home & Kitchen|Home|Lighting': [
    'Table Lamps',
    'Ceiling Lights',
    'LED Bulbs',
  ],
  'Home & Kitchen|Bed & Bath|Bedding & Pillows': [
    'Bedsheets',
    'Pillows',
    'Blankets',
  ],
  'Home & Kitchen|Bed & Bath|Bathroom Accessories': [
    'Towel Sets',
    'Soap Dispensers',
    'Bath Mats',
  ],
  'Home & Kitchen|Bed & Bath|Cleaning Supplies': [
    'Floor Cleaners',
    'Mops & Brooms',
    'Detergents',
  ],
  // ---- 4. BEAUTY ----
  'Beauty & Personal Care|Skincare|Skincare': [
    'Moisturizers',
    'Face Wash',
    'Sunscreen',
    'Serums',
  ],
  'Beauty & Personal Care|Skincare|Bath & Body Care': [
    'Body Lotions',
    'Soap Bars',
    'Shower Gels',
  ],
  'Beauty & Personal Care|Skincare|Personal Hygiene': [
    'Sanitary Pads',
    'Razors',
    'Intimate Wash',
  ],
  'Beauty & Personal Care|Makeup|Makeup & Cosmetics': [
    'Lipstick',
    'Foundation',
    'Compact',
  ],
  'Beauty & Personal Care|Makeup|Beauty Tools': [
    'Brushes Set',
    'Beauty Blender',
    'Eyelash Curler',
  ],
  'Beauty & Personal Care|Makeup|Perfumes & Fragrances': [
    'Eau De Parfum',
    'Deodorants',
    'Attars',
  ],
  'Beauty & Personal Care|Haircare|Haircare': [
    'Shampoo',
    'Conditioner',
    'Hair Oils',
  ],
  "Beauty & Personal Care|Grooming|Men's Grooming": [
    'Beard Oil',
    'Shaving Cream',
    'Face Wash Men',
  ],
  'Beauty & Personal Care|Grooming|Oral Care': [
    'Toothpaste',
    'Toothbrushes',
    'Mouthwash',
  ],
  // ---- 5. SPORTS ----
  'Sports & Fitness|Fitness|Gym & Fitness Equipment': [
    'Dumbbells',
    'Resistance Bands',
    'Benches',
  ],
  'Sports & Fitness|Fitness|Yoga Accessories': [
    'Yoga Mats',
    'Yoga Blocks',
    'Straps',
  ],
  'Sports & Fitness|Fitness|Fitness Accessories': [
    'Gym Gloves',
    'Shakers',
    'Skipping Ropes',
  ],
  'Sports & Fitness|Shoes & Wear|Sports Shoes': [
    'Running Shoes',
    'Training Shoes',
    'Badminton Shoes',
  ],
  'Sports & Fitness|Shoes & Wear|Sportswear': [
    'Dry-Fit T-Shirts',
    'Track Pants',
    'Shorts',
  ],
  'Sports & Fitness|Games|Cricket Equipment': [
    'Bats',
    'Leather Balls',
    'Kits',
  ],
  'Sports & Fitness|Games|Football': [
    'Footballs',
    'Goalkeeper Gloves',
    'Studs',
  ],
  'Sports & Fitness|Games|Badminton & Tennis': [
    'Rackets',
    'Shuttlecocks',
    'Tennis Balls',
  ],
  'Sports & Fitness|Outdoor|Cycling Accessories': [
    'Helmets',
    'Lights & Locks',
    'Pumps',
  ],
  'Sports & Fitness|Outdoor|Outdoor & Camping': [
    'Tents',
    'Sleeping Bags',
    'Backpacks',
  ],
  // ---- 6. BOOKS ----
  'Books, Stationery & Office|Books|Educational Books': [
    'NCERT Texts',
    'Reference Guides',
  ],
  'Books, Stationery & Office|Books|Competitive Exam Books': [
    'UPSC Guides',
    'Banking & SSC',
    'TNPSC Guides',
  ],
  'Books, Stationery & Office|Books|Fiction & Non-Fiction': [
    'Bestsellers',
    'Biographies',
    'Self-Help',
  ],
  "Books, Stationery & Office|Books|Children's Books": [
    'Story Books',
    'Colouring Books',
    'Rhymes',
  ],
  'Books, Stationery & Office|Stationery|Notebooks & Registers': [
    'Long Notebooks',
    'Registers',
    'Diaries',
  ],
  'Books, Stationery & Office|Stationery|Pens & Pencils': [
    'Ball Pens',
    'Gel Pens',
    'Pencils & Erasers',
  ],
  'Books, Stationery & Office|Stationery|School Supplies': [
    'School Bags',
    'Lunch Boxes',
    'Water Bottles',
  ],
  'Books, Stationery & Office|Stationery|Art & Craft Supplies': [
    'Crayons',
    'Sketch Pens',
    'Craft Paper',
  ],
  'Books, Stationery & Office|Office|Office Stationery': [
    'Files & Folders',
    'Staplers',
    'Sticky Notes',
  ],
  'Books, Stationery & Office|Office|Office Accessories': [
    'Desk Organizers',
    'Calculators',
    'Table Clocks',
  ],
  // ---- 7. AUTO ----
  'Automotive & Accessories|Car|Car Accessories': [
    'Seat Covers',
    'Floor Mats',
    'Phone Holders',
  ],
  'Automotive & Accessories|Car|Car Electronics': [
    'Dash Cams',
    'Car Chargers',
    'Speakers',
  ],
  'Automotive & Accessories|Car|Car Cleaning Products': [
    'Shampoo',
    'Microfiber Cloths',
    'Polish',
  ],
  'Automotive & Accessories|Bike|Bike & Scooter Accessories': [
    'Bike Covers',
    'Mobile Holders',
    'Foot Mats',
  ],
  'Automotive & Accessories|Bike|Helmets & Riding Gear': [
    'Full-Face Helmets',
    'Gloves',
    'Riding Jackets',
  ],
  'Automotive & Accessories|Parts|Vehicle Spare Parts': [
    'Brake Pads',
    'Filters',
    'Spark Plugs',
  ],
  'Automotive & Accessories|Parts|Tyres & Batteries': [
    'Tubeless Tyres',
    'Car Batteries',
    'Alloys',
  ],
  'Automotive & Accessories|Parts|Engine Oils & Lubricants': [
    'Engine Oil 10W30',
    'Chain Lube',
    'Coolants',
  ],
  'Automotive & Accessories|Essentials|Vehicle Tools': [
    'Tool Kits',
    'Puncture Kits',
    'Air Pumps',
  ],
  'Automotive & Accessories|Essentials|Car & Bike Covers': [
    'Waterproof Covers',
    'UV Covers',
    'Dust Covers',
  ],
  // ---- 8. TOYS ----
  'Toys, Kids & Pet Supplies|Baby|Baby Care': [
    'Diapers',
    'Baby Wipes',
    'Lotions',
  ],
  'Toys, Kids & Pet Supplies|Baby|Baby Feeding & Accessories': [
    'Feeding Bottles',
    'Sippers',
    'Bibs',
  ],
  'Toys, Kids & Pet Supplies|Baby|Baby Gear': [
    'Strollers',
    'Car Seats',
    'Walkers',
  ],
  'Toys, Kids & Pet Supplies|Toys|Educational Toys': [
    'Learning Tablets',
    'Alphabet Sets',
    'Numbers',
  ],
  'Toys, Kids & Pet Supplies|Toys|Dolls & Soft Toys': [
    'Barbie Dolls',
    'Teddy Bears',
    'Action Figures',
  ],
  'Toys, Kids & Pet Supplies|Toys|Building Blocks & Puzzles': [
    'LEGO Sets',
    'Jigsaw 500pc',
    'Cubes',
  ],
  'Toys, Kids & Pet Supplies|Toys|Remote-Controlled Toys': [
    'RC Cars',
    'RC Helicopters',
    'Drones Kids',
  ],
  'Toys, Kids & Pet Supplies|Toys|Board Games': [
    'Chess',
    'Ludo',
    'Monopoly',
  ],
  'Toys, Kids & Pet Supplies|Pets|Dog Supplies': [
    'Dog Food',
    'Chew Toys',
    'Leashes',
  ],
  'Toys, Kids & Pet Supplies|Pets|Cat Supplies': [
    'Cat Food',
    'Litter',
    'Scratching Posts',
  ],
  'Toys, Kids & Pet Supplies|Pets|Pet Food & Accessories': [
    'Fish Food',
    'Bowls',
    'Grooming Kits',
  ],
};

/// Tabs with leafs resolved (single lookup for screens).
List<CatTab> tabsFor(String categoryLabel) {
  final tabs = categoryTree[categoryLabel];
  if (tabs == null) return const [];
  return [
    for (final t in tabs)
      CatTab(
        name: t.name,
        icon: t.icon,
        groups: [
          for (final g in t.groups)
            CatGroup(
              name: g.name,
              icon: g.icon,
              leafs: _l(_leafNames[
                      '$categoryLabel|${t.name}|${g.name}'] ??
                  const []),
            ),
        ],
      ),
  ];
}
