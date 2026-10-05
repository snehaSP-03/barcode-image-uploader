# BHIMA Barcode Photo App

Ops/Admin Flutter app: enter a barcode → show the catalog product if it exists → add/remove product photos (max 5).

Not POS, not customer catalog, not product-editor enrich. Uses existing Bhima inventory APIs only.

## Environments

| Env | API base |
| --- | --- |
| Stage (dev) | `https://htgwsvfhc2.execute-api.ap-south-1.amazonaws.com/stage` |
| Prod | `https://wu3o6czi99.execute-api.ap-south-1.amazonaws.com/prod` |

Use Stage until product signs off.

## Auth

`Authorization: Bearer <Cognito IdToken>`

Allowed groups: **Ops** or **Admin**. Presign / PATCH / DELETE → `403 forbidden` for other groups.

## Locked rules (handoff)

- Lookup: `GET /inventory/by-barcode/{barcode}` only
- Unknown barcode (`404 not_found`): show **Product not in catalog** — no create / enrich
- Max **5** images; block adds when `image_keys.length >= 5`
- After each S3 PUT, `PATCH` with the **full** `image_keys` list (existing + new)
- Display via `image_urls` from the API — never invent URLs from `s3_key`
- Content types: `image/jpeg`, `image/png`, `image/webp`
- Ignore lots / lot_pick_required

## Run on a phone

```powershell
cd c:\Users\sneha\barcode-image-uploader
Copy-Item .env.development.local .env -Force
flutter pub get
flutter devices
flutter run
```

Sign in with an **Admin/Ops** account (phone/email + 4-digit PIN).

## Operator flow

1. **Scan barcode** (camera) or type digits → lookup runs automatically after a scan
2. **200** → product screen (name, brand, sku, barcode, status, photos)
3. **404** → “Product not in catalog” — stop
4. Add photo (if under 5): gallery/camera → presign → S3 PUT → PATCH full keys → UI from returned `item`
5. Remove photo (optional): DELETE `{ s3_key }` → UI from returned `item`

## APIs used

| Method | Path |
| --- | --- |
| GET | `/inventory/by-barcode/{barcode}` |
| POST | `/inventory/{id}/images/presign` |
| PATCH | `/inventory/{id}` (`image_keys` full list) |
| DELETE | `/inventory/{id}/images` |

## What this app does not do

- `GET /inventory/barcode-lookup/{barcode}` (editor enrich)
- Create / onboard SKUs for unknown barcodes
- PATCH with only the newest `s3_key`
- Upload more than 5 photos
- Customer Cognito tokens for upload
- Build display URLs from raw `s3_key`
