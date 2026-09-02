# Zeta Global Hands-on Lab & Hackathon

Comprehensive documentation and code artifacts for the **Cloudera AI Hands-on Lab and Hackathon** organized for Zeta Global technical teams.

## Documentation Site

Once GitHub Pages is enabled, the documentation is published at:

**https://superellipse.github.io/zeta-hol/**

## Repository Structure

```
zeta-hol/
├── docs/                          # MkDocs documentation source
│   ├── index.md                   # Home page
│   ├── setup/                     # Login, workbench, project setup
│   ├── vibe-coding/               # Cursor Remote SSH & Claude CLI guides
│   ├── sample-code/               # Data upload documentation
│   ├── demo-videos/               # Workshop recording references
│   ├── images/                    # Screenshots for the guide
│   └── stylesheets/               # Custom CSS
├── artifacts/                     # Code artifacts for the hackathon
│   ├── sample_metric_data.json    # Sample campaign metrics data
│   └── dataload_notebook.ipynb    # Data loading Jupyter notebook
├── mkdocs.yml                     # MkDocs configuration
├── requirements.txt               # Python dependencies for MkDocs
└── .github/workflows/deploy.yml   # GitHub Pages deployment
```

## Local Development

### Prerequisites

- Python 3.12+
- pip

### Build and Preview

```bash
# Install dependencies
pip install -r requirements.txt

# Serve locally with live reload
mkdocs serve

# Build static site
mkdocs build
```

Open [http://127.0.0.1:8000](http://127.0.0.1:8000) to preview the documentation.

## GitHub Pages Setup

1. Push this repository to [SuperEllipse/zeta-hol](https://github.com/SuperEllipse/zeta-hol)
2. Go to **Settings → Pages**
3. Set **Source** to **Deploy from a branch**
4. Select branch **`gh-pages`** and folder **`/ (root)`**
5. Alternatively, the included GitHub Actions workflow deploys automatically on push to `main`

## Hackathon Guide Sections

| Section | Description |
|---------|-------------|
| [Login & Workbench Setup](docs/setup/login-and-project.md) | CDP login, Cloudera AI, zeta1-workbench |
| [Project Creation](docs/setup/project-and-runtimes.md) | Team project setup and Python runtimes |
| [Cursor Remote SSH](docs/vibe-coding/cursor-remote-ssh/) | Connect Cursor IDE to the workbench |
| [Claude Private Model](docs/vibe-coding/claude-private-model.md) | Use Claude CLI with CAI Inference |
| [Data Upload](docs/sample-code/data-upload.md) | Sample JSON data and loading notebook |
| [Demo Videos](docs/demo-videos/index.md) | Workshop recording |

## Workshop Login

**URL:** https://login.cdpworkshops.cloudera.com/auth/realms/field-marketing-amer/protocol/saml/clients/cdp-sso

Credentials are provided by your instructor at the start of the session.

## License

Documentation and sample artifacts are provided for the Zeta Global hackathon workshop.
