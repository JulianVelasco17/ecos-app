import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Paleta Pantone ──────────────────────────────────────
const _paleta = [
  // ── Colores del año Pantone ──────────────────────────────
  (Color(0xFFFFBE98), 'Peach Fuzz',        'Pelusa de durazno'),    // 2024
  (Color(0xFFBB2649), 'Viva Magenta',      'Magenta vivo'),         // 2023
  (Color(0xFF6667AB), 'Very Peri',         'Azul perivenka'),       // 2022
  (Color(0xFFF5DF4D), 'Illuminating',      'Amarillo iluminador'),  // 2021
  (Color(0xFF939597), 'Ultimate Gray',     'Gris definitivo'),      // 2021
  (Color(0xFF0F4C81), 'Classic Blue',      'Azul clásico'),         // 2020
  (Color(0xFFFF6B6B), 'Living Coral',      'Coral vivo'),           // 2019
  (Color(0xFF5F4B8B), 'Ultra Violet',      'Ultravioleta'),         // 2018
  (Color(0xFF88B04B), 'Greenery',          'Verde naturaleza'),     // 2017
  (Color(0xFFF7CAC9), 'Rose Quartz',       'Cuarzo rosa'),          // 2016
  (Color(0xFF92A8D1), 'Serenity',          'Serenidad'),            // 2016
  (Color(0xFF955251), 'Marsala',           'Vino marsala'),         // 2015
  (Color(0xFFAD5E99), 'Radiant Orchid',    'Orquídea radiante'),    // 2014
  (Color(0xFF009473), 'Emerald',           'Verde esmeralda'),      // 2013
  (Color(0xFFDD4132), 'Tangerine Tango',   'Tango mandarina'),      // 2012
  (Color(0xFFD94F70), 'Honeysuckle',       'Rosa madreselva'),      // 2011
  (Color(0xFF45B5AA), 'Turquoise',         'Turquesa'),             // 2010
  (Color(0xFFEFC050), 'Mimosa',            'Amarillo mimosa'),      // 2009
  (Color(0xFF5A5B9F), 'Blue Iris',         'Azul iris'),            // 2008
  (Color(0xFF9B1B30), 'Chili Pepper',      'Rojo chile'),           // 2007
  (Color(0xFFDECDBE), 'Sand Dollar',       'Arena de playa'),       // 2006
  (Color(0xFF53B0AE), 'Blue Turquoise',    'Azul turquesa'),        // 2005
  (Color(0xFFE2583E), 'Tigerlily',         'Lirio tigre'),          // 2004
  (Color(0xFF7BC4E2), 'Aqua Sky',          'Cielo acuático'),       // 2003
  (Color(0xFFBF1932), 'True Red',          'Rojo verdadero'),       // 2002
  (Color(0xFFC74375), 'Fuchsia Rose',      'Rosa fucsia'),          // 2001
  (Color(0xFF9BB7D4), 'Cerulean',          'Azul cerúleo'),         // 2000
  (Color(0xFFA47764), 'Mocha Mousse',      'Mousse de moca'),       // 2025

  // ── Rojos ────────────────────────────────────────────────
  (Color(0xFFFF2400), 'Scarlet',           'Escarlata'),
  (Color(0xFFDC143C), 'Crimson',           'Carmesí'),
  (Color(0xFFE52B50), 'Amaranth',          'Amaranto'),
  (Color(0xFFFF0038), 'Carmine',           'Carmín'),
  (Color(0xFFC80815), 'Venetian Red',      'Rojo veneciano'),
  (Color(0xFFB22222), 'Firebrick',         'Ladrillo fuego'),
  (Color(0xFF8B0000), 'Dark Red',          'Rojo oscuro'),
  (Color(0xFF800000), 'Maroon',            'Granate oscuro'),
  (Color(0xFF722F37), 'Wine',              'Vino'),
  (Color(0xFF4A0010), 'Bordeaux',          'Burdeos'),
  (Color(0xFF9D0038), 'Cranberry',         'Arándano rojo'),
  (Color(0xFF872657), 'Raspberry',         'Frambuesa'),
  (Color(0xFFA8516E), 'Rouge',             'Rubor'),
  (Color(0xFFDE3163), 'Cerise',            'Cereza'),
  (Color(0xFFE4717A), 'Candy Pink',        'Rosa caramelo'),
  (Color(0xFFF95A61), 'Carnation',         'Clavel'),
  (Color(0xFFFA8072), 'Salmon',            'Salmón'),
  (Color(0xFFCB4154), 'Brick Red',         'Rojo ladrillo'),
  (Color(0xFFAB4B52), 'English Red',       'Rojo inglés'),
  (Color(0xFF733635), 'Garnet',            'Granate'),
  (Color(0xFF5C0120), 'Oxblood',           'Sangre de toro'),
  (Color(0xFF922B21), 'Auburn',            'Caoba rojiza'),
  (Color(0xFF6E2B0C), 'Mahogany',          'Caoba'),
  (Color(0xFFA0522D), 'Sienna',            'Siena'),

  // ── Rosas ────────────────────────────────────────────────
  (Color(0xFFFF69B4), 'Hot Pink',          'Rosa intenso'),
  (Color(0xFFFF007F), 'Rose',              'Rosa'),
  (Color(0xFFFC8EAC), 'Flamingo Pink',     'Rosa flamenco'),
  (Color(0xFFFFC1CC), 'Bubblegum',         'Rosa chicle'),
  (Color(0xFFFFB7C5), 'Cherry Blossom',    'Flor de cerezo'),
  (Color(0xFFDE5D83), 'Blush',             'Rubor rosa'),
  (Color(0xFFDCAE96), 'Dusty Rose',        'Rosa polvo'),
  (Color(0xFFE75480), 'Deep Pink',         'Rosa profundo'),
  (Color(0xFFF4C2C2), 'Baby Pink',         'Rosa bebé'),
  (Color(0xFFFFD1DC), 'Pastel Pink',       'Rosa pastel'),
  (Color(0xFFC3447A), 'Magenta Haze',      'Magenta neblina'),
  (Color(0xFF915F6D), 'Mauve Taupe',       'Malva antiguo'),
  (Color(0xFFE0B0B0), 'Misty Rose',        'Rosa brumoso'),
  (Color(0xFFD4869D), 'Antique Pink',      'Rosa antiguo'),
  (Color(0xFFB76E79), 'Rose Gold',         'Oro rosa'),
  (Color(0xFFFF66CC), 'Ultra Pink',        'Rosa ultra'),
  (Color(0xFFFF85CF), 'Carnation Pink',    'Rosa clavel'),
  (Color(0xFFF72585), 'Vivid Pink',        'Rosa vívido'),
  (Color(0xFFCE4A7E), 'Mulberry',          'Mora'),
  (Color(0xFF8B3A75), 'Berry',             'Baya'),
  (Color(0xFF6A1E5A), 'Blackberry',        'Zarzamora'),

  // ── Naranjas ─────────────────────────────────────────────
  (Color(0xFFFF7518), 'Pumpkin',           'Calabaza'),
  (Color(0xFFFF4500), 'Orange Red',        'Rojo naranja'),
  (Color(0xFFFF6347), 'Tomato',            'Tomate'),
  (Color(0xFFCC5500), 'Burnt Orange',      'Naranja quemado'),
  (Color(0xFFEC5800), 'Persimmon',         'Caqui naranja'),
  (Color(0xFFB7410E), 'Rust',              'Óxido'),
  (Color(0xFFF37A48), 'Mandarin',          'Mandarina'),
  (Color(0xFFF28500), 'Tangerine',         'Tangerina'),
  (Color(0xFFE96F00), 'Clementine',        'Clementina'),
  (Color(0xFFFFBF00), 'Amber',             'Ámbar'),
  (Color(0xFFEAA221), 'Marigold',          'Caléndula'),
  (Color(0xFFE3963E), 'Butterscotch',      'Caramelo suave'),
  (Color(0xFFD2691E), 'Cinnamon',          'Canela'),
  (Color(0xFFB87333), 'Copper',            'Cobre'),
  (Color(0xFFFFCBA4), 'Peach',             'Melocotón'),
  (Color(0xFFFBCEB1), 'Apricot',           'Albaricoque'),
  (Color(0xFFFF9966), 'Atomic Tangerine',  'Tangerina atómica'),
  (Color(0xFFFFA07A), 'Light Salmon',      'Salmón claro'),
  (Color(0xFFFF7043), 'Deep Orange',       'Naranja intenso'),
  (Color(0xFFE64A19), 'Burnt Sienna',      'Siena quemada'),
  (Color(0xFFFF8C00), 'Dark Orange',       'Naranja oscuro'),
  (Color(0xFFCD853F), 'Peru',              'Perú'),

  // ── Amarillos ────────────────────────────────────────────
  (Color(0xFFFFD700), 'Gold',              'Oro'),
  (Color(0xFFFFF44F), 'Lemon',             'Limón'),
  (Color(0xFFFFFF99), 'Canary',            'Canario'),
  (Color(0xFFFFE135), 'Banana',            'Plátano'),
  (Color(0xFFFFDB58), 'Mustard',           'Mostaza'),
  (Color(0xFFF4C430), 'Saffron',           'Azafrán'),
  (Color(0xFFE4D96F), 'Straw',             'Paja'),
  (Color(0xFFDFFF00), 'Chartreuse Yellow', 'Chartreuse'),
  (Color(0xFFEEDC82), 'Flax',              'Lino'),
  (Color(0xFFF3E5AB), 'Vanilla',           'Vainilla'),
  (Color(0xFFFFFDD0), 'Cream',             'Crema'),
  (Color(0xFFFFF8DC), 'Cornsilk',          'Maíz'),
  (Color(0xFFB8860B), 'Dark Goldenrod',    'Golondrina oscura'),
  (Color(0xFFDAA520), 'Goldenrod',         'Vara de oro'),
  (Color(0xFFFFC000), 'Golden Yellow',     'Amarillo dorado'),
  (Color(0xFFE2D58B), 'Pale Yellow',       'Amarillo pálido'),
  (Color(0xFFF9E4B7), 'Vanilla Cream',     'Crema vainilla'),
  (Color(0xFFD4B483), 'Wheat Gold',        'Trigo dorado'),
  (Color(0xFFD4A76A), 'Honey',             'Miel'),
  (Color(0xFFE8C07D), 'Sandy Gold',        'Oro arena'),
  (Color(0xFFF2D7A0), 'Pale Gold',         'Oro pálido'),
  (Color(0xFFCE9B6E), 'Warm Caramel',      'Caramelo cálido'),

  // ── Verdes ───────────────────────────────────────────────
  (Color(0xFF98FF98), 'Mint Green',        'Verde menta'),
  (Color(0xFF00A86B), 'Jade',              'Jade'),
  (Color(0xFF71EEB8), 'Seafoam',           'Espuma de mar'),
  (Color(0xFF8DB600), 'Apple Green',       'Verde manzana'),
  (Color(0xFF4F7942), 'Fern',              'Helecho'),
  (Color(0xFF8A9A5B), 'Moss',              'Musgo'),
  (Color(0xFF355E3B), 'Hunter Green',      'Verde caza'),
  (Color(0xFF228B22), 'Forest Green',      'Verde bosque'),
  (Color(0xFF006400), 'Dark Green',        'Verde oscuro'),
  (Color(0xFF2E8B57), 'Sea Green',         'Verde mar'),
  (Color(0xFF3CB371), 'Medium Sea Green',  'Verde mar medio'),
  (Color(0xFF93C572), 'Pistachio',         'Pistacho'),
  (Color(0xFF568203), 'Avocado',           'Aguacate'),
  (Color(0xFF4D5D53), 'Kale',              'Col rizada'),
  (Color(0xFF44D7A8), 'Eucalyptus',        'Eucalipto'),
  (Color(0xFFA2D5A4), 'Spearmint',         'Hierbabuena'),
  (Color(0xFFACE1AF), 'Celadon',           'Celadón'),
  (Color(0xFF808000), 'Olive',             'Oliva'),
  (Color(0xFF556B2F), 'Dark Olive',        'Oliva oscuro'),
  (Color(0xFF6B8E23), 'Olive Drab',        'Verde oliva'),
  (Color(0xFF9FA91F), 'Citron',            'Citrón'),
  (Color(0xFFBCB88A), 'Sage',              'Salvia'),
  (Color(0xFF40826D), 'Viridian',          'Viridiano'),
  (Color(0xFF0BDA51), 'Malachite',         'Malaquita'),
  (Color(0xFF00827F), 'Teal',              'Verde azulado'),
  (Color(0xFF7FFFD4), 'Aquamarine',        'Aguamarina'),
  (Color(0xFF50C878), 'Emerald Green',     'Esmeralda vivo'),
  (Color(0xFF00A693), 'Persian Teal',      'Teal persa'),
  (Color(0xFF4CAF50), 'Green',             'Verde'),
  (Color(0xFF8BC34A), 'Light Green',       'Verde claro'),
  (Color(0xFFCDDC39), 'Lime Green',        'Verde lima'),
  (Color(0xFF66BB6A), 'Meadow',            'Pradera'),
  (Color(0xFF388E3C), 'Deep Green',        'Verde profundo'),
  (Color(0xFF1B5E20), 'Dark Forest',       'Bosque oscuro'),
  (Color(0xFF69B076), 'Laurel',            'Laurel'),
  (Color(0xFF007355), 'Pine Green',        'Verde pino'),
  (Color(0xFF2AAA8A), 'Persian Green',     'Verde persa'),
  (Color(0xFF708238), 'Yellow Green',      'Verde amarillo'),
  (Color(0xFF9DC183), 'Pistachio Light',   'Pistacho claro'),
  (Color(0xFF57CC99), 'Medium Green',      'Verde mediano'),
  (Color(0xFF80ED99), 'Pale Green',        'Verde pálido'),
  (Color(0xFF77DD77), 'Pastel Green',      'Verde pastel'),
  (Color(0xFFC7F2A4), 'Pale Mint',         'Menta pálida'),
  (Color(0xFFADDFAD), 'Celadon Green',     'Verde celadón'),
  (Color(0xFF90EE90), 'Light Green',       'Verde luz'),

  // ── Azules ───────────────────────────────────────────────
  (Color(0xFF87CEEB), 'Sky Blue',          'Azul cielo'),
  (Color(0xFF89CFF0), 'Baby Blue',         'Azul bebé'),
  (Color(0xFFB0E0E6), 'Powder Blue',       'Azul polvo'),
  (Color(0xFF6495ED), 'Cornflower',        'Aciano'),
  (Color(0xFF0047AB), 'Cobalt',            'Cobalto'),
  (Color(0xFF001F5B), 'Navy',              'Azul marino'),
  (Color(0xFF191970), 'Midnight Blue',     'Azul medianoche'),
  (Color(0xFF4169E1), 'Royal Blue',        'Azul real'),
  (Color(0xFF1560BD), 'Denim',             'Denim'),
  (Color(0xFF4682B4), 'Steel Blue',        'Azul acero'),
  (Color(0xFF007FFF), 'Azure',             'Azur'),
  (Color(0xFF007BA7), 'Cerulean Blue',     'Azul cerúleo'),
  (Color(0xFF0ABAB5), 'Tiffany Blue',      'Azul Tiffany'),
  (Color(0xFFADD8E6), 'Light Blue',        'Azul claro'),
  (Color(0xFF5F9EA0), 'Cadet Blue',        'Azul cadete'),
  (Color(0xFF00BFFF), 'Deep Sky Blue',     'Cielo profundo'),
  (Color(0xFF1E90FF), 'Dodger Blue',       'Azul dodger'),
  (Color(0xFF4B9CD3), 'Carolina Blue',     'Azul Carolina'),
  (Color(0xFF0D98BA), 'Pacific Blue',      'Azul Pacífico'),
  (Color(0xFF2E86C1), 'Bright Blue',       'Azul brillante'),
  (Color(0xFF1A5276), 'Dark Blue',         'Azul oscuro'),
  (Color(0xFF0E4D92), 'Yale Blue',         'Azul Yale'),
  (Color(0xFF003153), 'Prussian Blue',     'Azul prusiano'),
  (Color(0xFF002868), 'Ultramarine',       'Ultramar'),
  (Color(0xFFD6ECEF), 'Ice Blue',          'Azul hielo'),
  (Color(0xFFCCCCFF), 'Periwinkle',        'Pervinca'),
  (Color(0xFF5072A7), 'Blue Yonder',       'Azul distante'),
  (Color(0xFF6699CC), 'Light Cornflower',  'Aciano claro'),
  (Color(0xFF0093AF), 'Cyan Process',      'Cian proceso'),
  (Color(0xFF00CED1), 'Dark Turquoise',    'Turquesa oscuro'),
  (Color(0xFF40E0D0), 'Medium Turquoise',  'Turquesa medio'),
  (Color(0xFFAFEEEE), 'Pale Turquoise',    'Turquesa pálido'),
  (Color(0xFF81D4FA), 'Pale Sky',          'Cielo pálido'),
  (Color(0xFF4FC3F7), 'Bright Sky',        'Cielo brillante'),
  (Color(0xFF039BE5), 'Vivid Blue',        'Azul vívido'),
  (Color(0xFF0277BD), 'Medium Blue',       'Azul medio'),
  (Color(0xFF01579B), 'Deep Ocean',        'Océano profundo'),
  (Color(0xFF4361EE), 'Bright Indigo',     'Índigo brillante'),
  (Color(0xFF4895EF), 'Medium Indigo',     'Índigo medio'),
  (Color(0xFF4CC9F0), 'Sky Cyan',          'Cian cielo'),
  (Color(0xFF4ECDC4), 'Medium Aqua',       'Agua medio'),
  (Color(0xFF3BCEAC), 'Pale Teal',         'Teal pálido'),
  (Color(0xFF1B998B), 'Medium Teal',       'Teal mediano'),
  (Color(0xFF008D8B), 'Teal Green',        'Teal verdoso'),
  (Color(0xFF006D77), 'Deep Teal',         'Teal profundo'),
  (Color(0xFF004D40), 'Darkest Teal',      'Teal oscuro'),

  // ── Púrpuras y violetas ───────────────────────────────────
  (Color(0xFFE6E6FA), 'Lavender',          'Lavanda'),
  (Color(0xFFC8A2C8), 'Lilac',             'Lila'),
  (Color(0xFFEE82EE), 'Violet',            'Violeta'),
  (Color(0xFFDDA0DD), 'Plum',              'Ciruela'),
  (Color(0xFF6F2DA8), 'Grape',             'Uva'),
  (Color(0xFF9966CC), 'Amethyst',          'Amatista'),
  (Color(0xFFC9A0DC), 'Wisteria',          'Glicina'),
  (Color(0xFFD8BFD8), 'Thistle',           'Cardo'),
  (Color(0xFFDA70D6), 'Orchid',            'Orquídea'),
  (Color(0xFFFF00FF), 'Magenta',           'Magenta'),
  (Color(0xFF614051), 'Eggplant',          'Berenjena'),
  (Color(0xFF3D0734), 'Aubergine',         'Aubergine'),
  (Color(0xFF702963), 'Byzantium',         'Bizantino'),
  (Color(0xFF4B0082), 'Indigo',            'Índigo'),
  (Color(0xFF8B008B), 'Dark Magenta',      'Magenta oscuro'),
  (Color(0xFF9400D3), 'Dark Violet',       'Violeta oscuro'),
  (Color(0xFF8B00FF), 'Electric Violet',   'Violeta eléctrico'),
  (Color(0xFF7B2FBE), 'Purple',            'Púrpura'),
  (Color(0xFF6A0DAD), 'Dark Purple',       'Púrpura oscuro'),
  (Color(0xFF4E1A45), 'Deep Purple',       'Púrpura profundo'),
  (Color(0xFFB29FBA), 'Heather',           'Brezo'),
  (Color(0xFFE0B0FF), 'Mauve',             'Malva'),
  (Color(0xFFA57BB7), 'African Violet',    'Violeta africana'),
  (Color(0xFF7E5CAD), 'Medium Purple',     'Púrpura medio'),
  (Color(0xFF9B59B6), 'Vivid Purple',      'Púrpura vívido'),
  (Color(0xFFEAD3F5), 'Pale Lavender',     'Lavanda pálida'),
  (Color(0xFF6C3483), 'Deep Violet',       'Violeta profundo'),
  (Color(0xFF5B2C6F), 'Dark Plum',         'Ciruela oscura'),
  (Color(0xFFBA55D3), 'Medium Orchid',     'Orquídea media'),
  (Color(0xFFB5179E), 'Purple Pink',       'Rosa púrpura'),
  (Color(0xFF7209B7), 'Vivid Violet',      'Violeta vívido'),
  (Color(0xFF3A0CA3), 'Deep Indigo',       'Índigo profundo'),
  (Color(0xFF7A2B68), 'Dark Berry',        'Baya oscura'),

  // ── Marrones y tierras ────────────────────────────────────
  (Color(0xFF7B3F00), 'Chocolate',         'Chocolate'),
  (Color(0xFF8B4513), 'Saddle Brown',      'Cuero marrón'),
  (Color(0xFF954535), 'Chestnut',          'Castaño'),
  (Color(0xFF5C3A1E), 'Walnut',            'Nogal'),
  (Color(0xFF2F1B0E), 'Espresso',          'Espresso'),
  (Color(0xFF3E2723), 'Deep Brown',        'Marrón profundo'),
  (Color(0xFF6D4C41), 'Brown',             'Marrón'),
  (Color(0xFF795548), 'Medium Brown',      'Marrón medio'),
  (Color(0xFF8D6E63), 'Light Brown',       'Marrón claro'),
  (Color(0xFFA1887F), 'Rosy Brown',        'Marrón rosado'),
  (Color(0xFFA57C52), 'Hazelnut',          'Avellana'),
  (Color(0xFFB5925A), 'Latte',             'Latte'),
  (Color(0xFF967259), 'Mocha Brown',       'Moca marrón'),
  (Color(0xFF806517), 'Oak',               'Roble'),
  (Color(0xFFAB917A), 'Driftwood',         'Madera flotante'),
  (Color(0xFFC3B091), 'Khaki',             'Caqui'),
  (Color(0xFFC2B280), 'Ecru',              'Crudo'),
  (Color(0xFF483C32), 'Taupe',             'Taupe'),
  (Color(0xFF928E7E), 'Stone',             'Piedra'),
  (Color(0xFF878370), 'Pebble',            'Guijarro'),
  (Color(0xFFB8A89A), 'Greige',            'Greige'),
  (Color(0xFFA9927D), 'Mushroom',          'Champiñón'),
  (Color(0xFFD2B48C), 'Tan',               'Tostado'),
  (Color(0xFFF5DEB3), 'Wheat',             'Trigo'),
  (Color(0xFFEFDECD), 'Almond',            'Almendra'),
  (Color(0xFFFFE4C4), 'Bisque',            'Bisque'),
  (Color(0xFFF5F5DC), 'Beige',             'Beige'),
  (Color(0xFFFAF0E6), 'Linen',             'Lino'),
  (Color(0xFFE8DCC8), 'Parchment',         'Pergamino'),
  (Color(0xFFD5C5A1), 'Buff',              'Ante'),
  (Color(0xFFC8A882), 'Camel',             'Camello'),
  (Color(0xFF997950), 'Buckskin',          'Cuero claro'),
  (Color(0xFF7A6040), 'Umber',             'Sombra'),
  (Color(0xFF5C4A30), 'Coffee',            'Café'),
  (Color(0xFF8B6914), 'Dark Honey',        'Miel oscura'),
  (Color(0xFF6B4F1F), 'Bark',              'Corteza'),

  // ── Grises ───────────────────────────────────────────────
  (Color(0xFFF5F5F5), 'White Smoke',       'Humo blanco'),
  (Color(0xFFEEEEEE), 'Near White',        'Casi blanco'),
  (Color(0xFFE0E0E0), 'Light Gray',        'Gris claro'),
  (Color(0xFFCECECE), 'Silver Gray',       'Gris plata'),
  (Color(0xFFBDBDBD), 'Medium Gray',       'Gris medio'),
  (Color(0xFF9E9E9E), 'Gray',              'Gris'),
  (Color(0xFF757575), 'Dark Gray',         'Gris oscuro'),
  (Color(0xFF616161), 'Dim Gray',          'Gris tenue'),
  (Color(0xFF474A51), 'Graphite',          'Grafito'),
  (Color(0xFF36454F), 'Charcoal',          'Carbón'),
  (Color(0xFF2F2F2F), 'Jet',               'Azabache'),
  (Color(0xFFB2BEB5), 'Ash',               'Ceniza'),
  (Color(0xFF96A8A1), 'Pewter',            'Peltre'),
  (Color(0xFFA8A9AD), 'Silver',            'Plata'),
  (Color(0xFFD4CFCF), 'Fog',               'Niebla'),
  (Color(0xFF8A8D8F), 'Storm Gray',        'Gris tormenta'),
  (Color(0xFF6D6E70), 'Slate Gray',        'Gris pizarra'),
  (Color(0xFF54585A), 'Cool Gray',         'Gris frío'),
  (Color(0xFF807F83), 'French Gray',       'Gris francés'),
  (Color(0xFFD0D0CE), 'Pale Silver',       'Plata pálida'),
  (Color(0xFF4E5356), 'Gunmetal',          'Gris acero'),
  (Color(0xFF738290), 'Blue Gray',         'Gris azulado'),
  (Color(0xFF708090), 'Slate',             'Pizarra'),
  (Color(0xFF778899), 'Light Slate',       'Pizarra clara'),
  (Color(0xFF8FBC8F), 'Dark Sea',          'Mar oscuro'),

  // ── Blancos y perlas ─────────────────────────────────────
  (Color(0xFFFFFAFA), 'Snow',              'Nieve'),
  (Color(0xFFF0EAD6), 'Eggshell',          'Cáscara de huevo'),
  (Color(0xFFFFF8E7), 'Cosmic Latte',      'Latte cósmico'),
  (Color(0xFFF0F8FF), 'Alice Blue',        'Azul Alicia'),
  (Color(0xFFF5FFFA), 'Mint Cream',        'Crema menta'),
  (Color(0xFFFFFAF0), 'Floral White',      'Blanco floral'),
  (Color(0xFFF8F0E3), 'Old Lace',          'Encaje antiguo'),
  (Color(0xFFEDEAE0), 'Bone',              'Hueso'),
  (Color(0xFFE8E0D0), 'Pearl White',       'Blanco perla'),
  (Color(0xFFD4C5A9), 'Warm Parchment',    'Pergamino cálido'),
  (Color(0xFFFDE9C9), 'Soft Peach',        'Melocotón suave'),
  (Color(0xFFF8D7DA), 'Pale Blush',        'Rubor pálido'),
  (Color(0xFFF5C6CB), 'Soft Pink',         'Rosa suave'),
  (Color(0xFFF3D4E0), 'Pale Rose',         'Rosa pálido'),
  (Color(0xFFE8C4D4), 'Dusty Pink',        'Rosa polvo suave'),
  (Color(0xFFF0F4C3), 'Pale Lime',         'Lima pálida'),
  (Color(0xFFE8F8E8), 'Honeydew',          'Melón dulce'),
  (Color(0xFFD0F0C0), 'Tea Green',         'Verde té'),
  (Color(0xFFE3F2FD), 'Pale Blue White',   'Azul pálido'),
  (Color(0xFFEDE7F6), 'Pale Violet',       'Violeta pálido'),
  (Color(0xFFFCE4EC), 'Pale Pink',         'Rosa muy pálido'),
  (Color(0xFFFFF3E0), 'Pale Amber',        'Ámbar pálido'),
  (Color(0xFFF1F8E9), 'Pale Green White',  'Verde pálido suave'),
];

