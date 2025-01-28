import hashlib, time, os, random, string
from simple_term_menu import TerminalMenu

SCRIPT_HASH = "a90ca3281b6dca2155a26444dfb8e83ab81f7c9c0dbffe8c4b2b0f3a6c854648"

def dramatic_print(strings):
    for string in strings:
        print(string, end="", flush=True)
        time.sleep(.6)

# Validates that main.py has not been altered
def validate():
    with open("main.py", 'rb') as file:
        script_content = file.read()
        script_hash = hashlib.sha256(script_content).hexdigest()
        if script_hash == SCRIPT_HASH:
            return True
        else:
            print("ERROR: Your main.py file has been altered.")
            print("To proceed, please reset main.py to its original state.")
            print("(Keep in mind, even an extra space counts as 'altered'!)")
            return False

def reset_file(filename):
    """Reset the given target file.

    Returns the hash of the target file after reset"""

    if filename == "intro.txt":
        content = "Hello, my name is CodePathBot!"
    elif filename == "permanent.txt":
        content = "This file shouldn't be writeable!"
    elif filename == "random.txt":
        if os.path.isfile("copy.txt"):
            os.remove("copy.txt")
        content = ''.join(random.choices(string.ascii_letters + string.digits, k=100))
    else: 
        raise FileNotFoundError

    os.chmod(filename, 0o644)
    with open(filename, 'w') as intro_file:
        intro_file.write(content)
    return hashlib.sha256(content.encode("utf-8")).hexdigest()

def run_script(scriptname, filename):
    """Reset, then run a script with a given target file
    
    Returns the hash of the target file after reset, as
    returned by the reset_file() function"""
    # Reset file
    dramatic_print([f"Resetting {filename}.", ".", ". "])
    clean_hash = reset_file(filename)
    print("Done.")

    # Run the challenge script
    dramatic_print([f"Running your {scriptname} script.", ".", ". "])
    os.system(f'./{scriptname}')
    print("Done.")

    return clean_hash

def check_file(filename, correct_hash=None, different_hash=None, correct_perms=None):
    """Validate a file against various SHA256 hashes and perms (744 octal format)

    Returns a summed value using octal format: 
        0=all tests passed
        1=correct_hash failed
        2=different_hash failed
        4=correct_perms failed
    """
    # Start
    result = 0

    # Check if the txt file has been modified
    with open(filename, 'rb') as file_reader:
        file_content = file_reader.read()
        file_hash = hashlib.sha256(file_content).hexdigest()
        file_perms = oct(os.stat('intro.txt').st_mode)[-3:]

    if correct_hash and file_hash != correct_hash:
        result += 1
    if different_hash and file_hash == different_hash:
        result += 2
    if correct_perms and file_perms != correct_perms:
        print(file_perms, type(file_perms))
        print(correct_perms, type(correct_perms))
        result += 4
    return result

def is_writable(filename):
    """Check if the given file has any write permissions"""
    new_perms = oct(os.stat(filename).st_mode)[-3:]
    return any([i in "2367" for i in new_perms])

def check_challenge_1():
    print("### Challenge 1 ###\n")
    # Reset the txt file to remove any manual editing
    original_hash = run_script('challenge_1.sh', 'intro.txt')

    # Check results
    result = check_file('intro.txt', different_hash=original_hash, correct_perms="644")
    dramatic_print([f"Checking for changes to intro.txt.", ".", ". "])
    if result == 0:
        print(f"✅ Correct!")
        with open('challenge_1.sh', 'r') as chal:
            print(f"Your command was:\n\t> {chal.read()}\n")
        return True
    elif result == 2:
        print(f"🚧 Your command ran, but the contents of intro.txt don't seem to have changed.  Please check your command and try again.")
        return False
    elif result == 4:
        print(f"🚧 Your command ran, but the file permissions for input changed when they shouldn't have.  Please check your command and try again.")
        print(f"\tOriginal permissions:\tpermanent.txt (644)")
        print(f"\tYour permissions:\tpermanent.txt ({oct(os.stat('permanent.txt').st_mode)[-3:]})\n")
        return False
    else:
        print(f"⛔ Sorry, that's not the right answer. Please make sure your challenge_1 command modifies the file's content, but not its' permissions. Error code: {result}\n")
        return False


