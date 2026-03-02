import re

print("Parsing analyze.txt...")
count = 0

with open('analyze.txt', 'r') as f:
    lines = f.readlines()

for line in lines:
    if 'invalid_constant' in line:
        parts = [p.strip() for p in line.split('-')]
        # Find the part that looks like a file path
        filepath_str = None
        for p in parts:
            if '.dart:' in p:
                filepath_str = p
                break
        
        if filepath_str:
            filepath_line = filepath_str.split(':')
            filepath = filepath_line[0]
            linenum = int(filepath_line[1]) - 1 # 0-indexed
            
            try:
                with open(filepath, 'r') as f:
                    f_lines = f.readlines()
                    
                # Search upwards for 'const ' and remove it
                for offset in range(10):
                    idx = linenum - offset
                    if idx >= 0:
                        # Match 'const ' not inside a string if possible, but simple replace is fine
                        if 'const ' in f_lines[idx]:
                            f_lines[idx] = f_lines[idx].replace('const ', '')
                            count += 1
                            break
                            
                with open(filepath, 'w') as f:
                    f.writelines(f_lines)
            except Exception as e:
                print(f"Error processing {filepath}: {e}")

print(f"Removed const in {count} places.")
