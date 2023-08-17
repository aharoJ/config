import re
import os

# Set the root of the workspace to the current working directory
workspace_root = os.getcwd()

# Set the attachment directory
attachment_dir = 'z'

# Recursively search for .md files in all subdirectories
for root, dirs, files in os.walk(workspace_root):
    for file_name in files:
        if file_name.endswith('.md'):
            # Construct the full path to the file
            file_path = os.path.join(root, file_name)

            # Open the input file in read mode
            with open(file_path, 'r') as file:
                # Read the contents of the file into a string
                contents = file.read()

            # Use a regular expression to find all instances of the pattern "![](../..etc/z/file_name)"
            pattern = rf'!\[\]\((\.\./)+{attachment_dir}/([\w\d_\.\-%% ]+)\)'     # Adjusted to match various relative links
            matches = re.findall(pattern, contents)

            # Iterate through the matches and replace them with the original pattern "![](file_name)"
            for _, match in matches:
                contents = contents.replace(f'![](../{attachment_dir}/{match})', f'![]({match})')

            # Open the input file in write mode
            with open(file_path, 'w') as file:
                # Write the modified contents back to the input file
                file.write(contents)
