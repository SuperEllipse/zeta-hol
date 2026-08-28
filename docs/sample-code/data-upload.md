# Data Upload and Insertion

This section provides sample code and data files for loading campaign metric data into your Cloudera AI project during the hackathon.

## Artifacts

The following files are available in the [zeta-hol repository](https://github.com/SuperEllipse/zeta-hol):

| File | Description | Location |
|------|-------------|----------|
| `sample_metric_data.json` | Sample campaign metrics (10 records) | [`artifacts/sample_metric_data.json`](https://github.com/SuperEllipse/zeta-hol/blob/main/artifacts/sample_metric_data.json) |
| `dataload_notebook.ipynb` | Jupyter notebook for loading and analyzing data | [`artifacts/dataload_notebook.ipynb`](https://github.com/SuperEllipse/zeta-hol/blob/main/artifacts/dataload_notebook.ipynb) |

## Getting the Files into Your Project

Choose one of these methods:

### Option 1: Upload via the Data Tab

1. Open your project in Cloudera AI
2. Click **Data** in the top navigation
3. Upload `sample_metric_data.json` directly

### Option 2: Clone the Repository

In your workbench terminal:

```bash
git clone https://github.com/SuperEllipse/zeta-hol.git
cd zeta-hol
```

Files will be available at `zeta-hol/artifacts/`.

### Option 3: Download Individual Files

```bash
curl -O https://raw.githubusercontent.com/SuperEllipse/zeta-hol/main/artifacts/sample_metric_data.json
curl -O https://raw.githubusercontent.com/SuperEllipse/zeta-hol/main/artifacts/dataload_notebook.ipynb
```

---

## Sample Data Schema

The JSON file contains campaign performance metrics:

```json
{
  "id": 1,
  "campaign_id": "CMP-1001",
  "campaign_name": "Summer Email Blast",
  "channel": "email",
  "impressions": 125000,
  "clicks": 3750,
  "conversions": 412,
  "spend_usd": 8500.00,
  "revenue_usd": 24680.50,
  "date": "2026-08-01"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Record identifier |
| `campaign_id` | string | Unique campaign code |
| `campaign_name` | string | Human-readable campaign name |
| `channel` | string | Marketing channel (email, push, display, etc.) |
| `impressions` | integer | Number of ad impressions |
| `clicks` | integer | Number of clicks |
| `conversions` | integer | Number of conversions |
| `spend_usd` | float | Campaign spend in USD |
| `revenue_usd` | float | Revenue attributed in USD |
| `date` | string | Date (ISO 8601 format) |

---

## Using the Notebook

Follow along with the **[workshop demo recording](../demo-videos/index.md)**, which walks through loading sample data step by step.

1. Upload or clone `dataload_notebook.ipynb` into your project
2. Open it in JupyterLab (from your active session)
3. Run all cells sequentially, as demonstrated in the video

The notebook covers:

1. **Setup** — Import libraries
2. **Load JSON** — Read sample metric data
3. **Create DataFrame** — Convert to pandas
4. **Derived Metrics** — Calculate CTR, conversion rate, ROAS, CPC
5. **Aggregation** — Summarize by marketing channel
6. **Export** — Save to CSV and Parquet
7. **Database Insert** — Optional SQLAlchemy example (commented out)

---

## Derived Metrics Reference

| Metric | Formula | Description |
|--------|---------|-------------|
| **CTR** | clicks / impressions × 100 | Click-through rate (%) |
| **Conversion Rate** | conversions / clicks × 100 | Conversion rate (%) |
| **ROAS** | revenue / spend | Return on ad spend |
| **CPC** | spend / clicks | Cost per click |
