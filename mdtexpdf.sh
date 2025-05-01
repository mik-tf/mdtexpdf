#!/bin/bash

# ANSI color codes
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}✗ $1 is not installed${NC}"
        return 1
    else
        echo -e "${GREEN}✓ $1 is installed${NC}"
        return 0
    fi
}

# Function to check if a LaTeX package is available
check_latex_package() {
    if kpsewhich "$1.sty" &> /dev/null; then
        echo -e "${GREEN}✓ LaTeX package $1 is available${NC}"
        return 0
    else
        echo -e "${RED}✗ LaTeX package $1 is not available${NC}"
        return 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}=== LaTeX-Markdown PDF Generator Prerequisites Check ===${NC}"
    echo

    # Check for Pandoc
    echo -e "${YELLOW}Checking for Pandoc...${NC}"
    PANDOC_INSTALLED=true
    if ! check_command pandoc; then
        PANDOC_INSTALLED=false
    fi
    echo

    # Check for LaTeX engines
    echo -e "${YELLOW}Checking for LaTeX engines...${NC}"
    LATEX_INSTALLED=false
    if check_command pdflatex; then
        LATEX_INSTALLED=true
        PDF_ENGINE="pdflatex"
    elif check_command xelatex; then
        LATEX_INSTALLED=true
        PDF_ENGINE="xelatex"
    elif check_command lualatex; then
        LATEX_INSTALLED=true
        PDF_ENGINE="lualatex"
    fi

    if [ "$LATEX_INSTALLED" = true ]; then
        echo -e "Using PDF engine: ${GREEN}$PDF_ENGINE${NC}"
    else
        echo -e "${RED}No LaTeX engine found${NC}"
    fi
    echo

    # Check for required LaTeX packages
    if [ "$LATEX_INSTALLED" = true ]; then
        echo -e "${YELLOW}Checking for required LaTeX packages...${NC}"
        PACKAGES_MISSING=false
        
        # List of required packages
        REQUIRED_PACKAGES=(
            "geometry" "fancyhdr" "graphicx" "amsmath" "amssymb" "hyperref" "xcolor" 
            "booktabs" "longtable" "amsthm" "fancyvrb" "framed" "listings" "array" 
            "enumitem" "etoolbox" "float" "lmodern" "textcomp" "upquote" "microtype" "mhchem"
        )
        
        for package in "${REQUIRED_PACKAGES[@]}"; do
            if ! check_latex_package "$package"; then
                PACKAGES_MISSING=true
            fi
        done
        echo
    fi

    # Print installation instructions if prerequisites are missing
    if [ "$PANDOC_INSTALLED" = false ] || [ "$LATEX_INSTALLED" = false ] || [ "$PACKAGES_MISSING" = true ]; then
        echo -e "${YELLOW}=== Installation Instructions ===${NC}"
        
        if [ "$PANDOC_INSTALLED" = false ]; then
            echo -e "${YELLOW}To install Pandoc:${NC}"
            echo "  - Ubuntu/Debian: sudo apt-get install pandoc"
            echo "  - macOS with Homebrew: brew install pandoc"
            echo "  - Windows with Chocolatey: choco install pandoc"
            echo
        fi
        
        if [ "$LATEX_INSTALLED" = false ] || [ "$PACKAGES_MISSING" = true ]; then
            echo -e "${YELLOW}To install LaTeX with required packages:${NC}"
            echo "  - Ubuntu/Debian: sudo apt-get install texlive-latex-base texlive-latex-recommended texlive-latex-extra texlive-science"
            echo "  - macOS with Homebrew: brew install --cask mactex"
            echo "  - Windows: Install MiKTeX from https://miktex.org/download"
            echo
        fi
        
        echo -e "${RED}Please install the missing prerequisites and run this script again.${NC}"
        return 1
    fi

    echo -e "${GREEN}All prerequisites are installed!${NC}"
    echo
    return 0
}

