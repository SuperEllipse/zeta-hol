# Using Cursor with Cloudera AI (Remote SSH)

This section explains how to connect **Cursor IDE** to your Cloudera AI workbench session using **Remote SSH**, enabling AI-assisted coding directly against your project environment.

## Overview

Cursor supports remote development via SSH, allowing you to:

- Edit code locally in Cursor while files run on the Cloudera AI workbench
- Use Cursor's AI features against your project codebase
- Access terminal, notebooks, and project files seamlessly

## Prerequisites

Before connecting, ensure you have:

- [x] Completed [Login & Workbench Setup](../setup/login-and-project.md)
- [x] Created your team [project](../setup/project-and-runtimes.md)
- [x] Started an active session in your project
- [x] **Cursor IDE** installed on your local machine ([cursor.com](https://cursor.com))
- [x] SSH access credentials from your Cloudera AI session

## Step 1: Install the Remote SSH Extension

1. Open **Cursor**
2. Go to **Extensions** (`Ctrl+Shift+X` / `Cmd+Shift+X`)
3. Search for **Remote - SSH**
4. Install the extension (published by Anysphere or Microsoft)

## Step 2: Obtain SSH Connection Details

From your Cloudera AI project session:

1. Click **Terminal Access** in the top navigation bar (or open a terminal session)
2. Look for SSH connection information provided by the workbench, typically:
   - **Host**: `<workbench-host>.cloudera.com`
   - **Port**: `<assigned-port>`
   - **Username**: `cdsw` (default Cloudera Data Science Workbench user)
   - **Key or password**: Provided in session settings or Terminal Access panel

!!! note "SSH Access Location"
    SSH connection details are available under **Terminal Access** or **Project Settings → SSH** in your Cloudera AI workbench. Your instructor can provide the exact location for this workshop environment.

## Step 3: Configure SSH in Cursor

### Option A: Quick Connect

1. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac) to open the Command Palette
2. Type **Remote-SSH: Connect to Host**
3. Enter your connection string:

```bash
ssh cdsw@<workbench-host> -p <port>
```

### Option B: SSH Config File (Recommended)

Add an entry to your local `~/.ssh/config` file:

```ssh-config
Host cloudera-zeta
    HostName <workbench-host>
    User cdsw
    Port <port>
    IdentityFile ~/.ssh/<your-key-file>
    StrictHostKeyChecking no
```

Then in Cursor:

1. Command Palette → **Remote-SSH: Connect to Host**
2. Select **`cloudera-zeta`**
3. Cursor opens a new window connected to the remote environment

## Step 4: Open Your Project Folder

Once connected:

1. Click **Open Folder**
2. Navigate to your project directory (typically `/home/cdsw` or your project path)
3. Click **OK** to trust the workspace

Your Cursor editor now operates against the remote Cloudera AI filesystem.

## Step 5: Configure Cloudera AI Inference (Optional)

If you want Cursor to use the Cloudera AI Inference endpoint for AI features:

1. In Cursor, open **Settings** → **Models**
2. Add a custom OpenAI-compatible endpoint:
   - **Base URL**: Your CAI inference endpoint (available in session environment variables)
   - **API Key**: Use the key provided in your session or leave blank if using local proxy
3. Select the configured model for AI completions

Environment variables in your session typically include:

```bash
echo $CAI_HOME
echo $OPENAI_BASE_URL
```

These point to the LiteLLM proxy and Cloudera AI Inference configuration.

## Step 6: Start Coding

With Remote SSH connected, you can:

- Create and edit Python files, notebooks, and scripts
- Use Cursor's AI chat and inline completions
- Run terminal commands on the remote workbench
- Debug code with full IDE support

!!! tip "Best Practice"
    Keep your Cloudera AI session running while using Remote SSH. If the session stops, the SSH connection will drop.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Connection refused | Verify the session is running and SSH port is correct |
| Permission denied | Check SSH key permissions (`chmod 600 ~/.ssh/<key>`) |
| Host key verification failed | Add `StrictHostKeyChecking no` to SSH config (workshop only) |
| Cursor AI not responding | Verify CAI inference endpoint and API key configuration |
| Slow file sync | Ensure stable network; avoid editing very large files locally |

## Alternative: Claude CLI

If you prefer working entirely in the browser without Remote SSH, see **[Claude with Private Model](claude-private-model.md)** for using the Claude CLI directly in the workbench terminal.
