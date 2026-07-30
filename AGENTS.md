# Zixy Project Guide

## Project Summary

Zixy is an iOS UIKit application based on the visual references and exported
assets in `/Users/myfy/Desktop/zixy`.

The current working tree provides the shared UIKit foundation, startup EULA,
and a root navigation preview. Feature controllers should be added as separate
files under the domain folders listed below.

The visual reference images are reference material only. Controllers must be
built from UIKit views, constraints, collection views, controls, and individual
image assets. Never render a full-page reference screenshot inside a controller
and never simulate controls with transparent hotspots. Persistent models,
repositories, and backend services have not been added yet.

## Source Layout

Every named controller must have its own Swift file. The file name must match
the controller class name.

```text
Zixy/Zixy/
├── App/
│   ├── AppDelegate.swift
│   └── SceneDelegate.swift
├── DesignSystem/
│   └── AppFont.swift
└── UI/
    ├── Auth/
    ├── Common/
    ├── Feed/
    ├── Main/
    ├── Messages/
    ├── Overlays/
    ├── Profile/
    ├── Rooms/
    └── Settings/
```

Place new controllers in the closest existing feature folder. Create a new
feature folder only when none of the existing domains is appropriate. Do not
create aggregate files such as `AuthControllers.swift` or
`FeatureControllers.swift`.

## Shared UI Foundations

- Screen controllers inherit from `BaseViewController` unless they require a
  different UIKit container superclass.
- `BaseViewController` owns a fixed `ZixyNavigationBar`, a page `contentView`,
  the shared blue-pink page gradient, and push navigation that hides the tab
  bar.
- `ZixyNavigationBar` follows the visual reference: a centered Avenir Next Bold
  title, a 40-point black rounded back button, and a symmetrical 40-point
  trailing action area. It must stay outside scrolling or keyboard-adjusted
  content.
- `MainTabBarController` owns four navigation stacks in this order: Home,
  Rooms, Messages, and Profile.
- `ZixyTabBar` is the full-width white custom tab bar used by the main
  container. It has rounded top corners, four equal icon-only buttons, and
  explicitly swaps every icon between gray normal and blue selected assets so
  exactly one item is selected at a time.
- Root controllers show `ZixyTabBar`; pushed child controllers hide it and
  restore it after returning to a tab root.
- Configure page navigation with
  `configureNavigation(title:showsBackButton:rightView:)`. Omit
  `showsBackButton` for automatic root/child behavior.
- All visible controls must be real, accessible UIKit views with explicit
  actions and layout constraints.
- The root and tab navigation controllers keep their navigation bars hidden and
  preserve the system interactive pop gesture.

## Typography

Use `AppFont.bold(size:relativeTo:)` for application text. The font resolves to
the iOS-provided `AvenirNext-Bold` face and falls back to a bold system font.

Examples:

```swift
label.font = AppFont.bold(size: 16)
label.font = AppFont.bold(size: 16, relativeTo: .body)
```

Do not introduce another font family without an explicit product requirement.

## Controller State Reuse

Use an enum inside a controller when multiple references represent states of
the same screen. Existing examples include:

- `MessagesViewController.Mode`: chats or rooms
- `ProfileSetupViewController.Gender`: female or male
- `RoomDetailViewController.Mode`: store or conversation
- `MyRoomViewController.Mode`: create or edit
- `ReleaseImageViewController.Mode`: empty or selected
- `AppAlertViewController.Kind`: alert variants
- `ProfileActionSheetViewController.Kind`: action-sheet variants

Do not create separate controller classes solely for these visual states.

## Navigation and Input Rules

- Keep the navigation bar fixed while the keyboard appears or disappears.
- Keep the active input visible above the keyboard and follow the keyboard
  animation.
- Restore the original layout when the keyboard is dismissed.
- A keyboard Done action must end editing.
- Tapping outside an input must dismiss the keyboard without blocking buttons,
  scrolling, list selection, or other gestures.
- Every pushed child screen must hide the tab bar. Returning to a tab root must
  restore it.
- Preserve the system left-edge swipe-to-go-back gesture.

## User-Owned Content Rules

