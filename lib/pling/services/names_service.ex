defmodule Pling.Services.NamesService do
  @adjectives [
    "Stor",
    "Liten",
    "Vakker",
    "Stygg",
    "Rask",
    "Langsom",
    "Smart",
    "Dum",
    "Lykkelig",
    "Trist",
    "Modig",
    "Feig",
    "Vennlig",
    "Frodig",
    "Sterk",
    "Svak",
    "Aktiv",
    "Lat",
    "Høy",
    "Lav",
    "Rik",
    "Fattig",
    "Ung",
    "Gammel",
    "Kreativ",
    "Uoriginal",
    "Spennende",
    "Kjedelig",
    "Søt",
    "Sur",
    "Kald",
    "Varm",
    "Morsom",
    "Alvorlig",
    "Flittig",
    "Sløv",
    "Dyktig",
    "Udyktig",
    "Snill",
    "Slem",
    "Lys",
    "Mørk",
    "Tynn",
    "Tykk",
    "Enkel",
    "Komplisert",
    "Rund",
    "Firkantet",
    "Myk",
    "Hard",
    "Klar",
    "Uklar",
    "Tom",
    "Full",
    "Skarp",
    "Utydelig",
    "Glatt",
    "Ru",
    "Ren",
    "Skitten",
    "Tung",
    "Lett",
    "Våt",
    "Tørr",
    "Rask",
    "Treg",
    "Frisk",
    "Syk",
    "Pen",
    "Stygg",
    "Stille",
    "Høylytt",
    "Ensom",
    "Populær",
    "Ny",
    "Gammel",
    "Tidløs",
    "Modern",
    "Tradisjonell",
    "Lokal",
    "Global",
    "Ekte",
    "Falsk",
    "Sulten",
    "Mett",
    "Ren",
    "Uren",
    "Glatt",
    "Humpete",
    "Våken",
    "Trøtt",
    "Åpen",
    "Lukket",
    "Tett",
    "Løs",
    "Kort",
    "Lang",
    "Skarp",
    "Flat",
    "Fersk",
    "Støl",
    "Frisk",
    "Muggen",
    "Lykkelig",
    "Elendig",
    "Optimal",
    "Dårlig",
    "Første",
    "Siste",
    "Øverste",
    "Nederste",
    "Innenfor",
    "Utenfor",
    "Langt",
    "Kort",
    "Fjern",
    "Nær",
    "Lys",
    "Tung",
    "Tom",
    "Hel",
    "Delvis",
    "Fullstendig",
    "Ufullstendig",
    "Fleksibel",
    "Stiv",
    "Stor",
    "Liten"
  ]

  @nouns [
    "Hund",
    "Katt",
    "Bil",
    "Hus",
    "Tre",
    "Elv",
    "Fjell",
    "Sjø",
    "Bok",
    "Sko",
    "Data",
    "Hage",
    "Fugl",
    "Vind",
    "Stol",
    "Bord",
    "Lampe",
    "Dør",
    "Vindu",
    "Himmel",
    "Sol",
    "Måne",
    "Stjerne",
    "Hav",
    "Strand",
    "By",
    "Landsby",
    "Skog",
    "Ørken",
    "Snø",
    "Regn",
    "Sommer",
    "Vinter",
    "Høst",
    "Vår",
    "Klokke",
    "Telefon",
    "Datamaskin",
    "TV",
    "Radio",
    "Kamera",
    "Tog",
    "Fly",
    "Båt",
    "Sykkel",
    "Mat",
    "Drikke",
    "Vann",
    "Melk",
    "Brød",
    "Ost",
    "Frukt",
    "Grønnsak",
    "Kjøtt",
    "Sukker",
    "Salt",
    "Pepper",
    "Krydder",
    "Blomst",
    "Gress",
    "Rot",
    "Blad",
    "Gren",
    "Fugl",
    "Fisk",
    "Flue",
    "Insekt",
    "Menneske",
    "Barn",
    "Voksen",
    "Lærer",
    "Student",
    "Leger",
    "Sykepleier",
    "Advokat",
    "Politi",
    "Brannmann",
    "Kokk",
    "Mekaniker",
    "Kunstner",
    "Musiker",
    "Sanger",
    "Skuespiller",
    "Idrettsutøver",
    "Spill",
    "Lek",
    "Sport",
    "Musikk",
    "Kunst",
    "Film",
    "Teater",
    "Bok",
    "Magasin",
    "Avis",
    "Penn",
    "Blyant",
    "Tusj",
    "Farge",
    "Lyd",
    "Bilde"
  ]

  # N = 100^2 = 10k
  def generate do
    "#{random_adjective()}-#{random_noun()}"
  end

  def random_adjective do
    Enum.random(@adjectives)
  end

  def random_noun do
    Enum.random(@nouns)
  end
end
