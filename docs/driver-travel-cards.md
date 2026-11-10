# BookIt Travel Cards

Passengers register an NFC card in Profile → RFID cards, add a paid unused ticket to it, and can show its generated BookIt QR token when NFC is unavailable.

Drivers open Scan → Scan Travel Card. They download the assigned bus's paid-ticket manifest while online. NFC UID or QR token scans are checked against card ownership, payment, bus assignment, travel date and prior use. Online redemption is atomic.

Offline scans are stored in platform secure storage and shown as provisional. On synchronization, the server rechecks driver/bus assignment, manifest validity, card-ticket link, payment and prior use. A ticket accepted by another offline reader or cancelled after download may be rejected. Use one assigned driver device per trip.

UID-only NFC cards can be cloned. Production deployments requiring clone resistance should use secure NFC cards with challenge-response, such as DESFire EV2/EV3.
