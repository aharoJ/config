# markdow_script


## my python script
``` python
  

import re

import os

  

# Set the root of the workspace

workspace_root = '/Users/aharo/programming/z/aharo24'

  

# Set the base directory and the attachment directory

base_dir = '.'

attachment_dir = 'z'

  

# Recursively search for .md files in all subdirectories

for root, dirs, files in os.walk(workspace_root):

# Calculate the relative depth of the current directory

depth = root[len(workspace_root):].count(os.sep)

# Construct the relative path to the attachment directory

attachment_path = os.sep.join(['..'] * depth + [attachment_dir])

for file_name in files:

if file_name.endswith('.md'):

# Construct the full path to the file

file_path = os.path.join(root, file_name)

  

# Open the input file in read mode

with open(file_path, 'r') as file:

# Read the contents of the file into a string

contents = file.read()

  

# Use a regular expression to find all instances of the pattern "![](file_name)"

pattern = r'!\[\]\(([\w\d_.]+)\)'

matches = re.findall(pattern, contents)

print(f"Found {len(matches)} matches in {file_name}: {matches}")

  

# Iterate through the matches and replace them with the desired pattern "![](z/file_name)"

for match in matches:

# Calculate the new path by adding the relative path to the attachment directory

# to the front of the file name

new_path = os.path.join(attachment_path, match)

replacement = f'![]({new_path})'

contents = contents.replace(f'![]({match})', replacement)

  

# Open the input file in write mode

with open(file_path, 'w') as file:

# Write the modified contents back to the input file

file.write(contents)
```


---




## The Break Down

![beta_0.0.1](aharo_5.png)

![](aharo_6.png)

![](aharo_7.png)



--- 







## modification

- [ ] can we expand it with more functionality or no?


![](aharo_8.png)


---








## git tool 

![](aharo_9.png)
























## suggestion

```python
import argparse
import re
import os

# Set up command-line arguments
parser = argparse.ArgumentParser()
parser.add_argument('--root', required=True, help='root directory to search for files')
parser.add_argument('--base', required=True, help='base directory to use as reference')
parser.add_argument('--attachment', required=True, help='attachment directory to store attachments')
parser.add_argument('--preview', action='store_true', help='print modified contents to console instead of modifying files')
args = parser.parse_args()

# Set the root of the workspace
workspace_root = args.root

# Set the base directory and the attachment directory
base_dir = args.base
attachment_dir = args.attachment

# Recursively search for files in all subdirectories
for root, dirs, files in os.walk(workspace_root):
    # Calculate the relative depth of the current directory
    depth = root[len(workspace_root):].count(os.sep)
    # Construct the relative path to the attachment directory
    attachment_path = os.sep.join(['..'] * depth + [attachment_dir])
    for file_name in files:
        # Check if the file has a supported extension
        extension = os.path.splitext(file_name)[1]
        if extension in ('.md', '.html', '.xml'):
            # Construct the full path to the file
            file_path = os.path.join(root, file_name)

            # Open the input file in read mode
            with open(file_path, 'r') as file:
                # Read the contents of the file into a string
                contents = file.read()

            # Use a regular expression to find all instances of the pattern "![](file_name)"
            pattern = r'!\[\]\(([\w\d_.-]+)\)'
            matches = re.findall(pattern, contents)
            print(f"Found {len(matches)} matches in {file_name}: {matches}")

            # Iterate through the matches and replace them with the desired pattern "![](z/file_name)"
            for match in matches:
                # Check if the attachment file exists
                attachment_file_path = os.path.join(workspace_root, attachment_dir, match)
                if not os.path.exists(attachment_file_path):
                    print(f"Warning: attachment file not found: {attachment_file_path}")
                    continue
                # Calculate the new path by adding the relative path to the attachment directory
                # to the front of the file name
                new_path = os.path.join(attachment_path, match)
                replacement = f'![]

```


![](aharo_10.png)



## Name