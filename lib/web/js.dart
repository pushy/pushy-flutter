library js;

// Require 'package:js' only on Web, otherwise fallback to 'js_fallback'
export 'package:js/js.dart'
    if (dart.library.js) 'package:js/js.dart' // Browser / Node.js
    if (dart.library.io) './js_fallback.js'; // Android / iOS
