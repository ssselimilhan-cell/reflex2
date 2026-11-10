# Firestore TTL: room and invitation cleanup

The app assigns an `expiresAt` timestamp to waiting rooms and game invitations.

- Waiting room: 5 minutes after creation, or 5 minutes after a guest leaves and the table reopens.
- Occupied room: `expiresAt: null`, so a match is never deleted while players are seated.
- Cancelled/finished room: retained for one day.
- Incoming invitation: 5 minutes.
- Room chat message: 7 days.

The lobby and room screen enforce the five-minute waiting deadline while the app is active. Firestore TTL is the server-side safety cleanup if every client closes. Firestore TTL deletion is asynchronous and is typically performed within 24 hours after the expiration time; it is not an exact five-minute scheduler.

## Required IAM permission

The GitHub Actions service account is:

`firebase-adminsdk-fbsvc@stres-card.iam.gserviceaccount.com`

Grant it the **Cloud Datastore Index Admin** role:

`roles/datastore.indexAdmin`

This role provides the required `datastore.indexes.update` permission to create TTL policies. The Firestore rules deployment already succeeds before the TTL setup step; without this role, the workflow reports a TTL permission failure and does not enable server-side TTL.

## Apply after granting the role

In GitHub:

1. Open **Actions** in `ssselimilhan-cell/reflex2`.
2. Select **Firestore Kurallarını Canlı Projeye Yayımla**.
3. Choose branch `redesign/modern-competitive`.
4. Run workflow.

The workflow backfills expiry timestamps on existing room/invite records, then enables TTL for collection groups `rooms`, `invites`, and `room_messages`.

To inspect the configured policies with gcloud:

```sh
gcloud firestore fields ttls list --project=stres-card
```
