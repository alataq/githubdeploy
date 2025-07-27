#!/bin/bash

# --- Configuration ---
# Define the name of the repository (e.g., "my-web-app" or "backend-api").
REPO_NAME="your-repo-name"

# Define the GitHub username or organization that owns the repository.
GITHUB_USERNAME="your-github-username-or-org"

# Define the absolute path on the server where the repository should be cloned/updated.
# This directory will contain the repository's folder (e.g., /var/www/html/my-web-app).
CLONE_DIR="/path/to/your/desired/directory"

# Define the default branch to pull from (e.g., "main", "master", or a specific feature branch).
DEFAULT_BRANCH="main"

# Full path to the repository
REPO_PATH="$CLONE_DIR/$REPO_NAME"

# --- Store Initial Directory ---
# Store the directory from which the script was executed.
INITIAL_DIR=$(pwd)
echo "Starting deployment from: $INITIAL_DIR"

# --- Functions ---

# Function to handle errors and exit
handle_error() {
    echo "Error: $1" >&2
    exit 1
}

# Function to clone the repository
clone_repository() {
    echo "Repository '$REPO_NAME' does not exist or was problematic. Cloning branch '$DEFAULT_BRANCH'..."
    cd "$CLONE_DIR" || handle_error "Cannot change to directory $CLONE_DIR for cloning. Check permissions and path."

    git clone -b "$DEFAULT_BRANCH" "git@github.com:${GITHUB_USERNAME}/${REPO_NAME}.git"
    if [ $? -eq 0 ]; then
        echo "Successfully cloned '$REPO_NAME' (branch '$DEFAULT_BRANCH') into $CLONE_DIR."
        cd "$REPO_PATH" || handle_error "Could not change into newly cloned repository $REPO_PATH."
    else
        handle_error "Failed to clone '$REPO_NAME' (branch '$DEFAULT_BRANCH'). Check SSH key setup, network, and repository/branch name."
    fi
}

# Function to update the repository (pull/reset/clean)
update_repository() {
    echo "Repository '$REPO_NAME' exists. Attempting to update from branch '$DEFAULT_BRANCH'..."
    cd "$REPO_PATH" || handle_error "Cannot change to repository directory $REPO_PATH. Check permissions."

    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]; then
        echo "Warning: Current branch is '$CURRENT_BRANCH', switching to '$DEFAULT_BRANCH'."
        git checkout "$DEFAULT_BRANCH" || {
            echo "Error: Failed to checkout branch '$DEFAULT_BRANCH' in existing repository. Initiating re-clone."
            return 1 # Indicate failure so main logic can re-clone
        }
    fi

    echo "Attempting to fetch, reset, and clean changes from branch: $DEFAULT_BRANCH"
    git fetch origin "$DEFAULT_BRANCH" && \
    git reset --hard origin/"$DEFAULT_BRANCH" && \
    git clean -fdx

    if [ $? -eq 0 ]; then
        echo "Successfully updated and reset latest changes for '$REPO_NAME' on branch '$DEFAULT_BRANCH'."
        return 0 # Indicate success
    else
        echo "Error: Failed to fetch/reset/clean changes for '$REPO_NAME' from branch '$DEFAULT_BRANCH'. Initiating re-clone."
        return 1 # Indicate failure so main logic can re-clone
    fi
}

# --- Main Logic ---

# Ensure the target directory for the repository exists.
mkdir -p "$CLONE_DIR"

# Check if the repository's directory already exists.
if [ -d "$REPO_PATH" ]; then
    # Attempt to update the existing repository
    update_repository
    # If update_repository returns 1 (failure), delete and re-clone
    if [ $? -ne 0 ]; then
        echo "Removing problematic repository directory '$REPO_NAME'..."
        rm -rf "$REPO_PATH" # Remove the entire repository directory
        clone_repository # Re-clone
    fi
else
    # If repository does not exist, clone it
    clone_repository
fi

# --- Custom Post-Deployment Tasks ---
# You can add your custom commands here that need to run after the repository
# has been successfully cloned or updated.
#
# Examples include:
# 1. Installing dependencies (e.g., Node.js, Python, PHP):
#    cd "$REPO_PATH" || handle_error "Failed to change directory to $REPO_PATH for post-deployment tasks."
#    npm install
#    composer install --no-dev --optimize-autoloader
#    pip install -r requirements.txt
#
# 2. Running database migrations:
#    php artisan migrate --force
#    python manage.py migrate
#
# 3. Building assets (e.g., for a frontend application):
#    npm run build
#
# 4. Restarting services (e.g., web server, application server):
#    sudo systemctl restart nginx
#    sudo systemctl restart my-app-service
#
# 5. Setting up permissions (if necessary):
#    sudo chown -R www-data:www-data "$REPO_PATH"
#    sudo chmod -R 755 "$REPO_PATH/storage"
#
# Make sure to handle errors for your custom commands as well,
# similar to how `handle_error` is used above.

echo "Deployment script ended."

# --- Return to Initial Directory ---
# Return to the directory where the script was initially executed.
cd "$INITIAL_DIR" || handle_error "Failed to return to the initial directory: $INITIAL_DIR"
echo "Returned to initial directory: $(pwd)"
