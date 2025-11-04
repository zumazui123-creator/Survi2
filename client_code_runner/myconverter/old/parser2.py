

from typing import List

functions = {}

class Parser():
    def __init__(self, data = None):
        self.data = data
        
    def movement(self,clean_line: str) -> str:
        if "sage" in clean_line.lower():
            return clean_line
        

            
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
                # Block sammeln bis passendes "end"
                block = []
                depth = 1
                while i < len(lines) and depth > 0:
                    current = lines[i].strip()
                    if current.startswith("wiederhole"):
                        depth += 1
                    elif current == "end":
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
         # --- Mehrzeilige Funktionsdefinition ---
        lines = text.strip().splitlines()
        result = []
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            
            if line.startswith("func"):
                name = line.split()[1].strip()
                i += 1
                block = []
                while i < len(lines) and lines[i].strip() != "end":
                    block.append(lines[i])
                    i += 1
                    print(f"Adding line to function {name}: {lines[i-1]}")
                functions[name] = block

    def parse_func(self,text):
        """
        Parse den Code-String und expandiere mehrzeilige Funktionen und Funktionsaufrufe.
        Gibt einen String zurück.
        """
        lines = text.strip().splitlines()
        result = []
        i = 0
        while i < len(lines):
            line = lines[i].strip()

            # --- Funktionsaufruf ---
            if line in functions:
                # rekursiv die Funktion expandieren
                expanded = self.parse_func("\n".join(functions[line]))
                result.append(expanded)
            
            else:
                result.append(line)
            
            i += 1
        
        # Ergebnis als String zurückgeben
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
        filepath = "funktionen.txt"
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                code = f.read()
                self.parse_func_definitions(code)

        except FileNotFoundError:
            print(f"{filepath} existiert nicht")
            return

    def parse(self,code : str) -> List[tuple]:
        if not code:
            return []
        
        # print(f"Parsing code:\n{code}")
        self.load_functions()
        code = self.parse_repeat(code)
        code = self.parse_func(code)

        actions : List[str] = []
        code_lines = code.strip().splitlines()

        for line in code_lines:
            clean_line = line.strip()
            if clean_line == "":
                continue
            print(f"Processing line: {clean_line}")
 
            action = self.movement(clean_line)
            if action != "":
                actions.append(action)

        compressed_actions = self.compress_sequence(actions)
        return compressed_actions
    
