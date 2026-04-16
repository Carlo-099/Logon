const admin = require("firebase-admin");
const {onValueWritten} = require("firebase-functions/v2/database");
const {setGlobalOptions} = require("firebase-functions/v2");
const {defineSecret} = require("firebase-functions/params");
const sgMail = require("@sendgrid/mail");

admin.initializeApp();
setGlobalOptions({region: "asia-southeast1", maxInstances: 10});

const SENDGRID_API_KEY = defineSecret("SENDGRID_API_KEY");
const SENDGRID_FROM_EMAIL = defineSecret("SENDGRID_FROM_EMAIL");

function isValidLatLon(lat, lon) {
  return Number.isFinite(lat) &&
    Number.isFinite(lon) &&
    lat >= -90 &&
    lat <= 90 &&
    lon >= -180 &&
    lon <= 180;
}

exports.sendGpsLostEmail = onValueWritten({
  ref: "/users/{uid}/gps_alerts/last",
  secrets: [SENDGRID_API_KEY, SENDGRID_FROM_EMAIL],
}, async (event) => {
  const uid = event.params.uid;
  const before = event.data.before.val();
  const after = event.data.after.val();

  if (!after) return;
  if (after.lost !== true) return;

  // Prevent duplicate emails for same event.
  const beforeMs = before && Number(before.atMs || 0);
  const afterMs = Number(after.atMs || 0);
  if (beforeMs && beforeMs === afterMs) return;

  const lat = Number(after.lastLat);
  const lon = Number(after.lastLon);
  if (!isValidLatLon(lat, lon)) {
    console.log("Skipping alert: invalid lastLat/lastLon", {uid, lat, lon});
    return;
  }

  const contactsSnap = await admin.database()
    .ref(`/users/${uid}/emergency_contacts/emails`)
    .get();

  const raw = contactsSnap.val();
  const emails = Array.isArray(raw) ?
    raw.map((x) => String(x || "").trim()).filter(Boolean).slice(0, 3) :
    [];

  if (!emails.length) {
    console.log("No emergency emails configured for uid", uid);
    return;
  }

  const mapsLink = `https://www.google.com/maps?q=${lat},${lon}`;
  const subject = "Logon Cane Alert: GPS signal lost";
  const text = [
    "The cane device reported a GPS signal loss.",
    "",
    `Last known latitude: ${lat.toFixed(6)}`,
    `Last known longitude: ${lon.toFixed(6)}`,
    `Open in Google Maps: ${mapsLink}`,
    "",
    "If needed, copy-paste the coordinates into Google Maps.",
  ].join("\n");
  const html = `
    <p><strong>Logon Cane Alert:</strong> GPS signal lost.</p>
    <p>Last known location:</p>
    <ul>
      <li><strong>Latitude:</strong> ${lat.toFixed(6)}</li>
      <li><strong>Longitude:</strong> ${lon.toFixed(6)}</li>
    </ul>
    <p><a href="${mapsLink}">Open location in Google Maps</a></p>
    <p>If needed, copy-paste the coordinates into Google Maps.</p>
  `;

  sgMail.setApiKey(SENDGRID_API_KEY.value());

  await sgMail.send({
    to: emails,
    from: SENDGRID_FROM_EMAIL.value(),
    subject,
    text,
    html,
  });

  console.log("GPS lost alert email sent", {uid, recipients: emails.length, afterMs});
});
