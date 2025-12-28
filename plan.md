# EHTML Feature Parity Plan (htmx Comparison)

This plan lists missing features compared to htmx, ordered from easiest to hardest to implement. Check off each item as you complete it.

## 1. Emit Custom Lifecycle Events (Easy)

- Emit custom events (e.g., `ehtml:beforeRequest`, `ehtml:afterSwap`, `ehtml:error`, etc.) at key points in the request/swap lifecycle.
- Allow users to listen for these events on elements or document.

## 2. Fine-grained Attribute Support (Easy)

- Add support for more htmx-like attributes (e.g., `data-params`, `data-headers`, `data-disabled-elt`, `data-encoding`).
- Allow disabling elements during requests, custom encoding, etc.

## 3. Swap Animation and Transitions (Easy/Medium)

- Add support for CSS transitions/animations during swaps (e.g., add/remove classes before/after swap, support for transition hooks).

## 4. Attribute Inheritance and Boosting (Medium)

- Implement attribute inheritance for nested elements (e.g., parent attributes apply to children if not overridden).
- Improve boosting for links/forms (automatic AJAX for navigation and submission).

## 5. Request Filtering and Conditional Requests (Medium)

- Add support for conditional requests (e.g., only send certain params, filter which elements trigger requests, etc.).

## 6. Out-of-Band Swaps (Medium/Hard)

- Support updating multiple targets from a single response (e.g., via special markers in the response, like htmx's `hx-swap-oob`).

## 7. History and State Management (Hard)

- Implement full browser history and state restoration (not just push/replace, but restoring content and scroll position on back/forward).

## 8. Request/Response Extensions (Hard)

- Add a plugin/extension system for request/response processing (e.g., polling, custom behaviors, etc.).

## 9. WebSocket and SSE Support (Hardest)

- Add built-in support for WebSockets and Server-Sent Events for real-time updates (e.g., `data-ws`, `data-sse`).

---

## How to Use This Plan

- Work through the list from top to bottom.
- Check off each feature as you implement it.
- For each feature, add notes or links to implementation details as needed.

---

_Last updated: December 28, 2025_