def check_challenge_2():
    print("### Challenge 2 ###\n")
    # Reset the txt file to remove any manual editing
    original_hash = run_script('challenge_2.sh', 'permanent.txt')

    # Check results
    result = check_file('permanent.txt', correct_hash=original_hash, correct_perms="644")
    has_write = is_writable('permanent.txt')

    dramatic_print([f"Checking for changes to permanent.txt.", ".", ". "])
    if result == 4 and not has_write:
        print(f"✅ Correct!")
        with open('challenge_2.sh', 'r') as chal:
            print(f"Your command was:\n\t> {chal.read()}\n")
        return True
    elif result == 4:
        print(f"🚧 You're really close!  Your command DOES modify the file permissions, but the file is still writeable. Please check your command and try again.")
        print(f"\tOriginal permissions:\tpermanent.txt (644)")
        print(f"\tYour permissions:\tpermanent.txt ({oct(os.stat('permanent.txt').st_mode)[-3:]})\n")
        return False
    elif result == 1:
        print(f"🚧 Your command ran, but it seems like you accidentally modified the contents of permanent.txt.  Please check your command and try again.\n")
        return False
    else:
        print(f"⛔ Sorry, that's not the right answer. Please make sure your challenge_2 command modifies the file's permissions, but not its' content. Error code: {result}\n")
        return False

def check_challenge_3():
    print("### Challenge 3 ###\n")
    # Reset the txt file to remove any manual editing
    original_hash = run_script('challenge_3.sh', 'random.txt')

    # Check results
    result1 = check_file('random.txt', correct_hash=original_hash, correct_perms="644")

    # Check if random.txt has been modified
    dramatic_print([f"Checking for changes to random.txt.", ".", ". "])
    if result1 == 0:
        print(f"Done.")
    else:
        print(f"⛔ Sorry, that's not the right answer. Please make sure your challenge_3 command does not modify the original random.txt file. Error code: {result1}")
        return False

    # Check if copy.txt has been created
    dramatic_print([f"Checking for new file copy.txt.", ".", ". "])
    try:
        result2 = check_file('copy.txt', correct_hash=original_hash, correct_perms="644")
    except FileNotFoundError:
        print(f"⛔ Sorry, that's not the right answer.  Please make sure your command creates a new file called copy.txt\n")
        return False
    if result2 == 0:
        print(f"✅ Correct!")
        with open('challenge_3.sh', 'r') as chal:
            print(f"Your command was:\n\t> {chal.read()}\n")
        return True
    else:
        print(f"🚧 You're making progress!  Your command creates copy.txt, but its contents do not match random.txt. Please check your command and try again.  Error code: {result2}\n")
        return False

dramatic_print([f"Validating scripts.", ".", ". "])
if validate():
    try:
        os.chmod("challenge_1.sh", 0o744)
        os.chmod("challenge_2.sh", 0o744)
        os.chmod("challenge_3.sh", 0o744)
    except FileNotFoundError:
        print("ERROR: One or more of your challenge scripts are missing.")
        print("Please make sure you have not deleted any of the challenge scripts.")
        print("\tTemplate: https://github.com/codepath/cyb102-prework-tmpl")
        exit()
    print("Validated.")
else:
    exit()

print(f"Welcome to the CYB102 Prework!\n")
print(f"To use this workspace, please follow the instructions at:")
print("\thttps://courses.codepath.org/snippets/cyb102/prework\n")

while True:        
    options = [
        "[0] Check All Challenges", 
        "[1] Check Challenge 1 only",
        "[2] Check Challenge 2 only",
        "[3] Check Challenge 3 only", 
        "[4] Reset txt files",
        "[5] Exit"]
    main_menu = TerminalMenu(options, title="Please select an option:")
    response = main_menu.show()

    if response == 5:
        print("Goodbye.")
        exit()
    elif response == 4:
        dramatic_print([f"Resetting txt files.", ".", ". "])
        reset_file("intro.txt")
        reset_file("permanent.txt")
        reset_file("random.txt")
        print("Done.")

    print()
    c1, c2, c3 = False, False, False
    if response == 0 or response == 1:
        c1 = check_challenge_1()
    if response == 0 or response == 2:
        c2 = check_challenge_2()
    if response == 0 or response == 3:
        c3 = check_challenge_3()

    if c1 and c2 and c3:
        print()
        print("🎉 CYB102 Prework complete! 🎉")
        print()
        print("To receive credit, submit your challenge")
        print("answers by following the instructions at:")
        print("\thttps://courses.codepath.org/snippets/cyb102/prework")
        print()
        exit()