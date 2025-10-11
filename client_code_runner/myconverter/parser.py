
from typing import List

end_token : str = "ende"

class Parser():
    def __init__(self, data = None):
        self.data = data
        self.functions = {}

    def movement(self,clean_line: str) -> str:
        if "sage" in clean_line.lower():
            return clean_line
        if "gehe zurück" in clean_line.lower():
            return "gehe zurück"
        if "nutze item" in clean_line.lower():
            return "use item " + clean_line.split(" ")[-1]

        match clean_line.lower():
            case "links":
                return "walkLeft"
            case "rechts":
                return "walkRight"
            case "hoch" | "oben":
                return "walkUp"
            case "runter" | "unten":
                return "walkDown"
            case "attacke":
                return "leftClickAction"
        return ""

    def parse_repeat_recursive(self, lines):
        result = []
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            if line.startswith("wiederhole"):
                # Zahl der Wiederholungen extrahieren
                parts = line.split()
                count = int(parts[1])
                i += 1
                # Block sammeln bis passendes end_token
                block = []
                depth = 1
                while i < len(lines) and depth > 0:
                    current = lines[i].strip()
                    if current.startswith("wiederhole"):
                        depth += 1
                    elif current == end_token:
                        depth -= 1
                        if depth == 0:
                            i += 1
                            break
                    if depth > 0:
                        block.append(lines[i])
                    i += 1
                # Rekursiv den Block verarbeiten und count-mal wiederholen
                expanded_block = self.parse_repeat_recursive(block)
                result.extend(expanded_block * count)
            else:
                result.append(line)
                i += 1
        return result

    def parse_repeat(self,text):
        lines = text.strip().splitlines()
        expanded_lines = self.parse_repeat_recursive(lines)
        return "\n".join(expanded_lines)


    def parse_func_definitions(self, text):
        """
        Liest Funktionsdefinitionen und speichert sie in self.functions.
        Syntax:
            func name =
                ...
            end
        """
        lines = text.strip().splitlines()
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            # print(f"Processing line for function definition: {line}")

            if line.startswith("func"):
                parts = line.split()
                if len(parts) < 2:
                    print(f"Fehler: Funktionsname fehlt in Zeile: {line}")
                    i += 1
                    continue

                name = parts[1].strip()
                i += 1
                block = []

                # Block einlesen bis end_token
                while i < len(lines) and lines[i].strip() != end_token:
                    block.append(lines[i].strip())
                    # print(f"Adding line to function {name}: {lines[i]}")
                    i += 1

                # end_token überspringen
                if i < len(lines) and lines[i].strip() == end_token:
                    i += 1

                self.functions[name] = block
                # print(f"Funktion {name} gespeichert: {block}")
            else:
                i += 1



    # def parse_func(self, text: str) -> str:
    #     """
    #     Ersetzt Funktionsaufrufe durch deren Definitionen.
    #     Funktionsdefinitionen selbst werden NICHT verarbeitet.
    #     """
    #     lines = text.strip().splitlines()
    #     result: list[str] = []

    #     for line in lines:
    #         clean_line = line.strip()

    #         if clean_line in self.functions:
    #             # Rekursiv expandieren, falls Funktionen verschachtelt sind
    #             expanded = self.parse_func("\n".join(self.functions[clean_line]))
    #             result.append(expanded)
    #         else:
    #             result.append(clean_line)

    #     return "\n".join(result)

    def parse_func(self, text: str) -> str:
        """
        Ersetzt Funktionsaufrufe durch deren Code-Blöcke.
        Verschachtelte Funktionsaufrufe werden NICHT aufgelöst.
        """
        lines = text.strip().splitlines()
        result: list[str] = []

        for line in lines:
            clean_line = line.strip()

            if clean_line in self.functions:
                # Block direkt einsetzen (ohne erneuten parse_func-Aufruf)
                expanded = "\n".join(self.functions[clean_line])
                result.append(expanded)
            else:
                result.append(clean_line)

        return "\n".join(result)

    def compress_sequence(self,seq) -> List[tuple]:
        if not seq:
            return []

        compressed = []
        current = seq[0]
        count = 1

        for item in seq[1:]:
            if item == current:
                count += 1
            else:
                compressed.append((current, count))
                current = item
                count = 1
        compressed.append((current, count))  # letzten Block hinzufügen
        return compressed

    def load_functions(self):
        filepath = "assets/funktionen.txt"
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                code = f.read()
                # print(f"Lade Funktionen aus {filepath}")
                self.parse_func_definitions(code)

        except FileNotFoundError:
            print(f"{filepath} existiert nicht")
            return

    def parse(self,code : str) -> List[str]:
        if not code:
            return []

        # print(f"Parsing code:\n{code}")
        self.load_functions()
        # print(f"Loaded functions: {self.functions}")

        code = self.parse_repeat(code)
        # print(f"Code after repeat parsing")
        code = self.parse_func(code)
        # print(f"Code after function parsing:\n{code}")

        actions : List[str] = []
        code_lines = code.strip().splitlines()

        for line in code_lines:
            clean_line = line.strip()
            if clean_line == "":
                continue
            # print(f"Processing line: {clean_line}")

            action = self.movement(clean_line)
            if action != "":
                actions.append(action)

        # compressed_actions = self.compress_sequence(actions)
        return actions