- Only configure a More action when the content author or target user is not
  the current user.
- Never bind reporting, blocking, or similar actions to the current user's own
  content or profile.
- Keep a current-user guard inside the action handler even when the button is
  conditionally hidden.
- Use a toast for normal feedback, success, failure, and lightweight errors.
  Do not create a `UIAlertController` for those messages.

## Loading State Rules

- Sign in, Sign up, Save, Publish, Submit, Confirm, and Log out operations must
  display Loading while their actual work is in progress.
- StoreKit product lookup, purchase, verification, and secure coin crediting
  must remain covered by Loading.
- The first visit to Home after each app launch must display Loading once and
  hide it after the first screen is presented. Switching tabs, returning Home,
  or recreating Home during the same app run must not show it again.
- Perform synchronous input, session, permission, and balance validation before
  showing Loading. Validation failures use Toast without showing Loading.
- Show Loading immediately before network, database, file, StoreKit, or other
  time-consuming work starts.
- A Confirm action shows Loading only after the user confirms and all required
  validation succeeds; merely presenting the confirmation does not show it.
- Publish and Submit Loading begins when persistence or submission actually
  starts and ends only after saving and required UI refresh succeeds or fails.
- Save Loading covers the save and required data refresh. Back, Cancel, and
  validation failures do not show Loading.
- Sign in, Sign up, and Log out Loading covers identity persistence, session
  changes, and required root-controller replacement.
- Sending chat messages, including text and image messages, must never display
  full-screen Loading.
- Navigation, tab switching, scrolling, cell selection, likes, follows, and
  other lightweight local state changes do not show Loading unless they start
  a genuinely time-consuming submission.
- Loading must disable repeated taps and submissions for its complete lifetime.
- Once shown, Loading must remain visible for at least 1 second and normally
  disappear within 3 seconds. If the underlying operation takes longer than
  3 seconds, keep Loading visible until the operation reaches a terminal state;
  never hide it while required work is still in progress.
- Every success, failure, cancellation, pending result, and early-exit path
  after Loading begins must hide it and restore interaction.
- Loading remains visible for at least one second. Routine local operations
  should normally finish and hide it within three seconds, but genuinely
  unfinished work must keep Loading visible rather than hiding early.
- Loading must not move the navigation bar or break keyboard dismissal,
  controls, list interaction, edge-swipe navigation, or tab-bar behavior.

## AI Chat Daily Limit

- Each authenticated user may send at most three messages to
  `ZixyAIChatController` per local calendar day. The quota must be keyed by the
  normalized login identifier so accounts on the same device do not share a
  count.
- Guest access uses its own guest quota. Persist the date and count in
  `UserDefaults`, restore them after relaunch, and reset the count when the
  local calendar day changes.
- Validate the quota immediately before appending the user message. The fourth
  and later attempts must not change the conversation or request an AI reply
  and must show a Toast explaining that the daily limit was reached.

## Seed Database and Authentication

- On the first database creation, `ZixyDataStore` imports
  `Data/zixy_seed_users.csv` into the persistent Core Data store. The seed
  includes users, credentials, profiles, posts, follows, and chat messages.
- Every seeded user's email is the lowercase username followed by
  `@gmail.com`; seeded passwords are `123456` and are stored as SHA-256 hashes.
  Login must validate both fields against the database before creating a
  session.
- Elena and two randomly selected seeded users form a mutually following
  three-person group. The random choice is made only while creating an empty
  database, then remains stable through persistence.
- Initial conversations are created between every pair in that three-person
  group. Chat lists, conversation history, sent text messages, followers, and
  following lists must read from and write to `ZixyDataStore`.
- Elena owns two seeded chat rooms. One room contains three users in total and
  the other contains four users in total, with the non-Elena members selected
  randomly from the seeded users. Room membership is persisted and the Rooms
  list and room-detail seats must read these records from `ZixyDataStore`.

## Asset Catalog Layout

All application assets use the `zixy_` prefix and lowercase English
snake-case names.

```text
Assets.xcassets/
├── Common/
├── screens/   # Legacy full-page references; never load from app code
└── tabs/
```

