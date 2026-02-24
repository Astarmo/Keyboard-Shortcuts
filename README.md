# Atajos-de-teclado
A program to type personalized symbols.

You can create your own keyboard shortcuts writing them down at shortcuts.txt file. This file must comply with the following structure (example in quotes):
"[Category name 1]
1: 'input1' → 'output1'
1: 'input2' → 'output2'
1: 'input3' → 'output3'

[Category name 1]
1: 'input4' → 'output4'"
...and so on.
This will make for example that every time user types "input1" it will write "output1". This is useful to type characters that are not in regular keyboards (for example, the program is loaded by default with shortcuts for math notation).

Both "KeyboardShortcuts.exe" and "shortcuts.txt" must be in the same folder.

Some clarifications:
- If some active "inputA" is a prefix o some other active "inputB", the user must write "inputA " (with space) for it to distinguish between inputA and inputB. Example: if "'1' -> 'one'" and "'10' -> 'ten'" both active, the user must type "1 " for it to become "one".
