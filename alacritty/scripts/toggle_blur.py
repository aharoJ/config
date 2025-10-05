import re
import os

# Path to your Alacritty configuration file
config_path = os.path.expanduser('~/.config/alacritty/alacritty.toml')

def toggle_blur(config_path):
    # Read the configuration file
    with open(config_path, 'r') as file:
        config = file.read()

    # Regular expression pattern to find the [window] section and the blur setting
    pattern = r'(\[window\]\s*blur\s*=\s*)(true|false)'

    # Function to toggle the blur setting
    def toggle_match(match):
        current_value = match.group(2)
        new_value = 'false' if current_value == 'true' else 'true'
        return match.group(1) + new_value

    # Replace the blur setting with its opposite value
    updated_config = re.sub(pattern, toggle_match, config, flags=re.IGNORECASE)

    # Write the updated configuration back to the file
    with open(config_path, 'w') as file:
        file.write(updated_config)

if __name__ == "__main__":
    toggle_blur(config_path)
