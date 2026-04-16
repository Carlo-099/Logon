# Functions: GPS Lost Email Alert (SendGrid)

This folder contains Firebase Cloud Functions that send an email when the cane reports GPS loss.

## Trigger

- Realtime Database path: `/users/{uid}/gps_alerts/last`
- Function: `sendGpsLostEmail`
- Sends to: `/users/{uid}/emergency_contacts/emails` (max 3 addresses)

## Required Secrets

Set these before deploy:

```bash
firebase functions:secrets:set SENDGRID_API_KEY
firebase functions:secrets:set SENDGRID_FROM_EMAIL
```

- `SENDGRID_API_KEY`: API key from SendGrid.
- `SENDGRID_FROM_EMAIL`: a verified sender email in SendGrid.

## Deploy

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

## Test Payload

Write this object into:
`/users/<uid>/gps_alerts/last`

```json
{
  "lost": true,
  "lastLat": 14.801503,
  "lastLon": 120.935563,
  "atMs": 123456789,
  "source": "esp32"
}
```

The function will send one email per new `atMs` event.
