import 'app_settings.dart';

// All the words shown in the app, in English ('en') and Bisaya/Cebuano ('ceb').
// Use tr('key') in a screen. Use {name} placeholders for values:
//   tr('timer_every', {'n': '30'})
//
// NOTE: please have a native speaker review the Bisaya text before release.

const Map<String, Map<String, String>> _strings = {
  'en': {
    // Navigation and dialog
    'nav_home': 'Home',
    'nav_monitor': 'Monitor',
    'nav_weather': 'Weather',
    'nav_timer': 'Timer',
    'nav_menu': 'Menu',
    'dlg_turn_title': 'Time to turn the rice!',
    'dlg_turn_body': 'Turn (karaw) the rice, then stop the alarm.',
    'dlg_stop_alarm': 'Stop alarm',

    // Home
    'home_drying_advice': 'Drying advice',
    'home_advice_waiting': 'Waiting for the weather. Tap to open Weather.',
    'advice_good': 'Good to dry',
    'advice_caution': 'Caution',
    'advice_avoid': 'Avoid drying',
    'home_checked': 'checked {time}',
    'banner_avoid':
    'Your rice is drying, but rain is likely or falling. Cover the rice soon.',
    'banner_caution':
    'The weather is uncertain while your rice dries. Keep an eye on the sky.',
    'timer_title': 'Turn timer',
    'status_drying': 'Drying...',
    'status_paused': 'Paused',
    'status_ready': 'Ready',
    'timer_summary': 'Turn every {n} min  |  Turned {c} times',
    'btn_start': 'Start drying',
    'btn_pause': 'Pause',
    'btn_resume': 'Resume',
    'btn_stop': 'Stop',
    'btn_change_interval': 'Change interval',
    'btn_open_timer': 'Open timer',
    'bird_title': 'Bird protection',
    'bird_mon_on': 'Monitoring is ON',
    'bird_mon_off': 'Monitoring is OFF',
    'bird_today': 'Birds detected today: {n}',
    'bird_last': '(last: {time})',
    'pair_monitor': 'Pairing: monitor phone',
    'pair_receiver': 'Pairing: alert phone',
    'pair_none': 'Pairing: not paired',
    'alert_none': 'No alerts received yet',
    'alert_last': 'Last alert received: {time}',
    'btn_open_monitor': 'Open monitor',
    'activity_title': 'Recent activity',
    'activity_empty':
    'Nothing yet. Bird detections and turn reminders will appear here.',
    'act_bird': 'Bird detected',
    'act_turn': 'Time to turn the rice (turn #{n})',
    'act_alert': 'Bird alert received',

    // Timer screen
    'timer_turned': 'Times turned: {n}',
    'timer_every': 'Turn every {n} minutes',
    'timer_slider': '{n} min',

    // Menu
    'menu_settings': 'Settings',
    'menu_sound': 'Scare sound',
    'menu_language': 'Language',
    'menu_theme': 'Theme',
    'theme_light': 'Light',
    'theme_dark': 'Dark',
    'theme_system': 'Auto',
    'menu_more': 'More',
    'menu_support': 'Support',
    'menu_about': 'About us',
    'menu_licenses': 'Licenses',

    // Sounds
    'sound_default': 'Default',
    'sound_siren': 'Siren',
    'sound_pulse': 'Pulse beeps',
    'sound_warble': 'Warble',
    'sound_rotate': 'Rotate (random)',
    'sound_title': 'Choose the sound',
    'sound_hint': 'Tap play to hear a sound. Tap a row to choose it.',
    'sound_tip':
    'Birds can get used to one sound. "Rotate" mixes them to keep birds away longer.',
    'sound_error': 'Could not play this sound.',

    // Support
    'support_title': 'Support',
    'support_contact': 'Contact us',
    'support_copy': 'Copy email',
    'support_copied': 'Email copied',
    'support_faq': 'Quick help',
    'faq_sound_q': 'I cannot hear the scare sound',
    'faq_sound_a':
    'Turn up the phone media volume (not just the ringer) and check that the Scare sound switch is on.',
    'faq_notif_q': 'I do not get bird alerts',
    'faq_notif_a':
    'Both phones need internet. Allow notifications, keep the app open, and set battery use to No restrictions.',
    'faq_weather_q': 'The weather looks wrong',
    'faq_weather_a':
    'Turn on location (GPS) and pull down on the Weather tab to refresh. Forecasts can miss small showers, so look at the sky too.',
    'faq_pair_q': 'Pairing does not work',
    'faq_pair_a':
    'Both phones must be online. The code lasts 10 minutes, so make a new one if it expired.',

    // About
    'about_title': 'About us',
    'about_text':
    'BinuWatch is a rice-drying helper for farmers in Biliran. It tells you when the weather is good for drying, reminds you to turn the rice, and watches for birds and chickens.',
    'about_version': 'Version {v}',
    'about_made_by': 'Made by',
    'about_school': 'A student project of',

    // Licenses
    'lic_title': 'Licenses',
    'lic_open_source': 'Open-source licenses',
    'lic_open_source_sub': 'Licenses of the software this app is built with.',
    'lic_credits': 'Data and credits',
  },
  'ceb': {
    // Navigation and dialog
    'nav_home': 'Panimalay',
    'nav_monitor': 'Bantay',
    'nav_weather': 'Panahon',
    'nav_timer': 'Oras',
    'nav_menu': 'Menu',
    'dlg_turn_title': 'Panahon na sa pagbalik sa bugas!',
    'dlg_turn_body': 'Balika ang bugas, unya undanga ang alarma.',
    'dlg_stop_alarm': 'Undangi ang alarma',

    // Home
    'home_drying_advice': 'Tambag sa pagbuwad',
    'home_advice_waiting':
    'Naghulat sa panahon. Pindota aron ablihan ang Panahon.',
    'advice_good': 'Maayo mubuwad',
    'advice_caution': 'Pag-amping',
    'advice_avoid': 'Ayaw pagbuwad',
    'home_checked': 'gisusi {time}',
    'banner_avoid':
    'Nagbuwad ang imong bugas, apan lagmit mag-ulan o nag-ulan na. Tabuni dayon ang bugas.',
    'banner_caution':
    'Dili sigurado ang panahon samtang nagbuwad ang imong bugas. Bantayi ang langit.',
    'timer_title': 'Timer sa pagbalik',
    'status_drying': 'Nagbuwad...',
    'status_paused': 'Gi-pause',
    'status_ready': 'Andam',
    'timer_summary': 'Balihon matag {n} min  |  Gibalik {c} ka beses',
    'btn_start': 'Sugdi ang pagbuwad',
    'btn_pause': 'Pahunong',
    'btn_resume': 'Ipadayon',
    'btn_stop': 'Undangi',
    'btn_change_interval': 'Usba ang agwat',
    'btn_open_timer': 'Ablihi ang timer',
    'bird_title': 'Panalipod batok sa langgam',
    'bird_mon_on': 'Nagbantay na',
    'bird_mon_off': 'Wala nagbantay',
    'bird_today': 'Mga langgam nga nakit-an karon: {n}',
    'bird_last': '(katapusan: {time})',
    'pair_monitor': 'Pagpares: telepono nga nagbantay',
    'pair_receiver': 'Pagpares: telepono nga modawat sa alerto',
    'pair_none': 'Pagpares: wala pa napares',
    'alert_none': 'Wala pay nadawat nga alerto',
    'alert_last': 'Katapusang alerto nga nadawat: {time}',
    'btn_open_monitor': 'Ablihi ang bantay',
    'activity_title': 'Bag-ong mga panghitabo',
    'activity_empty':
    'Wala pa. Makita dinhi ang mga langgam nga nakit-an ug ang mga paghinumdom sa pagbalik.',
    'act_bird': 'Nakit-an ang langgam',
    'act_turn': 'Panahon na sa pagbalik sa bugas (#{n})',
    'act_alert': 'Nadawat ang alerto sa langgam',

    // Timer screen
    'timer_turned': 'Gibalik: {n} ka beses',
    'timer_every': 'Balihon matag {n} ka minuto',
    'timer_slider': '{n} min',

    // Menu
    'menu_settings': 'Mga Setting',
    'menu_sound': 'Tunog batok sa langgam',
    'menu_language': 'Pinulongan',
    'menu_theme': 'Tema',
    'theme_light': 'Hayag',
    'theme_dark': 'Ngitngit',
    'theme_system': 'Awtomatiko',
    'menu_more': 'Dugang',
    'menu_support': 'Suporta',
    'menu_about': 'Mahitungod kanamo',
    'menu_licenses': 'Mga lisensya',

    // Sounds
    'sound_default': 'Default',
    'sound_siren': 'Siren',
    'sound_pulse': 'Pulso nga beep',
    'sound_warble': 'Warble',
    'sound_rotate': 'Usbon-usbon (random)',
    'sound_title': 'Pilia ang tunog',
    'sound_hint':
    'Pindota ang play aron madungog. Pindota ang linya aron pilion.',
    'sound_tip':
    'Makasanay ang mga langgam sa usa ka tunog. Ang "Usbon-usbon" nagsagol sa mga tunog aron mas dugay sila mahadlok.',
    'sound_error': 'Dili ma-play kini nga tunog.',

    // Support
    'support_title': 'Suporta',
    'support_contact': 'Kontaka mi',
    'support_copy': 'Kopyaha ang email',
    'support_copied': 'Nakopya ang email',
    'support_faq': 'Dali nga tabang',
    'faq_sound_q': 'Wala nako madungog ang tunog',
    'faq_sound_a':
    'Taasa ang media volume sa telepono (dili lang ang ringer) ug tan-awa kung naka-on ang switch sa tunog.',
    'faq_notif_q': 'Wala ko makadawat og alerto sa langgam',
    'faq_notif_a':
    'Kinahanglan ug internet ang duha ka telepono. Itugot ang mga notification, ayaw sirhi ang app, ug ibutang ang battery sa No restrictions.',
    'faq_weather_q': 'Sayop ang panahon',
    'faq_weather_a':
    'I-on ang location (GPS) ug i-pull down ang Panahon aron i-refresh. Makalimtan sa forecast ang gamay nga ulan, busa tan-awa usab ang langit.',
    'faq_pair_q': 'Dili molihok ang pagpares',
    'faq_pair_a':
    'Kinahanglan online ang duha ka telepono. Molungtad ang code og 10 ka minuto, busa paghimo og bag-o kung nahurot na.',

    // About
    'about_title': 'Mahitungod kanamo',
    'about_text':
    'Ang BinuWatch usa ka katabang sa pagbuwad sa bugas para sa mga mag-uuma sa Biliran. Gisultihan ka niini kung maayo ang panahon sa pagbuwad, gipahinumdoman ka sa pagbalik sa bugas, ug gibantayan ang mga langgam ug manok.',
    'about_version': 'Bersyon {v}',
    'about_made_by': 'Gihimo ni',
    'about_school': 'Proyekto sa estudyante sa',

    // Licenses
    'lic_title': 'Mga lisensya',
    'lic_open_source': 'Mga open-source nga lisensya',
    'lic_open_source_sub': 'Mga lisensya sa software nga gigamit niini nga app.',
    'lic_credits': 'Datos ug mga kredito',
  },
};

// Looks up a word in the current language. Falls back to English, then to the
// key itself, so a missing translation never crashes the app.
String tr(String key, [Map<String, String> args = const {}]) {
  final lang = AppSettings.instance.languageCode;
  var text = _strings[lang]?[key] ?? _strings['en']![key] ?? key;
  args.forEach((name, value) {
    text = text.replaceAll('{$name}', value);
  });
  return text;
}