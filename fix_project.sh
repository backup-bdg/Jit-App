#!/bin/bash

# This script fixes Xcode project.pbxproj files with "Malformed Project - Files in multiple groups" warnings
# Specifically for storyboard files that might be incorrectly referenced

# Make a backup
cp JITEnabler.xcodeproj/project.pbxproj JITEnabler.xcodeproj/project.pbxproj.backup

# Look at the Resources group and extract the relevant parts
RESOURCES_GROUP=$(grep -n -A 10 "1A2B3C4D5E6F7890ABCDEF39.*Resources" JITEnabler.xcodeproj/project.pbxproj)

echo "Fixing project structure issues..."

# Fix the issue by modifying the project.pbxproj file

# Create a new version of the project file
cat JITEnabler.xcodeproj/project.pbxproj | 
# Add a proper Resources group definition if the existing one is problematic
awk '
/1A2B3C4D5E6F7890ABCDEF39 \/\* Resources \*\/ = {/ {
    print $0;
    getline;
    print $0;
    getline;
    print $0;
    # Use unique identifiers for the storyboard references in the group children
    print "\t\t\t\t1A2B3C4D5E6F7890ABCDEF90 /* Main.storyboard */,";
    print "\t\t\t\t1A2B3C4D5E6F7890ABCDEF24 /* Assets.xcassets */,";
    print "\t\t\t\t1A2B3C4D5E6F7890ABCDEF91 /* LaunchScreen.storyboard */,";
    # Skip the existing children
    while (!/\);/) { getline; }
    print "\t\t\t);";
    next;
}

# Make sure the proper linking exists for Main.storyboard
/\/\* Begin PBXVariantGroup section \*\// {
    print $0;
    # Replace the storyboard variant group definitions with proper ones
    print "\t\t1A2B3C4D5E6F7890ABCDEF90 /* Main.storyboard */ = {";
    print "\t\t\tisa = PBXVariantGroup;";
    print "\t\t\tchildren = (";
    print "\t\t\t\t1A2B3C4D5E6F7890ABCDEF22 /* Base */,";
    print "\t\t\t);";
    print "\t\t\tname = Main.storyboard;";
    print "\t\t\tsourceTree = \"<group>\";";
    print "\t\t};";
    print "\t\t1A2B3C4D5E6F7890ABCDEF91 /* LaunchScreen.storyboard */ = {";
    print "\t\t\tisa = PBXVariantGroup;";
    print "\t\t\tchildren = (";
    print "\t\t\t\t1A2B3C4D5E6F7890ABCDEF26 /* Base */,";
    print "\t\t\t);";
    print "\t\t\tname = LaunchScreen.storyboard;";
    print "\t\t\tsourceTree = \"<group>\";";
    print "\t\t};";
    
    # Skip the old variant group definitions
    while (!/\/\* End PBXVariantGroup section \*\//) { getline; }
    print $0;
    next;
}

# Update the fileRef in PBXBuildFile to point to our new variant groups
/1A2B3C4D5E6F7890ABCDEF21 \/\* Main.storyboard in Resources \*\/ = {isa = PBXBuildFile; fileRef =/ {
    print "\t\t1A2B3C4D5E6F7890ABCDEF21 /* Main.storyboard in Resources */ = {isa = PBXBuildFile; fileRef = 1A2B3C4D5E6F7890ABCDEF90 /* Main.storyboard */; };";
    next;
}

/1A2B3C4D5E6F7890ABCDEF25 \/\* LaunchScreen.storyboard in Resources \*\/ = {isa = PBXBuildFile; fileRef =/ {
    print "\t\t1A2B3C4D5E6F7890ABCDEF25 /* LaunchScreen.storyboard in Resources */ = {isa = PBXBuildFile; fileRef = 1A2B3C4D5E6F7890ABCDEF91 /* LaunchScreen.storyboard */; };";
    next;
}

# Print all other lines unchanged
{ print; }
' > JITEnabler.xcodeproj/project.pbxproj.fixed

# Backup the original and replace with the fixed version
mv JITEnabler.xcodeproj/project.pbxproj.fixed JITEnabler.xcodeproj/project.pbxproj

echo "Project structure fixed!"