# Function to convert markdown to PDF
convert() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: No input file specified.${NC}"
        echo -e "Usage: mdtexpdf convert <input.md> [output.pdf]"
        return 1
    fi

    # Check prerequisites first
    if ! check_prerequisites; then
        return 1
    fi

    # Get input and output file names
    INPUT_FILE="$1"
    if [ ! -f "$INPUT_FILE" ]; then
        echo -e "${RED}Error: Input file '$INPUT_FILE' not found.${NC}"
        return 1
    fi

    # If output file is specified, use it; otherwise derive from input file
    if [ -n "$2" ]; then
        OUTPUT_FILE="$2"
    else
        OUTPUT_FILE="${INPUT_FILE%.md}.pdf"
    fi

    # Convert markdown to PDF using pandoc with our template
    echo -e "${YELLOW}Converting $INPUT_FILE to PDF...${NC}"
    echo -e "Using PDF engine: ${GREEN}$PDF_ENGINE${NC}"

    # No additional options needed for pdflatex
    PANDOC_OPTS=""

    # Check for template.tex in various locations
    TEMPLATE_PATH="template.tex"
    if [ ! -f "$TEMPLATE_PATH" ]; then
        # Check in templates directory
        if [ -f "templates/template.tex" ]; then
            TEMPLATE_PATH="templates/template.tex"
        else
            # Check if template exists in the installation directory
            SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
            if [ -f "$SCRIPT_DIR/templates/template.tex" ]; then
                TEMPLATE_PATH="$SCRIPT_DIR/templates/template.tex"
            elif [ -f "$SCRIPT_DIR/template.tex" ]; then
                TEMPLATE_PATH="$SCRIPT_DIR/template.tex"
            elif [ -f "/usr/local/share/mdtexpdf/template.tex" ]; then
                TEMPLATE_PATH="/usr/local/share/mdtexpdf/template.tex"
            else
                echo -e "${RED}Error: template.tex not found in any of the expected locations.${NC}"
                return 1
            fi
        fi
    fi
    
    echo -e "Using template: ${GREEN}$TEMPLATE_PATH${NC}"

    # Run pandoc with the selected PDF engine
    pandoc "$INPUT_FILE" \
        --from markdown \
        --to pdf \
        --output "$OUTPUT_FILE" \
        --template="$TEMPLATE_PATH" \
        --pdf-engine=$PDF_ENGINE \
        $PANDOC_OPTS \
        --variable=geometry:margin=1in \
        --highlight-style=tango \
        --standalone

    # Check if conversion was successful
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Success! PDF created as $OUTPUT_FILE${NC}"
        return 0
    else
        echo -e "${RED}Error: PDF conversion failed.${NC}"
        return 1
    fi
}

# Function to create a new markdown document with LaTeX template
create() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: No output file specified.${NC}"
        echo -e "Usage: mdtexpdf create <output.md> [title] [author]"
        return 1
    fi

    OUTPUT_FILE="$1"
    TITLE="${2:-My Document}"
    AUTHOR="${3:-Your Name}"
    
    if [ -f "$OUTPUT_FILE" ]; then
        echo -e "${RED}Error: File '$OUTPUT_FILE' already exists.${NC}"
        echo -e "Use a different filename or delete the existing file."
        return 1
    fi

    echo -e "${YELLOW}Creating new markdown document: $OUTPUT_FILE${NC}"
    
    # Create the markdown file with YAML frontmatter and example content
    cat > "$OUTPUT_FILE" << EOF
---
title: "$TITLE"
author: "$AUTHOR"
date: "$(date +"%B %d, %Y")"
output:
  pdf_document:
    template: template.tex
---

# $TITLE

## Introduction

This is a sample document created with mdtexpdf. You can write regular Markdown text here.

## LaTeX Math Support

You can include inline math equations like this: \$E = mc^2\$ or \\\(F = ma\\\).

For display equations, use double dollar signs:

\$\$\\int_{a}^{b} f(x) \\, dx = F(b) - F(a)\$\$

## Formatting

