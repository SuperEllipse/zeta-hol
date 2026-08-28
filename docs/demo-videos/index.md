# Demo Videos

Workshop demo recordings are available below. These videos walk through key setup steps and can be referenced during the hackathon.

## Workshop Recording — August 28, 2026

!!! info "Video Placement"
    Place the workshop recording MP4 file at `docs/videos/workshop-recording.mp4` in the repository. Once uploaded, the video below will be available on the published site.

<video controls width="100%" style="max-width: 960px; border-radius: 4px;">
  <source src="../videos/workshop-recording.mp4" type="video/mp4">
  Your browser does not support the video tag. Download the recording from the
  <a href="https://github.com/SuperEllipse/zeta-hol/tree/main/docs/videos">repository</a>.
</video>

### Recording Details

| Detail | Value |
|--------|-------|
| **Filename** | `GMT20260828-025554_Recording_1728x996.mp4` |
| **Date** | August 28, 2026 |
| **Resolution** | 1728 × 996 |

---

## What the Demo Covers

The workshop recording typically includes:

1. Logging into the Cloudera workshop environment
2. Navigating to Cloudera AI and the Zeta workbench
3. Creating a team project
4. Starting a session with Claude Code runtime
5. Using the Claude CLI for AI-assisted coding
6. Loading sample data with the provided notebook

For step-by-step written instructions, refer to the corresponding documentation sections:

- [Login & Workbench Setup](../setup/login-and-project.md)
- [Project Creation & Runtimes](../setup/project-and-runtimes.md)
- [Claude with Private Model](../vibe-coding/claude-private-model.md)
- [Data Upload & Insertion](../sample-code/data-upload.md)

---

## Adding the Video to the Repository

If you have the MP4 file locally, add it to the repo:

```bash
# Copy the recording into the docs/videos folder
cp GMT20260828-025554_Recording_1728x996.mp4 docs/videos/workshop-recording.mp4

# Commit and push
git add docs/videos/workshop-recording.mp4
git commit -m "Add workshop demo recording"
git push
```

!!! note "Large File Warning"
    Video files may exceed GitHub's 100 MB file size limit. If the recording is too large, consider:

    - Using [Git LFS](https://git-lfs.github.com/) for the video file
    - Hosting on a shared drive and linking externally
    - Uploading to the Cloudera AI workbench **Data** tab for team access
