#!/usr/bin/env python3
"""
Split jemalloc.3.adoc.in into modular sections with include statements.
"""

import sys
import re
from pathlib import Path

def split_manpage(input_file, output_dir):
    """Split man page into sections."""

    # Read the input file
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Split into sections based on == headers
    sections = []
    current_section = {'name': 'header', 'content': []}

    for line in content.split('\n'):
        if line.startswith('== ') and current_section['content']:
            # Save previous section
            sections.append(current_section)
            # Start new section
            section_name = line[3:].strip().lower().replace(' ', '_')
            current_section = {'name': section_name, 'content': [line]}
        else:
            current_section['content'].append(line)

    # Save last section
    if current_section['content']:
        sections.append(current_section)

    # Create output directory
    sections_dir = output_dir / 'sections'
    sections_dir.mkdir(parents=True, exist_ok=True)

    # Write header to main file
    main_content = []
    section_files = []

    for section in sections:
        section_name = section['name']
        section_content = '\n'.join(section['content'])

        if section_name == 'header':
            # This is the header/preamble - goes in main file
            main_content.append(section_content)
        else:
            # Write section to separate file
            section_file = sections_dir / f'{section_name}.adoc'
            with open(section_file, 'w', encoding='utf-8') as f:
                f.write(section_content.lstrip())
                if not section_content.endswith('\n'):
                    f.write('\n')

            section_files.append((section_name, section_file.name))
            print(f"Created: sections/{section_file.name}")

    # Create main file with includes
    main_file = output_dir / 'jemalloc.3.adoc.in'
    with open(main_file, 'w', encoding='utf-8') as f:
        # Write header
        f.write(main_content[0])
        f.write('\n\n')

        # Write include statements
        for section_name, filename in section_files:
            f.write(f'include::sections/{filename}[]\n\n')

    print(f"\nCreated main file: {main_file.name}")
    print(f"Total sections: {len(section_files)}")

    return len(section_files)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <input.adoc.in>")
        sys.exit(1)

    input_file = Path(sys.argv[1])
    if not input_file.exists():
        print(f"Error: {input_file} not found")
        sys.exit(1)

    output_dir = input_file.parent

    num_sections = split_manpage(input_file, output_dir)
    print(f"\n✅ Successfully split man page into {num_sections} sections")