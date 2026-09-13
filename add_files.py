import os
from pbxproj import XcodeProject

project_path = "byMakerCleaner.xcodeproj/project.pbxproj"
project = XcodeProject.load(project_path)

# Ensure the files exist
theme_path = "byMakerCleaner/UI/Theme.swift"
components_path = "byMakerCleaner/UI/TerminalComponents.swift"

for f_path in [theme_path, components_path]:
    if os.path.exists(f_path):
        # target name is byMakerCleaner
        results = project.add_file(f_path, force=False, target_name="byMakerCleaner")
        if results:
            print(f"Added {f_path} to target")
        else:
            print(f"File {f_path} might already be in target or failed to add")

project.save()
print("Saved pbxproj")
