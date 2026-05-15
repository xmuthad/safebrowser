#!/bin/bash

# SafeBrowser Release Script
# Usage: ./release.sh [version]
# Example: ./release.sh 1.0.0

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get version from argument or prompt
if [ -z "$1" ]; then
    echo -e "${YELLOW}Enter version number (e.g., 1.0.0):${NC}"
    read VERSION
else
    VERSION=$1
fi

# Validate version format
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Invalid version format. Use semver (e.g., 1.0.0)${NC}"
    exit 1
fi

TAG_NAME="v${VERSION}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}SafeBrowser Release Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Version: $VERSION"
echo "Tag: $TAG_NAME"
echo ""

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}Warning: You have uncommitted changes:${NC}"
    git status --short
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Navigate to ios directory
cd ios

# Check XcodeGen is installed
if ! command -v xcodegen &> /dev/null; then
    echo -e "${YELLOW}XcodeGen not found. Installing...${NC}"
    brew install xcodegen
fi

# Generate Xcode project
echo -e "${GREEN}Generating Xcode project...${NC}"
xcodegen generate

# Build project
echo -e "${GREEN}Building project...${NC}"

# Find available simulator
SIMULATOR=$(xcrun simctl list devices available | grep -E "iPhone" | head -1 | awk '{print $1, $2, $3}')
echo "Using simulator: $SIMULATOR"

# Build Debug
echo -e "${GREEN}Building Debug...${NC}"
xcodebuild -project SafeBrowser.xcodeproj \
    -scheme SafeBrowser \
    -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
    CODE_SIGNING_ALLOWED=NO \
    build 2>&1 | tail -10

# Build Release
echo -e "${GREEN}Building Release...${NC}"
xcodebuild -project SafeBrowser.xcodeproj \
    -scheme SafeBrowser \
    -configuration Release \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
    CODE_SIGNING_ALLOWED=NO \
    build 2>&1 | tail -10

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Go back to root
cd ..

# Create git tag
echo -e "${GREEN}Creating git tag...${NC}"
git tag -a "$TAG_NAME" -m "Release $VERSION built on $(date '+%Y-%m-%d')"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Ready to push!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Push the tag with:"
echo "  git push origin $TAG_NAME"
echo ""
echo "Or push all with:"
echo "  git push --tags"
echo ""
