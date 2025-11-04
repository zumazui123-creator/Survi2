from typing import List

end_token: str = "ende"

class FunctionHandler:
    def __init__(self, data=None):
        self.data = data
        self.functions = {}

    def parse_func_definitions(self, text: str):
        """
        Liest Funktionsdefinitionen aus Text und speichert sie in self.functions.
        Syntax:
            func name =
                ...
            ende
        """
        lines = text.strip().splitlines()
        i = 0
        while i < len(lines):
            line = lines[i].strip()

            if line.startswith("func"):
                parts = line.split()
                if len(parts) < 2:
                    print(f"⚠️ Fehler: Funktionsname fehlt in Zeile: {line}")
                    i += 1
                    continue

                name = parts[1].strip()

                # Prüfen auf doppelte Funktionsnamen
                if name in self.functions:
                    print(f"⚠️ Doppelte Funktion '{name}' gefunden – wird übersprungen.")
                    # Überspringe den Block
                    while i < len(lines) and lines[i].strip() != end_token:
                        i += 1
                    if i < len(lines) and lines[i].strip() == end_token:
                        i += 1
                    continue

                i += 1
                block = []

                # Block einlesen bis end_token
                while i < len(lines) and lines[i].strip() != end_token:
                    block.append(lines[i].strip())
                    i += 1

                # end_token überspringen
                if i < len(lines) and lines[i].strip() == end_token:
                    i += 1

                self.functions[name] = block
            else:
                i += 1


    def load_functions(self):
        filepath = "assets/funktionen.txt"
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                code = f.read()
                self.parse_func_definitions(code)
        except FileNotFoundError:
            print(f"⚠️ {filepath} existiert nicht")
            return
        return self.functions

    def save_functions(self):
        """
        Schreibt alle gespeicherten Funktionen in die Datei assets/funktionen.txt
        im ursprünglichen Format.
        """
        filepath = "assets/funktionen.txt"
        with open(filepath, "w", encoding="utf-8") as f:
            for name, lines in self.functions.items():
                f.write(f"func {name} =\n")
                for line in lines:
                    f.write(f"    {line}\n")
                f.write(f"{end_token}\n\n")
        print(f"✅ Funktionen erfolgreich in {filepath} gespeichert.")
