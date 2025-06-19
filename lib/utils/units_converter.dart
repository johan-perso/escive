String humanReadableDistance(dynamic distance, String fromUnit) {
  if(distance.runtimeType != double){
    try { // try to parse another way, in case if it's a string or a double
      distance = double.parse(distance.toString());
    } catch (e) {
      distance = 0;
    }
  }
  distance ??= 0; // set distance to 0 if still null

  if(fromUnit == 'km') distance = distance * 1000; // unit of the distance, will be converted to meters

  String? readableDistance;

  if(distance < 1000){
    readableDistance = "${distance.toStringAsFixed(0)} m";
  } else {
    readableDistance = "${(distance/1000).toStringAsFixed(1)} km";
  }

  if(readableDistance.contains('.0 ')) readableDistance = readableDistance.replaceAll('.0 ', ' ');
  return readableDistance.replaceAll('.', ',');
}