(Color, String, String) colorDelDia({String uid = '', int offset = 0}) {
  final hoy = DateTime.now();
  final diaDelAno = hoy.difference(DateTime(hoy.year, 1, 1)).inDays;
  final semilla = diaDelAno * 31 + uid.codeUnits.fold<int>(0, (a, b) => a + b);
  return _paleta[((semilla + offset) * 137) % _paleta.length];
}

int totalColores() => _paleta.length;

String hexDeColor(Color color) {
  final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
  return '#$r$g$b'.toUpperCase();
}

// ─── Pantalla fullscreen del color ───────────────────────
class PantallaColorDelDia extends StatefulWidget {
  final Color color;
  final String nombre;
  final String nombreEs;

  const PantallaColorDelDia({
    super.key,
    required this.color,
    required this.nombre,
    required this.nombreEs,
  });

  @override
  State<PantallaColorDelDia> createState() => _PantallaColorDelDiaState();
}

class _PantallaColorDelDiaState extends State<PantallaColorDelDia> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final luminancia = widget.color.computeLuminance();
    final colorTexto = luminancia > 0.45 ? Colors.black54 : Colors.black87;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: widget.color,
        body: Center(
          child: AnimatedOpacity(
            opacity: _visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.nombreEs,
                  style: TextStyle(
                    color: colorTexto,
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '(${widget.nombre})',
                  style: TextStyle(
                    color: colorTexto.withValues(alpha: 0.45),
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Ruta con expansión circular ─────────────────────────
class CircularRevealRoute extends PageRoute<void> {
  final Color color;
  final String nombre;
  final String nombreEs;
  final Offset origen;

  CircularRevealRoute({
    required this.color,
    required this.nombre,
    required this.nombreEs,
    required this.origen,
  });

  @override
  Color get barrierColor => Colors.transparent;

  @override
  String get barrierLabel => '';

  @override
  bool get barrierDismissible => false;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 650);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 450);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return PantallaColorDelDia(color: color, nombre: nombre, nombreEs: nombreEs);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final size = MediaQuery.of(context).size;
    final radioFinal = sqrt(pow(size.width, 2) + pow(size.height, 2));

    final curva = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOut,
      reverseCurve: Curves.easeInOut,
    );

    return AnimatedBuilder(
      animation: curva,
      builder: (context, _) => ClipPath(
        clipper: _CircleClipper(
          centro: origen,
          radio: radioFinal * curva.value,
        ),
        child: child,
      ),
    );
  }
}

class _CircleClipper extends CustomClipper<Path> {
  final Offset centro;
  final double radio;

  _CircleClipper({required this.centro, required this.radio});

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: centro, radius: radio));

  @override
  bool shouldReclip(_CircleClipper old) => old.radio != radio;
}

// ─── Blob irregular (gris, revela color al expandirse) ───
class BlobColorDelDia extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  final bool revelado;

  const BlobColorDelDia({
    super.key,
    required this.onTap,
    required this.color,
    this.revelado = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        height: 72,
        child: CustomPaint(
          painter: _BlobPainter(color: revelado ? color : const Color(0xFF3A3A3A)),
        ),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final Color color;
  const _BlobPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final path = Path();
    path.moveTo(cx, cy - 32);
    path.cubicTo(cx + 22, cy - 34, cx + 38, cy - 14, cx + 34, cy + 10);
    path.cubicTo(cx + 30, cy + 28, cx + 12, cy + 36, cx - 6, cy + 34);
    path.cubicTo(cx - 26, cy + 32, cx - 38, cy + 12, cx - 34, cy - 8);
    path.cubicTo(cx - 30, cy - 26, cx - 16, cy - 30, cx, cy - 32);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.color != color;
}
