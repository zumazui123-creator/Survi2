from typing import List
from . import constants

class FunctionHandler:
    def __init__(self, data=None):
        self.data = data
        self.functions = {}
        self.assets_filepath = "assets/funktionen.txt"

    def parse_func_definitions(self, text: str):
        """
        Liest Funktionsdefinitionen aus Text und speichert sie in self.functions.
        Syntax:
            func name =
                ...
            end_func
        """
        lines = text.strip().splitlines()
        i = 0
        while i < len(lines):
            line = lines[i].strip()

            if line.startswith(constants.KEYWORD_FUNC + " "):
                parts = line.split()
                if len(parts) < 2:
                    print(f"⚠️ Fehler: Funktionsname fehlt in Zeile: {line}")
                    i += 1
                    continue

                name = parts[1].strip()

                i += 1
                block = []

                # Block einlesen bis end_token
                while i < len(lines) and lines[i].strip() != constants.KEYWORD_END_FUNC:
                    block.append(lines[i].strip())
                    i += 1

                # end_token überspringen
                if i < len(lines) and lines[i].strip() == constants.KEYWORD_END_FUNC:
                    i += 1

                self.functions[name] = block
            else:
                i += 1
        return self.functions


    def load_functions(self):
        try:
            with open(self.assets_filepath, "r", encoding="utf-8") as f:
                code = f.read()
                self.parse_func_definitions(code)

        except FileNotFoundError:
            print(f"⚠️ {self.assets_filepath} existiert nicht")
            return {}
        except Exception as e:
             print(f"⚠️ Error in load_functions: {e}")
             return {}
        return self.functions

    def save_functions(self):
        """
        Schreibt alle gespeicherten Funktionen in die Datei assets/funktionen.txt
        im ursprünglichen Format.
        """
        with open(self.assets_filepath, "w", encoding="utf-8") as f:
            for name, lines in self.functions.items():
                f.write(f"{constants.KEYWORD_FUNC} {name} =\n")
                for line in lines:
                    f.write(f"    {line}\n")
                f.write(f"{constants.KEYWORD_END_FUNC}\n\n")
        print(f"✅ Funktionen erfolgreich in {self.assets_filepath} gespeichert.")
