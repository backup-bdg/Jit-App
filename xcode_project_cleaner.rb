#!/usr/bin/env ruby

# Simple script to clean up Xcode project files with duplicate references
# Specifically targets issues with storyboard and resource files

require 'pathname'

# Read the project file
project_path = "JITEnabler.xcodeproj/project.pbxproj"
contents = File.read(project_path)

# Make a backup
backup_path = "JITEnabler.xcodeproj/project.pbxproj.bak-fixed"
File.write(backup_path, contents)

puts "Backed up project file to #{backup_path}"

# Parse the file structure
puts "Analyzing project structure..."

# Get all file references
ref_pattern = /\s+([0-9A-F]{24})\s+\/\*\s+(.*)\s+\*\/\s+=\s+\{isa\s+=\s+PBXFileReference;/
file_refs = contents.scan(ref_pattern)
puts "Found #{file_refs.size} file references"

# Get all variant groups (storyboards)
variant_pattern = /\s+([0-9A-F]{24})\s+\/\*\s+(.*)\s+\*\/\s+=\s+\{isa\s+=\s+PBXVariantGroup;/
variant_groups = contents.scan(variant_pattern)
puts "Found #{variant_groups.size} variant groups"

# Check for duplicate file references in groups
group_pattern = /\s+([0-9A-F]{24})\s+\/\*\s+(.*)\s+\*\/\s+=\s+\{isa\s+=\s+PBXGroup;[\s\S]*?children\s+=\s+\(([\s\S]*?)\);/m
groups = contents.scan(group_pattern)

# Find all references to storyboards and fix them
puts "Cleaning up storyboard references..."

# Specifically check for Main.storyboard and LaunchScreen.storyboard issues
main_storyboard_id = variant_groups.find { |id, name| name == "Main.storyboard" }&.first
launch_storyboard_id = variant_groups.find { |id, name| name == "LaunchScreen.storyboard" }&.first

if main_storyboard_id && launch_storyboard_id
  puts "Found storyboard variant groups: Main=#{main_storyboard_id}, Launch=#{launch_storyboard_id}"
  
  # Ensure resources group only references the PBXVariantGroup, not file references
  resources_pattern = /\s+1A2B3C4D5E6F7890ABCDEF39\s+\/\*\s+Resources\s+\*\/\s+=\s+\{[\s\S]*?children\s+=\s+\(([\s\S]*?)\);/m
  resources_section = contents.match(resources_pattern)
  
  if resources_section
    fixed_resources = resources_section[0].gsub(/([0-9A-F]{24})\s+\/\*\s+(Main|LaunchScreen)\.storyboard\s+\*\//) do |match|
      id = $1
      name = $2
      if name == "Main"
        "#{main_storyboard_id} /* #{name}.storyboard */"
      elsif name == "LaunchScreen"
        "#{launch_storyboard_id} /* #{name}.storyboard */"
      else
        match
      end
    end
    
    contents.gsub!(resources_section[0], fixed_resources)
    puts "Fixed resources section"
  end
end

# Write the fixed project file
File.write(project_path, contents)
puts "Project file cleaned successfully"
