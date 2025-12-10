#!/bin/bash

# Zyl Build Script
# usage: ./build.sh [option]

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

ZYL_HOME="$HOME/.zyl"
LOCAL_BIN="$HOME/.local/bin"
EXECUTABLE_NAME="zyl" # Assumes 'dub' produces a binary named 'zyl'

log_info() { echo -e "${YELLOW}[INFO] $1${NC}"; }
log_success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $1${NC}"; }

# Function to check and install dependencies
check_dependencies() {
    log_info "Checking dependencies..."

    local MISSING_DEPS=0

    # Check for LDC2
    if ! command -v ldc2 &> /dev/null; then
        log_info "LDC2 not found."
        MISSING_DEPS=1
    fi

    # Check for DUB
    if ! command -v dub &> /dev/null; then
        log_info "DUB not found."
        MISSING_DEPS=1
    fi

    if [ $MISSING_DEPS -eq 1 ]; then
        log_info "Attempting to install missing dependencies (ldc, dub, llvm-devel)..."
        
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case $ID in
                ubuntu|debian|pop|mint)
                    log_info "Detected Debian-based system."
                    sudo apt-get update
                    # Note: Package names might vary slightly by version, but these are standard
                    sudo apt-get install -y ldc dub llvm-dev libxml2-dev clang
                    ;;
                fedora|rhel|centos)
                    log_info "Detected Fedora-based system."
                    sudo dnf install -y ldc dub llvm-devel libxml2-devel clang
                    ;;
                arch|manjaro)
                    log_info "Detected Arch-based system."
                    sudo pacman -S --noconfirm ldc dub llvm clang
                    ;;
                *)
                    log_error "Unsupported distribution for auto-install ($ID)."
                    log_error "Please install 'ldc', 'dub', and 'llvm-devel' manually."
                    exit 1
                    ;;
            esac
        else
            log_error "Cannot detect OS. Please install dependencies manually."
            exit 1
        fi
    else
        log_info "Dependencies found (ldc2, dub)."
    fi
}

# Function to setup ~/.zyl and copy stdlib
setup_environment() {
    log_info "Setting up Zyl environment at $ZYL_HOME..."

    if [ ! -d "./std" ]; then
        log_error "Standard library folder './std' not found in current directory!"
        exit 1
    fi

    # Create directory
    mkdir -p "$ZYL_HOME"

    # Copy stdlib (remove old one to ensure clean update)
    rm -rf "$ZYL_HOME/std"
    cp -r "./std" "$ZYL_HOME/std"

    log_success "Environment setup complete. Stdlib copied to $ZYL_HOME/std"
}

# Function to build the compiler
build_compiler() {
    log_info "Building Zyl compiler using LDC2..."
    
    # Run dub build
    if dub build --compiler=ldc2; then
        log_success "Build successful!"
    else
        log_error "Build failed."
        exit 1
    fi
}

# Function to install the binary to ~/.local/bin
install_binary() {
    log_info "Installing binary to $LOCAL_BIN..."

    mkdir -p "$LOCAL_BIN"

    if [ -f "./$EXECUTABLE_NAME" ]; then
        cp "./$EXECUTABLE_NAME" "$LOCAL_BIN/"
        chmod +x "$LOCAL_BIN/$EXECUTABLE_NAME"
        log_success "Binary installed to $LOCAL_BIN/$EXECUTABLE_NAME"
        
        # Check PATH
        if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
            echo ""
            log_info "WARNING: $LOCAL_BIN is not in your PATH."
            echo "Please add the following line to your shell configuration (.bashrc, .zshrc, etc.):"
            echo -e "${GREEN}export PATH=\"\$PATH:$LOCAL_BIN\"${NC}"
            echo ""
        fi
    else
        log_error "Executable './$EXECUTABLE_NAME' not found. Did the build pass?"
        exit 1
    fi
}

show_help() {
    echo "Usage: ./build.sh [OPTION]"
    echo "Options:"
    echo "  (no arguments)   Full process: Check deps, setup env, build, and install."
    echo "  --build-only     Only compile the project."
    echo "  --stdlib-only    Only copy ./std to ~/.zyl/std."
    echo "  --validate       Only check and install dependencies."
    echo "  --help           Show this message."
}

# Main Execution Logic
case "$1" in
    --build-only)
        build_compiler
        ;;
    --stdlib-only)
        setup_environment
        ;;
    --validate)
        check_dependencies
        ;;
    --help)
        show_help
        ;;
    *)
        # Default behavior: Full install
        check_dependencies
        setup_environment
        build_compiler
        install_binary
        log_success "Zyl is ready! Run 'zyl --help' to test."
        ;;
esac
