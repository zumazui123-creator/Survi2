
from typing import List
from .function import FunctionHandler
end_token : str = "ende"

class Parser():
    def __init__(self,  funcHandler :FunctionHandler , data = None ):
        # self.data = data
        self.functions = {}
        self.funcHandler = funcHandler

    def translate_action(self,clean_line: str) -> str:
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


    def translate_to_actions(self,code : str) -> List[str]:
        if not code:
            return []

        # print(f"Parsing code:\n{code}")
        self.functions = self.funcHandler.load_functions()
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

            action = self.translate_action(clean_line)
            if action != "":
                actions.append(action)

        # compressed_actions = self.compress_sequence(actions)
        return actions
