import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Map iconsMap = {
  "home": LucideIcons.house,
  "sofa": LucideIcons.sofa,
  "hotel": LucideIcons.hotel,

  "work": LucideIcons.briefcaseBusiness,
  "university": LucideIcons.university,
  "school": LucideIcons.school,
  "church": LucideIcons.church,

  "book": LucideIcons.bookOpen,
  "library": LucideIcons.library,

  "theater": LucideIcons.theater,
  "popcorn": LucideIcons.popcorn,
  "piano": LucideIcons.piano,
  "drums": LucideIcons.drum,
  "guitar": LucideIcons.guitar,
  "boombox": LucideIcons.boomBox,

  "bank": LucideIcons.landmark,
  "keys": LucideIcons.keySquare,
  "store": LucideIcons.store,
  "shoppingcart": LucideIcons.shoppingCart,
  "package": LucideIcons.package,

  "cake": LucideIcons.cake,
  "pizza": LucideIcons.pizza,
  "burger": LucideIcons.hamburger,
  "beef": LucideIcons.beef,
  "ham": LucideIcons.ham,
  "carrot": LucideIcons.carrot,
  "wheat": LucideIcons.wheat,
  "coffee": LucideIcons.coffee,

  "gym": LucideIcons.dumbbell,
  "activity": LucideIcons.activity,
  "bike": LucideIcons.bike,
  "pool": LucideIcons.wavesLadder,
  "volleyball": LucideIcons.volleyball,

  "heart": LucideIcons.heart,
  "pawprint": LucideIcons.pawPrint,
  "cat": LucideIcons.cat,
  "dog": LucideIcons.dog,
  "rabbit": LucideIcons.rabbit,
  "turtle": LucideIcons.turtle,
  "bird": LucideIcons.bird,
  "rat": LucideIcons.rat,
  "panda": LucideIcons.panda,

  "forest": LucideIcons.trees,
  "treepalm": LucideIcons.treePalm,

  "bus": LucideIcons.busFront,
  "car": LucideIcons.carFront,
  "tram": LucideIcons.tramFront,
  "train": LucideIcons.trainFront,
  "plane": LucideIcons.plane,

  "star": LucideIcons.star,
  "question": Icons.question_mark_rounded,
};

IconData iconFromString(String string) {
  if (iconsMap.containsKey(string)) {
    return iconsMap[string];
  } else {
    return Icons.question_mark_rounded;
  }
}