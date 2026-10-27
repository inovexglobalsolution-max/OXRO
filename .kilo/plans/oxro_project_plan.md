# OXRO Project Plan

## Project Overview

**Project Name:** oxro
**Type:** Flutter mobile application (shopping/restaurant platform)
**Location:** D:\OXRO\oxro

## Current State

### Core Structure
- **Main Library:** `lib/` - Contains the primary Flutter application
  - `app/` - Core UI widgets and screens (SplashScreen, HomeScreen, RestaurantListing, Cart, Orders, etc.)
  - `features/*` - Feature modules:
    - Restaurants (discovery, listing, details)
    - Wishlist (save/remove items)
    - Home (main dashboard)
    - Cart (shopping basket)
    - Orders (order tracking, placement)
    - Wallet (payment methods)
    - Notifications (push alerts)
    - Account (profile, settings)
  - `packages/oxro_pricing/` - Pricing engine (seller commission, fees, payouts)
- **Web Frontend:** `web/` - Separate web build
- **Native Integrations:**
  - Android (`android/`, `linux/runner/`)
  - Linux (`linux/runner/`)
  - Windows (`windows/runner/`)
- **Tests:** Comprehensive test suite in `test/` (unit and widget tests)

### Key Modules Identified

| Module | Path | Purpose |
|--------|------|----------|
| App Entry | `lib/app/app.dart` | MaterialApp root with SplashScreen |
| Restaurants | `lib/features/restaurants/` | Restaurant discovery & listings |
| Wishlist | `lib/features/wishlist/` | Save/remove items from cart |
| Home | `lib/features/home/` | Main dashboard screen |
| Cart | `lib/features/cart/` | Shopping basket management |
| Orders | `lib/features/orders/` | Order placement & tracking |
| Wallet | `lib/features/wallet/` | Payment method storage |
| Notifications | `lib/features/notifications/` | Push notification handling |
| Account | `lib/features/account/` | Profile & settings |
| Pricing Engine | `packages/oxro_pricing/` | Business logic for commissions/fees |

## Architecture Notes

- **Flutter Framework:** Uses Material Design 3 with Inter font
- **State Management:** Implicit (likely using setState or similar)
- **Local Storage:** `shared_preferences` for simple key-value storage
- **Networking:** Depends on `http` package (in pubspec.yaml)
- **Pricing:** Pure Dart module shared between UI and backend
- **Testing:** Full unit test coverage across features

## Implementation Plan

### Phase 1: Project Assessment & Setup
1. **Verify Project Structure** - Confirm all directories and files exist
2. **Check Dependency Versions** - Review pubspec.yaml for compatible versions
3. **Analyze Lint Configuration** - Review analysis_options.yaml for lint rules
4. **Review Existing Tests** - Ensure test coverage is adequate

### Phase 2: Core Feature Development
1. **Restaurants Module** - Implement restaurant discovery and listing UI
2. **Wishlist Module** - Add save/remove functionality for items
3. **Home Module** - Build main dashboard with featured content
4. **Cart Module** - Implement shopping basket with add/remove/update
5. **Orders Module** - Create order placement and tracking UI
6. **Wallet Module** - Add payment method storage and management
7. **Notifications Module** - Implement push notification handling
8. **Account Module** - Build profile and settings interface

### Phase 3: Pricing Engine Integration
1. **Review oxro_pricing/ package** - Understand business logic
2. **Integrate Pricing Logic** - Connect pricing engine to cart/orders
3. **Test Pricing Calculations** - Verify commission/fee calculations

### Phase 4: Testing & Quality Assurance
1. **Run Existing Tests** - Execute test suite to identify gaps
2. **Add Unit Tests** - Cover new features and edge cases
3. **Integration Testing** - Verify cross-module interactions
4. **Performance Testing** - Check app responsiveness

### Phase 5: Platform-Specific Considerations
1. **Android** - Verify native integrations (geolocator, url_launcher)
2. **iOS** - Check platform-specific requirements
3. **Web** - Ensure web build compiles correctly
4. **Linux/Windows** - Validate native runner configurations

### Phase 6: Deployment & Validation
1. **Build All Platforms** - Generate APK, IPA, web, and native binaries
2. **Beta Testing** - Deploy to test devices
3. **Final Validation** - Verify all features work end-to-end

## Constraints & Risks

- **Dependency Compatibility** - Ensure all pubspec dependencies are compatible
- **Platform Differences** - Handle OS-specific behaviors (e.g., geolocation permissions)
- **Testing Coverage** - Maintain high test coverage as new features are added
- **Performance** - Optimize UI rendering and network calls

## Data Flow

1. **User Interaction** → UI Layer (lib/features/*)
2. **Business Logic** → Pricing Engine (packages/oxro_pricing/)
3. **Network Requests** → http package → Backend
4. **Local Storage** → shared_preferences
5. **Push Notifications** → Notifications module

## Validation Steps

- [ ] All unit tests pass
- [ ] Integration tests cover core workflows (restaurant → cart → order)
- [ ] Build succeeds on all target platforms (Android, iOS, macOS, Linux, Windows)
- [ ] Performance benchmarks meet requirements
- [ ] Security review of network and storage access

## Open Questions

- What specific functionality needs to be implemented or improved?
- Are there any bugs or performance issues reported?
- Do you need help with a particular module (e.g., restaurant listing, cart, pricing)?
- Should we focus on one area first (e.g., adding a new feature, fixing existing bugs, improving tests)?

## Next Actions

1. Review the existing plan file at `D:\OXRO\oxro\.kilo\plans\oxro_project_plan.md`
2. Confirm the project structure matches the description
3. Begin Phase 1 tasks: verify project structure and dependencies
4. Update the plan with specific implementation tasks as work progresses
