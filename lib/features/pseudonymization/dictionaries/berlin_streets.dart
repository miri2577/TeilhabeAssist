/// Berliner Straßennamen (Auswahl der häufigsten / bekanntesten).
/// Wird für Adress-Erkennung verwendet.
/// Quelle: OpenData Berlin / OpenStreetMap, häufigste Straßen.
const kBerlinStreets = <String>{
  // Zentrale / bekannte Straßen
  'Alexanderplatz', 'Alexanderstraße', 'Alt-Moabit', 'Unter den Linden',
  'Friedrichstraße', 'Leipziger Straße', 'Potsdamer Straße',
  'Kurfürstendamm', 'Kurfürstenstraße', 'Kantstraße', 'Bismarckstraße',
  'Berliner Straße', 'Hauptstraße', 'Schönhauser Allee', 'Prenzlauer Allee',
  'Karl-Marx-Allee', 'Karl-Marx-Straße', 'Frankfurter Allee',
  'Greifswalder Straße', 'Landsberger Allee', 'Storkower Straße',
  'Danziger Straße', 'Eberswalder Straße', 'Kastanienallee',
  'Oranienstraße', 'Oranienburger Straße', 'Torstraße', 'Invalidenstraße',
  'Chausseestraße', 'Brunnenstraße', 'Müllerstraße', 'Badstraße',
  'Turmstraße', 'Beusselstraße', 'Tegeler Weg', 'Spandauer Damm',
  'Heerstraße', 'Kaiserdamm', 'Reichsstraße',

  // Neukölln / Kreuzberg
  'Hermannstraße', 'Hermannplatz', 'Sonnenallee', 'Richardstraße',
  'Flughafenstraße', 'Boddinstraße', 'Weserstraße', 'Pannierstraße',
  'Reuterstraße', 'Hobrechtstraße', 'Kottbusser Damm',
  'Kottbusser Straße', 'Görlitzer Straße', 'Wiener Straße',
  'Skalitzer Straße', 'Gitschiner Straße', 'Gneisenaustraße',
  'Mehringdamm', 'Bergmannstraße', 'Zossener Straße',
  'Urbanstraße', 'Hasenheide',

  // Tempelhof / Schöneberg
  'Tempelhofer Damm', 'Mariendorfer Damm', 'Bundesallee', 'Rheinstraße',
  'Schmiljanstraße', 'Grunewaldstraße', 'Motzstraße', 'Nollendorfstraße',
  'Winterfeldtstraße', 'Goltzstraße', 'Akazienstraße',
  'Martin-Luther-Straße', 'Kolonnenstraße',

  // Charlottenburg / Wilmersdorf
  'Wilmersdorfer Straße', 'Uhlandstraße', 'Fasanenstraße',
  'Joachimsthaler Straße', 'Lietzenburger Straße', 'Konstanzer Straße',
  'Brandenburgische Straße', 'Westfälische Straße', 'Mommsenstraße',
  'Savignyplatz', 'Bleibtreustraße',

  // Wedding / Reinickendorf
  'Osloer Straße', 'Seestraße', 'Residenzstraße', 'Scharnweberstraße',
  'Aroser Allee', 'Provinzstraße', 'Pankstraße', 'Reinickendorfer Straße',

  // Pankow / Weißensee
  'Breite Straße', 'Wollankstraße', 'Florastraße', 'Berliner Allee',

  // Lichtenberg / Marzahn / Hellersdorf
  'Rhinstraße',
  'Marzahner Promenade', 'Hellersdorfer Straße', 'Allee der Kosmonauten',
  'Märkische Allee',

  // Spandau
  'Klosterstraße', 'Brunsbütteler Damm', 'Falkenseer Chaussee',
  'Wilhelmstraße', 'Neuendorfer Straße',

  // Steglitz / Zehlendorf
  'Schloßstraße', 'Albrechtstraße', 'Birkbuschstraße',
  'Clayallee', 'Argentinische Allee', 'Potsdamer Chaussee',
  'Königstraße', 'Teltower Damm',

  // Treptow / Köpenick
  'Baumschulenstraße', 'Puschkinallee', 'Köpenicker Landstraße',
  'Grünauer Straße', 'Bahnhofstraße', 'Wendenschloßstraße',
};

/// Typische Straßensuffixe für Pattern-Matching
const kStreetSuffixes = <String>[
  'straße', 'str.', 'weg', 'platz', 'allee', 'damm', 'ring', 'ufer',
  'zeile', 'gasse', 'pfad', 'chaussee', 'promenade', 'steig', 'steg',
  'brücke', 'markt', 'hof', 'park', 'garten',
];
