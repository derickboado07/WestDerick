# ecommerce_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Chat feature and Firestore indexes

This app includes a simple real-time 1:1 chat between users and the admin. Messages are stored under `chats/{userId}/messages` with unread counters on `chats/{userId}`. To support the queries used by the chat, add the following single-field index exemptions in Firebase console:

1) messages subcollection
- Collection ID: `messages`
- Field Path: `createdAt`
- Indexing: enable both Ascending and Descending

2) chats collection
- Collection ID: `chats`
- Field Path: `lastMessageAt`
- Indexing: enable both Ascending and Descending

After adding, wait for the indexes to finish building.

### Usage
- User: tap the "Contact Admin" floating action button on Home to open the chat. A Material badge indicates unread messages.
- Admin: open Admin Panel -> "View User Chats" to see all chats ordered by most recent, with unread badges per user.
- Opening a chat automatically resets the appropriate unread counter.

## Admin: Manage Products (Add/Edit/Delete)

The Admin Panel lets admins add new products and now also edit or delete existing ones. Products are stored in the `products` collection with fields: `name`, `description`, `price`, `imageUrl`, `createdAt`.

- Edit: In Admin Panel, scroll to "Manage Products" and tap the pencil icon to update name, description, price, or image URL.
- Delete: Tap the trash icon and confirm. Deletions remove the product document; the Home screen (used by users) streams the `products` collection and will automatically stop showing deleted items.

Notes:
- Updates also write `updatedAt` with `FieldValue.serverTimestamp()`.
- Home screen sorts by `createdAt` descending.

## Optional Module: Collaborative Cart & Split Pay

This is an additive feature that lets users create a temporary shared cart session, invite others via Session ID or QR code, import the contents of their personal cart, and generate a split payment plan (equal split now; custom/item-based extensible).

### Overview
Route: `/collab-cart` (not linked by default from home; you can navigate manually or add a button).

Core entities (client-side only right now):
1. `CartParticipant` – represents a user/guest in the session.
2. `CartSession` – holds participants + imported cart snapshot + optional split plan.
3. `SplitPaymentPlan` – describes how the subtotal is divided (current modes: `percentage`, `custom`).

### Real-time Sync
The screen uses an in-memory broadcast channel by default (no backend requirement). To enable a real WebSocket server:
1. Provide a `wsUrl` to `CollabCartService` and use `WebSocketRealTimeChannel()` instead of `InMemoryRealTimeChannel()` in `CollabCartScreen`.
2. Server should broadcast JSON messages of the form `{ "type": "join" | "leave" | "cart_update" | "split_update" | "session_closed" }`.

### Payment Links
Current implementation demonstrates link generation by listing participant shares. Replace with real payment link creation (e.g., Stripe Checkout, PayPal) per share.

### Extending Split Modes
Add logic in `CollabCartProvider` for `items` mode (allocate specific item IDs to participants) and adjust `SplitPaymentShare` to include `itemIds`.

### Security / Persistence
The session is ephemeral client-side. For production:
- Persist sessions in Firestore or your backend DB.
- Authorize participant actions (join/leave/update) through secure server-side validation.
- Prevent tampering by recalculating split server-side before generating payment intents.

### Quick Demo Steps
1. Run the app.
2. Navigate to `/collab-cart` (e.g., hot restart then `Navigator.pushNamed(context, '/collab-cart')`).
3. Enter a name and Create Session.
4. In another emulator/device, open the same route and Join using the Session ID.
5. On host side, tap "Import from My Cart" after adding items to personal cart.
6. Tap "Equal Split" then "Create Payment Links" (demo output).

### Environment Variable (Optional)
If using a WebSocket backend, store the URL in a Dart define or .env approach (e.g., `--dart-define=COLLAB_WS=wss://yourserver/sockets`). Inject into `CollabCartService(wsUrl: const String.fromEnvironment('COLLAB_WS'))`.

### Removal / Isolation
All new files are under `lib/collab/`; removing that directory and the route entry in `main.dart` fully detaches the feature.