Keep asset names unchanged when moving an image set between catalog groups.
Image-set directory names, raster filenames, `Contents.json` filenames, and
source references must remain synchronized.

Do not use Chinese, spaces, punctuation, duplicated extensions, export suffixes,
or temporary names in project resources.

## Code Language

Project source, identifiers, comments, UI strings, logs, errors, test data,
configuration keys, and resource filenames must be English. Product-facing
non-English text must be implemented through localization resources rather than
hard-coded source strings.

## Startup Flow

Successful sign-in and completed registration must persist the authenticated
user state through `ZixySessionStore` before replacing the root controller.
On later launches, `SceneDelegate` must use `ZixyMainContainerController` as
the window root when the persisted session is authenticated; otherwise it must
use `ZixyAccessCoordinator`. Logging out or removing the account must clear the
persisted session before routing back to authentication.

### Guest Access

- Tapping `I'm new` on `ZixyGatewayController` starts a guest session. It must
  not open Sign up or profile setup.
- The separate `Sign up` link continues to open the registration flow.
- Guest state must be persisted through `ZixySessionStore` independently from
  authenticated user state.
- `ZixyMainContainerController` remains the window root for a guest session,
  but guests may view only the first tab and its content.
- All four tab items must remain visible with their standard icon appearance
  for a guest session. Tabs two through four remain disabled and must be
  blocked at both the custom tab-bar control and container-selection levels so
  guest access cannot bypass the disabled buttons.
- Tapping tabs two through four as a guest must keep the first tab selected and
  present `ZixyAlertController(kind: .loginRequired)`. Choosing Log in clears
  the guest session and routes back to authentication; cancelling leaves the
  guest on the first tab.
- Guest sessions are read-only for social interactions. Guests must not like
  posts or comments, submit comments, follow or unfollow another user, or open
  More actions.
- More controls must be hidden for guests. Like, comment, and follow handlers
  must check `ZixySessionStore.allowsSocialInteraction` before changing state,
  even when the corresponding control is already disabled or hidden.
- When a guest attempts an otherwise visible restricted interaction, keep the
  underlying state unchanged and use a Toast prompting the guest to sign in.
- Successful authentication must replace guest state. Logging out or removing
  the account must clear both authenticated and guest session state.

Each tab owns a hidden-system-bar `UINavigationController` so custom
navigation, edge-swipe back, and child tab-bar hiding work independently per
tab.

Before the authentication screen can be used, `SceneDelegate` presents
`EULAViewController` on the first launch. Agreeing stores
`zixy_eula_accepted` in `UserDefaults`, dismisses the EULA, and continues the
existing flow. Cancelling terminates the current process as explicitly required
by the product flow. Subsequent launches skip the first-launch EULA.

On `ZixyGatewayController`, Login by email, Sign up, and `I'm new` must proceed
only after the agreement checkbox is selected. If it is not selected, keep the
user on the gateway screen and show a Toast requesting acceptance of the User
Agreement and Privacy Policy. Persist the checkbox state in `UserDefaults` and
restore both its behavior and selected appearance whenever the gateway screen
is created again. This preference is independent from authenticated and guest
session state.

The main container owns four tab roots:

1. `HomeViewController`
2. `RoomsViewController`
3. `MessagesViewController`
4. `ProfileViewController`

## CodeGraph

The repository contains a `.codegraph` index. Use CodeGraph before grep or
manual file reads when locating symbols or tracing controller navigation.

After adding, deleting, moving, or splitting Swift files, run:

```bash
codegraph sync
codegraph status
```

## Verification

Run the following checks after controller or asset changes:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project Zixy/Zixy.xcodeproj \
  -scheme Zixy \
  -destination generic/platform=iOS \
  -configuration Debug \
  -derivedDataPath /private/tmp/zixy-build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Validate each direct asset group with:

```bash
ruby /Users/myfy/.codex/skills/furno-asset-namer/scripts/validate_assets.rb \
  <asset-group-path> \
  Zixy
```

At the time of this document:

- `ZixyNavigationBar` and `BaseViewController` define the shared navigation
  appearance and behavior.
- No Swift source renders a full-page visual reference or transparent hotspot.
- The generic iOS device build succeeds.
