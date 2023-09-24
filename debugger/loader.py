#STARTFILE loader.py

import os

# loads files onto the pico over serial
def load_files(num_files):
    for i in range(num_files):
        file_name = ""
        file_lines = []
    
        # monitor input for #STARTFILE
        while True:
            ln = input()
            
            if ln.startswith("#STARTFILE"):
                # get file name
                file_name = ln[11:]
                
                if len(file_name) == 0:
                    print("Error: Missing file name")
                    return
                
                break
        
        # read file data until #ENDFILE
        while True:
            ln = input()
            
            if ln.startswith("#ENDFILE"):
                break
            
            file_lines.append(ln)
        
        # write file data
        with open(file_name, mode="w") as f:
            for ln in file_lines:
                f.write(ln)
                f.write("\n")

def echo_file(fname):
    with open(fname, mode="r") as f:
        for ln in f:
            print(ln)

#ENDFILE
