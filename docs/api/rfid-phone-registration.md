# Phone NFC registration API

## Endpoint

`POST /rw/v1/bk/rfid-cards/phone-registration`

Authentication: required. Send the user's existing BookIt access token as a bearer token. The authenticated account must have the passenger (`user`) or administrator (`admin`) role.

The endpoint is intended for a UID read locally by the signed-in Android phone. It does not accept a reader device token and does not create a hardware registration session.

## Request

```http
POST /rw/v1/bk/rfid-cards/phone-registration
Authorization: Bearer <bookit-access-token>
Content-Type: application/json
```

```json
{
  "cardUid": "04A10BFF"
}
```

The server accepts hexadecimal UID text with optional separators, normalizes it to uppercase hexadecimal, and requires an even number of 8–40 hex characters (4–20 bytes).

## Success

Newly linked:

```json
{
  "message": "NFC card registered successfully.",
  "card": {
    "id": "<card-id>",
    "cardUid": "04A10BFF",
    "status": "active",
    "registeredAt": "<timestamp>"
  }
}
```

Already linked to the same account returns HTTP 200 with an idempotent success message and the existing card.

## Errors

| HTTP | Meaning |
|---|---|
| 400 | Missing or invalid UID |
| 401 | Missing or invalid BookIt access token |
| 409 | UID is already linked to a different passenger |
| 429 | Registration rate limit reached |
| 500 | Registration could not be persisted |

The route is protected by the normal authenticated API middleware and a per-IP rate limit of 10 registration attempts per 15 minutes. Database uniqueness is also treated as a duplicate-card conflict.

## Trust boundary

The server trusts the authenticated BookIt account, not the phone's claim that a UID proves card ownership. UID-only cards may be cloned or emulated. This endpoint is for account association and must not be used as the sole proof for payment or boarding authorization.