You can use **bold text**, *italic text*, and \`code\`.

- Bullet points
- Work as expected

1. Numbered lists
2. Also work well

> Blockquotes are supported too.

## Tables

| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Cell 1   | Cell 2   | Cell 3   |
| Cell 4   | Cell 5   | Cell 6   |

## Code Blocks

\`\`\`python
def hello_world():
    print("Hello, world!")
\`\`\`

---

The footer of each page will show "Copyright This 2025" as specified in the template.
EOF

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Success! Markdown document created as $OUTPUT_FILE${NC}"
        echo -e "You can now edit this file and convert it to PDF using:"
        echo -e "${BLUE}mdtexpdf convert $OUTPUT_FILE${NC}"
        return 0
    else
        echo -e "${RED}Error: Failed to create markdown document.${NC}"
        return 1
    fi
}

# Function to install the script
install() {
    echo
    echo -e "${GREEN}Installing mdtexpdf...${NC}"
    if sudo -v; then
        # Create directories for templates and resources
        sudo mkdir -p /usr/local/share/mdtexpdf/templates
        sudo mkdir -p /usr/local/share/mdtexpdf/examples
        
        # Copy the script to /usr/local/bin
        sudo cp "$0" /usr/local/bin/mdtexpdf
        sudo chmod 755 /usr/local/bin/mdtexpdf
        
        # Copy templates to the shared directory
        SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
        
        # Look for templates in various locations
        if [ -d "$SCRIPT_DIR/templates" ]; then
            sudo cp -r "$SCRIPT_DIR/templates/"* /usr/local/share/mdtexpdf/templates/
            sudo chmod 644 /usr/local/share/mdtexpdf/templates/*
        elif [ -f "$SCRIPT_DIR/template.tex" ]; then
            sudo cp "$SCRIPT_DIR/template.tex" /usr/local/share/mdtexpdf/templates/
            sudo chmod 644 /usr/local/share/mdtexpdf/templates/template.tex
        fi
        
        # Copy example files
        if [ -d "$SCRIPT_DIR/examples" ]; then
            sudo cp -r "$SCRIPT_DIR/examples/"* /usr/local/share/mdtexpdf/examples/
            sudo chmod 644 /usr/local/share/mdtexpdf/examples/*
        elif [ -f "$SCRIPT_DIR/document.md" ] || [ -f "$SCRIPT_DIR/example.md" ]; then
            [ -f "$SCRIPT_DIR/document.md" ] && sudo cp "$SCRIPT_DIR/document.md" /usr/local/share/mdtexpdf/examples/
            [ -f "$SCRIPT_DIR/example.md" ] && sudo cp "$SCRIPT_DIR/example.md" /usr/local/share/mdtexpdf/examples/
            sudo chmod 644 /usr/local/share/mdtexpdf/examples/*
        else
            echo -e "${YELLOW}Warning: template.tex not found in the script directory.${NC}"
            echo -e "You'll need to provide your own template.tex file when converting documents."
        fi

        echo
        echo -e "${PURPLE}mdtexpdf has been installed successfully.${NC}"
        echo -e "You can now use ${GREEN}mdtexpdf${NC} command from anywhere."
        echo
        echo -e "Use ${BLUE}mdtexpdf help${NC} to see the commands."
        echo
    else
        echo -e "${RED}Error: Failed to obtain sudo privileges. Installation aborted.${NC}"
        exit 1
    fi
}

# Function to uninstall the script
uninstall() {
    echo
    echo -e "${GREEN}Uninstalling mdtexpdf...${NC}"
    if sudo -v; then
        echo -e "${YELLOW}Removing executable...${NC}"
        sudo rm -f /usr/local/bin/mdtexpdf
        
        echo -e "${YELLOW}Removing shared files...${NC}"
        sudo rm -rf /usr/local/share/mdtexpdf
        
        echo -e "${PURPLE}mdtexpdf has been uninstalled successfully.${NC}"
        echo
    else
        echo -e "${RED}Error: Failed to obtain sudo privileges. Uninstallation aborted.${NC}"
        exit 1
    fi
}

# Function to display help information
help() {
    echo -e "\n${YELLOW}═══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}         mdtexpdf - Markdown to PDF         ${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════${NC}\n"
    
    echo -e "${PURPLE}Description:${NC} mdtexpdf is a tool for converting Markdown documents to PDF using LaTeX templates."
    echo -e "${PURPLE}             It supports LaTeX math equations, custom templates, and more.${NC}"
    echo -e "${PURPLE}Usage:${NC}       mdtexpdf <command> [arguments]"
    echo -e "${PURPLE}License:${NC}     Apache 2.0"
    echo -e "${PURPLE}Code:${NC}        https://github.com/mik-tf/mdtexpdf\n"
    
    echo -e "${PURPLE}Commands:${NC}"
    echo -e "  ${GREEN}convert <input.md> [output.pdf]${NC}"
    echo -e "                  ${BLUE}Convert a Markdown file to PDF using LaTeX${NC}"
    echo -e "                  ${BLUE}Example:${NC} mdtexpdf convert document.md"
    echo -e "                  ${BLUE}Example:${NC} mdtexpdf convert document.md output.pdf\n"
    
    echo -e "  ${GREEN}create <output.md> [title] [author]${NC}"
    echo -e "                  ${BLUE}Create a new Markdown document with LaTeX template${NC}"
    echo -e "                  ${BLUE}Example:${NC} mdtexpdf create document.md"
    echo -e "                  ${BLUE}Example:${NC} mdtexpdf create document.md \"My Title\" \"Author Name\"\n"
    
    echo -e "  ${GREEN}check${NC}"
    echo -e "                  ${BLUE}Check if all prerequisites are installed${NC}"
    echo -e "                  ${BLUE}Example:${NC} mdtexpdf check\n"
    
    echo -e "  ${GREEN}install${NC}"
    echo -e "                  ${BLUE}Install mdtexpdf system-wide${NC}"
    echo -e "                  ${BLUE}Example:${NC} mdtexpdf install\n"
    
    echo -e "  ${GREEN}uninstall${NC}"
    echo -e "                  ${BLUE}Remove mdtexpdf from the system${NC}"
    echo -e "                  ${BLUE}Example:${NC} mdtexpdf uninstall\n"
    
    echo -e "  ${GREEN}help${NC}"
    echo -e "                  ${BLUE}Display this help information${NC}"
    echo -e "                  ${BLUE}Example:${NC} mdtexpdf help\n"
    
    echo -e "${PURPLE}Prerequisites:${NC}"
    echo -e "  - Pandoc: Document conversion tool"
    echo -e "  - LaTeX: PDF generation engine (pdflatex, xelatex, or lualatex)"
    echo -e "  - LaTeX Packages: Various packages for formatting and math support\n"
    
    echo -e "${PURPLE}For more information, see the README.md file.${NC}\n"
}

# Main script execution
case "$1" in
    convert)
        shift
        convert "$@"
        ;;
    create)
        shift
        create "$@"
        ;;
    check)
        check_prerequisites
        ;;
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    help)
        help
        ;;
    *)
        if [ -z "$1" ]; then
            echo -e "${RED}Error: No command specified.${NC}"
        else
            echo -e "${RED}Error: Unknown command '$1'.${NC}"
        fi
        echo -e "Use ${BLUE}mdtexpdf help${NC} to see available commands."
        exit 1
        ;;
esac

exit $?